// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../utils/Governable.sol";

contract RoleStore is Governable {

	using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    EnumerableSet.Bytes32Set internal roles;
    mapping(bytes32 => EnumerableSet.AddressSet) internal roleMembers;

    constructor() Governable() {}

    function grantRole(address account, bytes32 key) external onlyGov {
        roles.add(key);
        roleMembers[key].add(account);
    }

    function revokeRole(address account, bytes32 key) external onlyGov {
        roleMembers[key].remove(account);
    }

    function hasRole(address account, bytes32 key) external view returns (bool) {
        return roleMembers[key].contains(account);
    }

    function getRoleCount() external view returns (uint256) {
        return roles.length();
    }
    
}