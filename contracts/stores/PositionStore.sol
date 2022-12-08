// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../utils/Roles.sol";

contract PositionStore is Roles {

	using EnumerableSet for EnumerableSet.Bytes32Set;

	struct Position {
		address user;
		address asset;
		string market;
		bool isLong;
		uint256 size;
		uint256 margin;
		int256 fundingTracker;
		uint256 price;
		uint256 timestamp;
	}

	uint256 public removeMarginBuffer = 1000;
	uint256 public oracleFeeShare = 1000;

	mapping(address => mapping(string => uint256)) private OI; // open interest. market => asset => amount
	mapping(address => mapping(string => uint256)) private OILong; // open interest. market => asset => amount
	mapping(address => mapping(string => uint256)) private OIShort; // open interest. market => asset => amount]

	mapping(bytes32 => Position) private positions; // key = asset,user,market
	EnumerableSet.Bytes32Set private positionKeys; // [position keys..]
	mapping(address => EnumerableSet.Bytes32Set) private positionKeysForUser; // user => [position keys..]

	constructor(RoleStore rs) Roles(rs) {}

	function setRemoveMarginBuffer(uint256 bps) external onlyGov {
		removeMarginBuffer = bps;
	}
	function setOracleFeeShare(uint256 bps) external onlyGov {
		oracleFeeShare = bps;
	}

	function incrementOI(
		address asset, 
		string memory market, 
		uint256 amount, 
		bool isLong
	) external onlyContract {
		OI[asset][market] += amount;
		if (isLong) {
			OILong[asset][market] += amount;
		} else {
			OIShort[asset][market] += amount;
		}
	}

	function decrementOI(
		address asset, 
		string memory market, 
		uint256 amount, 
		bool isLong
	) external onlyContract {
		OI[asset][market] = OI[asset][market] <= amount ? 0 : OI[asset][market] - amount;
		if (isLong) {
			OILong[asset][market] = OILong[asset][market] <= amount ? 0 : OILong[asset][market] - amount;
		} else {
			OIShort[asset][market] = OIShort[asset][market] <= amount ? 0 : OIShort[asset][market] - amount;
		}
	}

	function getOI(address asset, string memory market) external view returns(uint256) {
		return OI[asset][market];
	}

	function getOILong(address asset, string memory market) external view returns(uint256) {
		return OILong[asset][market];
	}

	function getOIShort(address asset, string memory market) external view returns(uint256) {
		return OIShort[asset][market];
	}

	// Setters

	function addOrUpdate(Position memory position) external onlyContract {
		bytes32 key = _getPositionKey(position.user, position.asset, position.market);
		positions[key] = position;
		positionKeysForUser[position.user].add(key);
		positionKeys.add(key);
	}

	function remove(address user, address asset, string memory market) external onlyContract {
		bytes32 key = _getPositionKey(user, asset, market);
		positionKeysForUser[user].remove(key);
		positionKeys.remove(key);
		delete positions[key];
	}

    // Getters

    function get(address user, address asset, string memory market) external view returns(Position memory) {
		bytes32 key = _getPositionKey(user, asset, market);
		return positions[key];
	}

    function getPosition(address user, address asset, string memory market) public view returns(Position memory position) {
		bytes32 key = _getPositionKey(user, asset, market);
		return positions[key];
	}

	function getPositions(address[] calldata users, address[] calldata assets, string[] calldata markets) external view returns(Position[] memory _positions) {
		uint256 length = users.length;
		_positions = new Position[](length);
		for (uint256 i = 0; i < length; i++) {
			_positions[i] = getPosition(users[i], assets[i], markets[i]);
		}
		return _positions;
	}

	function getPositions(bytes32[] calldata keys) external view returns(Position[] memory _positions) {
		uint256 length = keys.length;
		_positions = new Position[](length);
		for (uint256 i = 0; i < length; i++) {
			_positions[i] = positions[keys[i]];
		}
		return _positions;
	}

	function getPositionCount() external view returns(uint256) {
		return positionKeys.length();
	}

	function getPositions(uint256 length, uint256 offset) external view returns(Position[] memory _positions) {
		uint256 _length = positionKeys.length();
		if (length > _length) length = _length;
		_positions = new Position[](length);
		for (uint256 i = offset; i < length + offset; i++) {
			_positions[i] = positions[positionKeys.at(i)];
		}
		return _positions;
	}

	function getUserPositions(address user) external view returns(Position[] memory _positions) {
		uint256 length = positionKeysForUser[user].length();
		_positions = new Position[](length);
		for (uint256 i = 0; i < length; i++) {
			_positions[i] = positions[positionKeysForUser[user].at(i)];
		}
		return _positions;
	}

	// Internal

	function _getPositionKey(address user, address asset, string memory market) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(user, asset, market));
    }

}