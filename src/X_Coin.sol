// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/token/ERC20/ERC20.sol"; 

/**
 * @notice ERC20 token controlled by a central engine contract.
 *          One token deployed per new App Instance.
 * @dev Minting and burning are restricted to the engine, and approvals
 *      are disabled to limit how the token can be used.
 */
contract Coin is ERC20 {
}