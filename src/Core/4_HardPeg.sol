// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Engine} from "./shared/3_Engine.sol";
import {CollateralManager} from "./shared/CollateralManager.sol";
import {AccessManager} from "./shared/AccessManager.sol";


/**
 * @notice Depending on the collateral the stablecoin will be a different "peg"
 * @dev Each peg system may or may not override certain functions in Engine to customize redemption liquidation and other actions
 *      Each peg system will specify different positions...
 */


/**
 * @notice Handles Stable Collateral
 */
contract HardPeg is Engine {
    
    constructor(address owner, address timelock)
    AccessManager(owner, timelock)
    CollateralManager(0)
    {}
}