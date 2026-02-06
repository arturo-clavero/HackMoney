// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20Mock} from "@openzeppelin/mocks/token/ERC20Mock.sol";
// import {ERC20DecimalsMock} from "@openzeppelin/mocks/token/ERC20DecimalsMock.sol";

contract MockToken is ERC20Mock {
    uint8 private immutable _decimals;

    constructor(uint8 decimals_) {
        _decimals = decimals_;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }
} 