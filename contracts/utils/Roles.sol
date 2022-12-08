// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./Governable.sol";
import "../stores/RoleStore.sol";

contract Roles is Governable {

    bytes32 public constant CONTRACT = keccak256("CONTRACT");
	bytes32 public constant ORACLE = keccak256("ORACLE");

	RoleStore public roleStore;

	constructor(RoleStore rs) Governable() {
        roleStore = rs;
    }

    modifier onlyOracle() {
        require(roleStore.hasRole(msg.sender, ORACLE), "!oracle-role");
        _;
    }

    modifier onlyContract() {
        require(roleStore.hasRole(msg.sender, CONTRACT), "!contract-role");
        _;
    }

    modifier onlyContractOrGov() {
        require(msg.sender == this.gov() || roleStore.hasRole(msg.sender, CONTRACT), "!contract-or-gov");
        _;
    }

}