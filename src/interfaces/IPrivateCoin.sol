// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/token/ERC20/extensions/IERC20Permit.sol";

interface IPrivateCoin is IERC20, IERC20Permit {

    event NeedToSetMorePermissions(address[] toAdd, address[] toRevoke);

    function mint(address from, address to, uint256 value) external;

    function burn(address account, uint256 value) external;

    function transferFrom(address from, address to, uint256 value) external returns (bool);

    function approve(address, uint256) external returns (bool);

    function transfer(address, uint256) external returns (bool);

    function updateUserList(address[] memory toAdd, address[] memory toRemove) external;

}