// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

contract MockChainlink {

    mapping(address => uint256) marketPrices;

    constructor() {
    }

    function setMarketPrice(address feed, uint256 price) external {
        marketPrices[feed] = price;
    }

    function getPrice(address feed) external view returns(uint256) {
        return marketPrices[feed];
    }

}