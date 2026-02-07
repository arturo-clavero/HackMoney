// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {AccessManager} from "./shared/AccessManager.sol";
import {CollateralManager} from "./shared/CollateralManager.sol";
import {Security} from "./shared/Security.sol";
import {AppManager, AppConfig} from "./shared/AppManager.sol";

import {RiskEngine} from "./../utils/RiskEngineLib.sol";

import {SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {IERC4626} from "@openzeppelin/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/interfaces/IERC20.sol";

import {Error} from "../utils/ErrorLib.sol";
// @devL difference between HrdPeg is that stable stays 1$ while collateral compounds on the background 
/**
    In short:
        deposit 100$ of yield bearing assets 
        get 100$ stablecoind(1 to 1)
        100$ grows woth yieds to 106$
        6$ goes to user (may go to protocol too)
        ()
@notice Nominal value(alwasy 1$) adnd real value(with time it will grow) stablecoin must
        stay pegged to the nominal $1 and real value will grow
    Main idea need to promise peg stability 
    IN makerDaopeg stays 1:1:
        - stablecoin supply based on the deposit value at time of mint 
        -  yield accures to the collateral not stablecoin
        - redemprion uses current collateral value to return correct propportion
@notice - collateral should absorb whole chaos so stablecoin will stay 1
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
    Flow for the code:
    deposit -- transfer token and deposit it to vault 4626
    shares
    // totalDebt
    collateralToken->vaultMapping
    collateral tracker
    minting logic ...
    yild collection ()harvestYield
    redemption logic

    yield accounting snapshot and 4626
    Collateral Provider (capital owner)(ERC4626 aUSDC) - take risk receive yields 
    Stablecoin Holder(money user) - pay salary

    Shoould not minth in yields 
    Yields belongs to collateral position not to stable redemption
    ERC4626 fixex everythong automatically increment and count time


 */

 contract MediumPeg is AppManager, Security {
    using SafeERC20 for IERC20;

    struct Position {
        uint256 principals; // fixed $ for minting  (value at depoist time)
        uint256 shares; //erv4626(grow in value)
    }
    // appId-> user->position collateral
    mapping(uint256 => mapping (address => Position)) internal positions;
    //total stablecoins minted per app
    mapping(uint256 => uint256) internal totalDebt;
    //appId-> vault4626  vault as collateral 
    mapping(uint256 => address) internal vaults;

    constructor(
        address owner, 
        address timelock, 
        uint256 globalDebtcap, 
        uint256 mintCapPerTx
    )
    AccessManager(owner, timelock)
    CollateralManager(0) 
    Security(globalDebtcap, mintCapPerTx)
    {}

    /**
        @notice set vault for app(4626)
        @dev 
     */
    function setVault(uint256 appId, address vault) external {
        AppConfig memory app = _getAppConfig(appId);
        if (msg.sender != app.owner) revert Error.InvalidAccess();
        vaults[appId] = vault;
    }


    /** 
        @notice user deposits yield-bearing stablecoins. Store depositedValue, mint stays 1:1 against it
        @dev only collateral providers call this
     */
    function deposit(
        uint256 appId,
        uint256 assets)
     external {
    // @notice vault grows principal stayes unchanged
    // frontend ask to approve
        //if collateral alllowed 
        //transfer assets from user
        //approve vault
        //deposit -> get shares
        address vault = vaults[appId];
        if (vault == address(0)) revert Error.InvalidTokenAddress();
        IERC20 asset = IERC20(IERC4626(vault).asset());
        asset.safeTransferFrom(msg.sender, address(this), assets);
        asset.approve(vault, assets);
        uint256 shares = IERC4626(vault).deposit(assets, address(this));
        uint256 valueAtDeposit = IERC4626(vault).convertToAssets(shares);
        Position storage p = positions[appId][msg.sender];
        p.principals += valueAtDeposit;
        p.shares += shares;


    }
    // @notice mints stavlecoin against their deposit. Mint against depositedvalue(not cuurent )
    // @dev mint is only based on principal (yields ignored)
    function mint(
        uint256 appId,
        address to,
        uint256 amount
    ) external {
        Position storage p = positions[appId][msg.sender];
        uint256 available = p.principals - totalDebt[appId];
        if (amount > available) revert Error.CapExceeded();
        totalDebt[appId] += amount;
        _mintAppToken(appId, to, amount);
    }
    //@notice burns to get collateral back 
    //@notice reedem stablecoin for fixed 1$
    //@dev yields not inculded 
    function redeem(address stablecoin, uint256 amount) external {
        uint256 appId = _getStablecoinID(stablecoin);
        if (amount == 0) revert Error.InvalidAmount();
        _burnAppToken(appId, amount);
        totalDebt[appId] -= amount;
        IERC4626(vaults[appId]).withdraw(amount, msg.sender, address(this));
    }
    // @notice user withdraws unused collateral 
    // @dev only if no stablecoin debt exists 
    function withdrawCollateral(uint256 appId) external {
        Position storage p = positions[appId][msg.sender];
        if (totalDebt[appId] != 0) revert Error.OutstandingDebt();
        uint256 shares = p.shares;
        if (shares == 0) revert Error.InvalidAmount();

        p.shares = 0;
        p.principals = 0;

        IERC4626(vaults[appId]).redeem(
            shares,
            msg.sender,
            address(this)
        );
    }

    function getTotalDebt(uint256 appId) external view returns(uint256 ) {
        return totalDebt[appId];
    }
    function getPosition (uint256 appId, address user) 
        external view returns(uint256 principal, uint256 shares){
        Position memory p = positions[appId][user];
        return (p.principals, p.shares);
    }
 }