// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {AccessManager} from "./shared/AccessManager.sol";
import {CollateralManager} from "./shared/CollateralManager.sol";
import {Security} from "./shared/Security.sol";
import {AppManager} from "./shared/AppManager.sol";

import {RiskEngine} from "./../utils/RiskEngineLib.sol";

import {SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/interfaces/IERC20.sol";

import {Error} from "../utils/ErrorLib.sol";

/**
    In short:
        deposit 100$ of yield bearing assets 
        get 100$ stablecoind(1 to 1)
        100$ grows woth yieds to 106$
        6$ goes to user (may go to protocol too)
@notice Nominal value(alwasy 1$) adnd real value(with time it will grow) stablecoin must
        stay pegged to the nominal $1 and real value will grow
    Main idea need to promise peg stability 
    IN makerDaopeg stays 1:1:
        - stablecoin supply based on the deposit value at time of mint 
        -  yield accures to the collateral not stablecoin
        - redemprion uses current collateral value to return correct propportion
@notice - collateral should absorb whole hause so stablecoin will stay 1
@notice - if stablecin will start receive yields arbitrage will drain collateral
        Think about::
        -  how to track the difference between eposited value and current value with 
        the yield - can be with the erc4626 vault standart - give share based accounting automaticly
        - where does the accumulates yields go? simpliest go to  protocol, deposit reward/stablecoin
            holder reward (will be goos but harder)
        - when someone gets 100 stableoin what exaclty do they get?  -fixed value redemption 
        If redemption depends on pool growth-  token is a share.
        If redemption is fixed - token is money.
        - how users will recieve yieds ?
            yields will go to the collateral owner 
        || split tokens to stablecoin and yield token 
    Flow for the code
    collateral tracker
    minting logic ...
    yild collection
    redemption logic




 */