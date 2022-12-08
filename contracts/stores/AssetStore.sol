// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../utils/Roles.sol";

contract AssetStore is Roles {

	struct Asset {
		uint256 minSize;
		address chainlinkFeed;
	}

	address[] public assetList;
	mapping(address => Asset) private assets;

	constructor(RoleStore rs) Roles(rs) {}

	// Setters

	function set(address asset, Asset memory assetInfo) external onlyGov {
		assets[asset] = assetInfo;
		for (uint256 i = 0; i < assetList.length; i++) {
			if (assetList[i] == asset) return;
		}
		assetList.push(asset);
	}

	// Getters

	function get(address asset) external view returns(Asset memory) {
		return assets[asset];
	}

	function getAssetList() external view returns(address[] memory) {
		return assetList;
	}

	function getAssetCount() external view returns(uint256) {
		return assetList.length;
	}

	function getAssetByIndex(uint256 index) external view returns(address) {
		return assetList[index];
	}

	function isSupported(address asset) external view returns(bool) {
		return assets[asset].minSize > 0;
	}

}