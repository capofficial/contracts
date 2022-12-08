// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

contract Governable {
    
    address public gov;

    event SetGov(address prevGov, address nextGov);

    constructor() {
        _setGov(msg.sender);
    }

    modifier onlyGov() {
        require(msg.sender == gov, "!gov");
        _;
    }

    function setGov(address _gov) external onlyGov {
        _setGov(_gov);
    }

    function _setGov(address _gov) internal {
        address prevGov = gov;
        gov = _gov;
        emit SetGov(prevGov, _gov);
    }

}