// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract MockTarget {
    uint256 public value;

    mapping(uint256 => mapping(address => bool)) public roles;
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    function setRole(uint256 role, address account, bool enabled) external {
        require(msg.sender == owner, "NOT_OWNER");
        roles[role][account] = enabled;
    }

    function hasRole(uint256 role, address account) external view returns (bool) {
        return roles[role][account];
    }

    function isOwner(address account) external view returns (bool) {
        return account == owner;
    }

    function setValue(uint256 newValue) external {
        value = newValue;
    }
}