// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC2981} from "@openzeppelin/contracts/interfaces/IERC2981.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract NftAuction is ReentrancyGuard {
    // Placeholder for NftAuction contract code
    struct Auction {
        address seller;           // 卖家地址
        address nftContract;      // NFT合约地址
        uint256 tokenId;          // Token ID
        uint256 startPrice;       // 起拍价
        uint256 highestBid;       // 当前最高出价
        address highestBidder;    // 当前最高出价者
        uint256 endTime;          // 拍卖结束时间
        bool active;              // 是否激活
    }

    // 事件定义
    event AuctionCreated(uint256 indexed auctionId, address indexed seller, address indexed nftContract, uint256 tokenId, uint256 startPrice, uint256 endTime);
    event BidPlaced(uint256 indexed auctionId, address indexed bidder, uint256 amount);
    event AuctionFinalized(uint256 indexed auctionId, address indexed winner, uint256 amount);
    event RefundWithdrawn(uint256 indexed auctionId, address indexed refunder, uint256 amount);

    // 状态变量
    uint256 public constant PLATFORM_FEE = 5; // 平台手续费5%
    uint256 public constant MIN_BID_INCREMENT = 10; // 每次出价必须高于当前最高出价的10%
    uint256 public auctionCount; // 拍卖计数器
    address public platformFeeRecipient; // 平台手续费的收款地址
    mapping(uint256=>Auction) public auctions; // auctionId => Auction
    mapping(uint256=>mapping(address=>uint256)) public refunds; // auctionId => refunder => amount

    function createAuction (
        address _nftContract,
        uint256 _tokenId,
        uint256 _startPrice,
        uint256 _duration
    ) external returns (uint256) {
        // 创建拍卖逻辑
        require(address(0) != _nftContract, "Invalid NFT contract address");
        require(_startPrice > 0, "Start price must be greater than 0");
        require(_duration > 0, "Duration must be greater than 0");

        // 判断NFT所有权和授权逻辑
        IERC721 nftToken = IERC721(_nftContract);
        require(nftToken.ownerOf(_tokenId) == msg.sender, "Caller is not the owner of the NFT");
        require(nftToken.getApproved(_tokenId) == address(this) 
            || nftToken.isApprovedForAll(msg.sender, address(this)), "Contract is not approved to transfer this NFT");

        uint256 auctionId = auctionCount++;
        auctions[auctionId] = Auction({
            seller: msg.sender,
            nftContract: _nftContract,
            tokenId: _tokenId,
            startPrice: _startPrice,
            highestBid: 0,
            highestBidder: address(0),
            endTime: block.timestamp + _duration,
            active: true
        });

        emit AuctionCreated(auctionId, msg.sender, _nftContract, _tokenId, _startPrice, block.timestamp + _duration);
        return auctionId;
    }

    function placeBid(uint256 _auctionId) external payable {
        // 出价逻辑
        Auction storage auction = auctions[_auctionId];
        require(auction.active, "Auction is not active");
        require(block.timestamp < auction.endTime, "Auction has ended");

        // 出价必须高于当前最高出价,每次出价不得低于当前最高出价10%
        uint256 minBid = auction.highestBid == 0 ? auction.startPrice : auction.highestBid + (auction.highestBid * MIN_BID_INCREMENT / 100);
        require(msg.value >= minBid, "Bid amount too low");

        // 临时保存上一个最高出价者的信息，以便退款
        if (auction.highestBidder != address(0)) {
            refunds[_auctionId][auction.highestBidder] += auction.highestBid;
        }

        // 更新最高出价和出价者
        auction.highestBid = msg.value;
        auction.highestBidder = msg.sender;

        // 记录事件
        emit BidPlaced(_auctionId, msg.sender, msg.value);
    }

    function finalizeAuction(uint256 _auctionId) external nonReentrant {
        // 结束拍卖逻辑
        Auction storage auction = auctions[_auctionId];
        require(auction.active, "Auction is not active");
        require(block.timestamp >= auction.endTime, "Auction has not ended yet");
        // 只能由卖家结束拍卖
        require(msg.sender == auction.seller, "Only seller can finalize the auction");

        // 标记拍卖为非激活状态
        auction.active = false;

        if (auction.highestBidder != address(0)) {
            // 转移NFT给最高出价者
            IERC721 nftToken = IERC721(auction.nftContract);
            nftToken.safeTransferFrom(auction.seller, auction.highestBidder, auction.tokenId);

            uint256 sellerAmount = auction.highestBid;

            // 平台手续费(假设为5%)
            uint256 platformFee = (sellerAmount * PLATFORM_FEE) / 100;
            sellerAmount -= platformFee;

            // 处理版税支付
            (address royaltyReceiver, uint256 royaltyAmount) = _getRoyaltyInfo(auction.nftContract, auction.tokenId, auction.highestBid);
            if (royaltyAmount > 0 && royaltyReceiver != address(0)) {
                sellerAmount -= royaltyAmount;
                (bool royaltyPaySuccess, ) = royaltyReceiver.call{value: royaltyAmount}("");
                require(royaltyPaySuccess, "Royalty payment failed");
            }

            // 支付平台手续费给合约拥有者
            (bool platformFeePaySuccess, ) = platformFeeRecipient.call{value: platformFee}("");
            require(platformFeePaySuccess, "Platform fee payment failed");

            // 支付给卖家
            (bool sellerPaySuccess, ) = auction.seller.call{value: sellerAmount}("");
            require(sellerPaySuccess, "Seller payment failed");

            emit AuctionFinalized(_auctionId, auction.highestBidder, auction.highestBid);
        } else {
            // 没有出价,记录事件
            emit AuctionFinalized(_auctionId, address(0), 0);
        }
    }

    function withdrawRefund(uint256 _auctionId) external nonReentrant {
        // 提现退款逻辑
        // 判断拍卖是否结束
        Auction storage auction = auctions[_auctionId];
        require(!auction.active, "Auction is still active");
        uint256 totalRefund = refunds[_auctionId][msg.sender];
        require(totalRefund > 0, "No refunds available");

        // 清空退款记录
        refunds[_auctionId][msg.sender] = 0;

        (bool success, ) = msg.sender.call{value: totalRefund}("");
        require(success, "Refund withdrawal failed");

        emit RefundWithdrawn(_auctionId, msg.sender, totalRefund);
    }

    function _getRoyaltyInfo(
        address nftContract,
        uint256 tokenId,
        uint256 salePrice
    ) internal view returns (address receiver, uint256 royaltyAmount) {
        // 如果NFT合约支持ERC2981接口，则获取版税信息
        if (IERC165(nftContract).supportsInterface(type(IERC2981).interfaceId)) {
            (receiver, royaltyAmount) = IERC2981(nftContract).royaltyInfo(tokenId, salePrice);
        } else {
            receiver = address(0);
            royaltyAmount = 0;
        }
    }
}