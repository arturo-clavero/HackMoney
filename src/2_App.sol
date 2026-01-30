// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Storage} from "./1_Storage.sol";

/**
 * @notice Management for each app instance
 * @dev stores app specific configurations and manages adding new instances
 */
abstract contract App is Storage {

}