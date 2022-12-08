// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../utils/Governable.sol";

contract DataStore is Governable {

	// TODO: is hashing of keys needed? string can be used directly as the key

	// Constants
	uint256 public constant UNIT = 10**18;
	uint256 public constant BPS_DIVIDER = 10000;

	// Key-value stores
	mapping(bytes32 => uint256) public uintValues;
    mapping(bytes32 => int256) public intValues;
    mapping(bytes32 => address) public addressValues;
    mapping(bytes32 => bytes32) public dataValues;
    mapping(bytes32 => bool) public boolValues;
    mapping(bytes32 => string) public stringValues;

	constructor() Governable() {}

    function getHash(string memory key) public pure returns (bytes32) {
    	return keccak256(abi.encodePacked(key));
    }

    // Uint

    function getUint(string memory key) external view returns(uint256) {
		return uintValues[getHash(key)];
	}

	function setUint(string memory key, uint256 value, bool overwrite) external onlyGov returns(bool) {
		bytes32 hash = getHash(key);
		if (overwrite || uintValues[hash] == 0) {
			uintValues[hash] = value;
			return true;
		}
		return false;
	}

	// Int
    function getInt(string memory key) external view returns(int256) {
		return intValues[getHash(key)];
	}

	function setInt(string memory key, int256 value, bool overwrite) external onlyGov returns(bool) {
		bytes32 hash = getHash(key);
		if (overwrite || intValues[hash] == 0) {
			intValues[hash] = value;
			return true;
		}
		return false;
	}

	// Address

	function getAddress(string memory key) external view returns(address) {
		return addressValues[getHash(key)];
	}

	function setAddress(string memory key, address value, bool overwrite) external onlyGov returns(bool) {
		bytes32 hash = getHash(key);
		if (overwrite || addressValues[hash] == address(0)) {
			addressValues[hash] = value;
			return true;
		}
		return false;
	}

	// Data

	function getData(string memory key) external view returns(bytes32) {
		return dataValues[getHash(key)];
	}

	function setData(string memory key, bytes32 value) external onlyGov returns(bool) {
		dataValues[getHash(key)] = value;
		return true;
	}

	// Bool

	function getBool(string memory key) external view returns(bool) {
		return boolValues[getHash(key)];
	}

	function setBool(string memory key, bool value) external onlyGov returns(bool) {
		boolValues[getHash(key)] = value;
		return true;
	}

	// String

	function getString(string memory key) external view returns(string memory) {
		return stringValues[getHash(key)];
	}

	function setString(string memory key, string memory value) external onlyGov returns(bool) {
		stringValues[getHash(key)] = value;
		return true;
	}


}