// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8;

import {ERC721URIStorage, ERC721} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {ERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract NftToken is ERC721, ERC721URIStorage, ERC2981, Ownable {
    uint256 private _tokenIdCount;
    uint256 public constant MAX_SUPPLY = 10000;
    uint256 public constant MINT_PRICE = 0.01 ether;

    event Mint(address indexed _to, uint256 _tokenId, string _tokenURI);

    constructor() ERC721("NFT", "NFT") Ownable(msg.sender) {}

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721URIStorage, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function mint(string memory _tokenURI) public payable returns (uint256) {
        require(_tokenIdCount < MAX_SUPPLY, "Max supply reached");
        require(msg.value >= MINT_PRICE, "Insufficient payment");

        _tokenIdCount++;
        uint256 tokenId = _tokenIdCount;
        
        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, _tokenURI);

        emit Mint(msg.sender, tokenId, _tokenURI);

        return tokenId;
    }
}