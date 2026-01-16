// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8;

import {NftAuction} from "./NftAuction.sol";

contract NftAuctionV2 is NftAuction {

    function version() external pure returns (string memory) {
        return "NftAuction V2.0.0";
    }
}