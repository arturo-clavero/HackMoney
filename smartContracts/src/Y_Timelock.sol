// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
 * @notice Simple timelock interacting with stablecoin.
 * @dev Sensitive actions (like config updates) are queued first and can only be executed later,
 *      giving time to observe and react before changes go live.
 */
contract Timelock {

}