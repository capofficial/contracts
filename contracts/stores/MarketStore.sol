// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../utils/Roles.sol";

contract MarketStore is Roles {

	struct Market {
		string name; // Bitcoin / U.S. Dollar
		string category; // crypto, fx, commodities, indices
		address chainlinkFeed;
		uint256 maxLeverage; // No decimals
		uint256 maxDeviation; // In bps, from chainlink feed
		uint256 fee; // In bps. 10 = 0.1%
		uint256 liqThreshold; // In bps
		bool allowChainlinkExecution; // Allow anyone to execute orders with chainlink
		bool isClosed; // if market is closed, eg weekends, etc
		bool isReduceOnly; // accepts only reduce only orders
	}

	uint256 public constant MAX_FEE = 1000; // 10%

	string[] public marketList; // "ETH-USD", "BTC-USD", etc

	mapping(string => Market) private markets;

	bool public isGlobalReduceOnly;
	
	constructor(RoleStore rs) Roles(rs) {}
	
	// Setters

	function setIsGlobalReduceOnly(bool b) external onlyGov {
		isGlobalReduceOnly = b;
	}

	function set(string memory market, Market memory marketInfo) external onlyGov {
		require(marketInfo.fee <= MAX_FEE, "!max-fee");
		require(marketInfo.maxLeverage >= 1, "!max-leverage");
		markets[market] = marketInfo;
		for (uint256 i = 0; i < marketList.length; i++) {
			if (keccak256(abi.encodePacked(marketList[i])) == keccak256(abi.encodePacked(market))) return;
		}
		marketList.push(market);
	}

	function setMarketStatus(string[] memory _markets, bool[] calldata isClosed) external onlyContractOrGov {
		for (uint256 i = 0; i < _markets.length; i++) {
			Market storage market = markets[_markets[i]];
			market.isClosed = isClosed[i];
		}
	}

	// Getters

	function get(string memory market) external view returns(Market memory) {
		return markets[market];
	}

	function getMany(string[] memory _markets) external view returns(Market[] memory _marketInfos) {
		uint256 length = _markets.length;
		_marketInfos = new Market[](length);
		for (uint256 i = 0; i < length; i++) {
			_marketInfos[i] = markets[_markets[i]];
		}
		return _marketInfos;
	}

	function getMarketByIndex(uint256 index) external view returns(string memory) {
		return marketList[index];
	}

	function getMarketList() external view returns(string[] memory) {
		return marketList;
	}

	function getMarketCount() external view returns(uint256) {
		return marketList.length;
	}

	

}