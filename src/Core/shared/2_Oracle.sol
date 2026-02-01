// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {CollateralManager} from "./CollateralManager.sol";

/**
 * @notice Oracle management
 * @dev get prices for certain collateral (with safety: oracle fallback, suspicious detection, etc)
 */
abstract contract Oracle is CollateralManager {

}