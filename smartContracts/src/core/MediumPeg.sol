// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {AccessManager} from "./shared/AccessManager.sol";
import {CollateralManager} from "./shared/CollateralManager.sol";
import {Security} from "./shared/Security.sol";
import {AppManager, AppConfig} from "./shared/AppManager.sol";

import {SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {IERC4626} from "@openzeppelin/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/interfaces/IERC20.sol";

import {Error} from "../utils/ErrorLib.sol";
// @dev difference between HrdPeg is that stable stays 1$ while collateral compounds on the background 

 contract MediumPeg is AppManager, Security {
    using SafeERC20 for IERC20;

    struct Position {
        uint256 principals; // fixed $ for minting  (value at depoist time)
        uint256 shares; //erv4626(grow in value)
    }
    // appId-> user->position collateral
    mapping(uint256 => mapping (address => Position)) internal positions;
    // //total stablecoins minted per app
    mapping(uint256 => uint256) internal _totalDebtPerApp;
    //per user 
    mapping(uint256 => mapping (address => uint256)) userDebt;
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
    function depositShares(uint256 appId, uint256 shares) external {
        depositSharesTo(appId, msg.sender, shares);
    }

    function depositSharesTo(uint256 appId, address to, uint256 shares) public {
        address vault = vaults[appId];
        if (vault == address(0)) revert Error.InvalidTokenAddress();
        IERC20(vault).safeTransferFrom(to, address(this), shares);
        uint256 valueAtDeposit = IERC4626(vault).convertToAssets(shares);
        Position storage p = positions[appId][to];
        p.principals += valueAtDeposit;
        p.shares += shares;
    }

    /**
        @notice user deposits yield-bearing stablecoins. Store depositedValue, mint stays 1:1 against it
        @dev only collateral providers call this
     */
    function deposit(
        uint256 appId,
        uint256 assets)
     external {
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
        uint256 available = p.principals - userDebt[appId][msg.sender];
        if (amount > available) revert Error.CapExceeded();
        userDebt[appId][msg.sender] += amount;
        _totalDebtPerApp[appId] += amount;//for redeem
        _beforeMint(amount);
        _mintAppToken(appId, to, amount);
    }
    //@notice burns to get collateral back 
    //@notice reedem stablecoin for fixed 1$
    //@dev yields not inculded 
    function redeem(address stablecoin, uint256 amount) external {
        uint256 appId = _getStablecoinID(stablecoin);
        if (amount == 0) revert Error.InvalidAmount();

        if (userDebt[appId][msg.sender] < amount) revert Error.CapExceeded();
        _burnAppToken(appId, amount);
        _afterBurn(amount);
        userDebt[appId][msg.sender] -= amount;
        _totalDebtPerApp[appId] -= amount;
        IERC4626(vaults[appId]).withdraw(amount, msg.sender, address(this));
    }
    // @notice user withdraws unused collateral 
    // @dev only if no stablecoin debt exists 
    function withdrawCollateral(uint256 appId) public {
        _beforeWithdraw();
        Position storage p = positions[appId][msg.sender];
        if (userDebt[appId][msg.sender] != 0) revert Error.OutstandingDebt();
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


    function getTotalDebtPerApp(uint256 appId) external view returns(uint256 ) {
        return _totalDebtPerApp[appId];
    }
    function getPosition (uint256 appId, address user) 
        external view returns(uint256 principal, uint256 shares){
        Position memory p = positions[appId][user];
        return (p.principals, p.shares);
    }
 }
