// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Storage} from "./1_Storage.sol";

/**
 * @notice Oracle management
 * @dev get prices for certain collateral (with safety: oracle fallback, suspicious detection, etc)
 */
abstract contract Oracle is Storage {

}