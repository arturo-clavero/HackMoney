// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Oracle} from "./2_Oracle.sol";
import {Security} from "./2_Security.sol";
import {App} from "./1_App.sol";


/**
 * @notice External interactions for main "stablecoin" functions
 * @dev handles collateral deposits, withdrawals, mints, burns, redeamption, liquidation etc
 */
abstract contract Engine is Oracle, Security, App {

}