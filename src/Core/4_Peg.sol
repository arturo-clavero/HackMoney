// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// import {Engine} from "./3_Engine.sol";


        // if (pegType == 0) {
        //     i_allowedCollateralModes |= STABLE;
        // }
        // else if (pegType == 1){
        //     i_allowedCollateralModes |= STABLE;
        //     i_allowedCollateralModes |= YIELD;
        // }
        // else {
        //     i_allowedCollateralModes |= STABLE;
        //     i_allowedCollateralModes |= VOLATILE;
        // }
/**
 * @notice Depending on the collateral the stablecoin will be a different "peg"
 * @dev Each peg system may or may not override certain functions in Engine to customize redemption liquidation and other actions
 *      Each peg system will specify different positions...
 */


/**
 * @notice Handles Stable Collateral
//  */
// contract HardPeg is Engine {
//     constructor(address owner, address timelock) 
//     // Storage(owner, timelock, 0){}
// }

// /**
//  * @notice Handles Stable Collateral + Yield
//  */
// contract MediumPeg is Engine {
//     constructor(address owner, address timelock) 
//     // Storage(owner, timelock, 1){}

// }

// /**
//  * @notice Handles Multi Collateral (Any non yield)
//  */
// contract SoftPeg is Engine, CrossChain {
//     constructor(address owner, address timelock) 
//     Storage(owner, timelock, 2){}

// }