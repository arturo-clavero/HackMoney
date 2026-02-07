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
    function deposit(
        uint256 appId,
        uint256 assets)
     external {
        depositTo(appId, msg.sender, assets);
    }

    function depositTo(
        uint256 appId,
        address to,
        uint256 assets)
     public {
    // @notice vault grows principal stayes unchanged
        address vault = vaults[appId];
        if (vault == address(0)) revert Error.InvalidTokenAddress();
        IERC20 asset = IERC20(IERC4626(vault).asset());
        asset.safeTransferFrom(to, address(this), assets);
        asset.approve(vault, assets);
        uint256 shares = IERC4626(vault).deposit(assets, address(this));
        uint256 valueAtDeposit = IERC4626(vault).convertToAssets(shares);
        Position storage p = positions[appId][to];
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
        userDebt[appId][msg.sender] -= amount;
        _totalDebtPerApp[appId] -= amount;
        IERC4626(vaults[appId]).withdraw(amount, msg.sender, address(this));
    }
    // @notice user withdraws unused collateral 
    // @dev only if no stablecoin debt exists 
    function withdrawCollateral(uint256 appId) external {
        withdrawCollateralTo(appId, msg.sender);
    }

    function withdrawCollateralTo(uint256 appId, address to) public {
        Position storage p = positions[appId][to];
        if (userDebt[appId][to] != 0) revert Error.OutstandingDebt();
        uint256 shares = p.shares;
        if (shares == 0) revert Error.InvalidAmount();

        p.shares = 0;
        p.principals = 0;

        IERC4626(vaults[appId]).redeem(
            shares,
            to,
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

 ////

 // SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {AccessManager} from "./shared/AccessManager.sol";
import {CollateralManager} from "./shared/CollateralManager.sol";
import {Security} from "./shared/Security.sol";
import {AppManager} from "./shared/AppManager.sol";
import {SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/interfaces/IERC20.sol";
import {RiskMath} from "../utils/RiskMathLib.sol";
import {Error} from "../utils/ErrorLib.sol";


/**
 * @title HardPeg
 * @notice Stablecoin system backed by a basket of supported collateral tokens.
 * @dev
 * Each HardPeg instance:
 *  - Tracks collateral in "value units" for internal accounting.
 *  - Mints a 1:1 ratio of app coins against collateral.
 *  - Supports redemption and collateral withdrawal in pro-rata fashion.
 *  - No liquidations or price oracles are used in this implementation.
 */
contract HardPeg is AppManager, Security {

    using SafeERC20 for IERC20;

    /// @notice Total value of all collateral across all apps (in "value units")
    uint256 private totalPool;

    /// @notice Total supply of all app stablecoins (in "value units")
    uint256 private totalSupply;                                     

    /// @notice Collateral type => total value amount
    mapping(address colType => uint256 valueAmount) private globalPool; 
    
    /// @notice App ID => user address => value amount deposited
    mapping (uint256 id =>
        mapping(address user => uint256 valueAmount)) private vault; 
        
    /**
     * @notice Constructor
     * @param owner Protocol owner address
     * @param timelock Protocol timelock address
     */
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
     * @notice Deposit collateral into the app
     * @dev Only supported collateral is accepted. `rawAmount` is in token units.
     * @param id App ID
     * @param token Collateral token address
     * @param rawAmount Amount of collateral tokens to deposit
     */
    function deposit(uint256 id, address token, uint256 rawAmount) external {
        depositTo(id, msg.sender, token, rawAmount); 
    }

    /**
     * @notice Deposit collateral to a sepcific account into the app
     * @dev Only supported collateral is accepted. `rawAmount` is in token units.
     * @param id App ID
     * @param to Account who will own the deposited tokens
     * @param token Collateral token address
     * @param rawAmount Amount of collateral tokens to deposit
     */
    function depositTo(uint256 id, address to, address token, uint256 rawAmount) public {
        if (!_isAppCollateralAllowed(id, token))
            revert Error.CollateralNotSupportedByApp();
        if (rawAmount == 0)
            revert Error.InvalidAmount();
        IERC20(token).safeTransferFrom(to, address(this), rawAmount);
        uint256 valueAmount = rawAmount / globalCollateralConfig[token].scale;
        vault[id][to] += valueAmount;
        globalPool[token] += valueAmount;
        totalPool += valueAmount;
    }

    /**
     * @notice Mint app stablecoins
     * @dev Mints at 1:1 ratio of `valueAmount` against available collateral.
     * @param id App ID
     * @param to Recipient address
     * @param rawAmount Amount of stablecoins to mint (in raw units). Use `type(uint256).max` to mint max available.
     */
    function mint(uint256 id, address to, uint256 rawAmount) external {
        uint256 maxValue = vault[id][msg.sender];
        uint256 valueAmount;
        if (rawAmount == type(uint256).max)
            rawAmount = maxValue * RiskMath.DEFAULT_COIN_SCALE;

        valueAmount = rawAmount / RiskMath.DEFAULT_COIN_SCALE;

        vault[id][msg.sender] = maxValue - valueAmount;
        totalSupply += valueAmount;
        _mintAppToken(id, to, rawAmount);
    }

    /**
     * @notice Redeem app stablecoins for underlying collateral
     * @param token App stablecoin token address
     * @param rawAmount Amount of stablecoins to redeem (in raw units)
     */
    function redeem(address token, uint256 rawAmount) external {
        uint256 id = _getStablecoinID(token);
        if (rawAmount == 0)
            revert Error.InvalidAmount();
        uint256 valueAmount = rawAmount / RiskMath.DEFAULT_COIN_SCALE;
        totalSupply -= valueAmount;
        _burnAppToken(id, rawAmount);
        _sendCollateralBasket(valueAmount, msg.sender);
    }

    /**
     * @notice Withdraw collateral directly from the vault
     * @param id App ID
     * @param valueAmount Amount of value units to withdraw. Use `type(uint256).max` to withdraw all available.
     */
    function withdrawCollateralTo(uint256 id, address to, uint256 valueAmount) public {
        uint256 maxValue = vault[id][msg.sender];
        if (valueAmount == type(uint256).max)
            valueAmount = maxValue;
        vault[id][msg.sender] = maxValue - valueAmount;
        _sendCollateralBasket(valueAmount, to);
    }

      /**
     * @notice Withdraw collateral directly from the vault
     * @param id App ID
     * @param valueAmount Amount of value units to withdraw. Use `type(uint256).max` to withdraw all available.
     */
    function withdrawCollateral(uint256 id, uint256 valueAmount) external {
        withdrawCollateralTo(id, msg.sender, valueAmount);
    }

    /// @notice Returns total value of all collateral across apps
    function getTotalPool() external view returns (uint256){
        return totalPool;
    }

    /// @notice Returns total value of a specific collateral token
    function getGlobalPool(address token) external view returns (uint256){
        return globalPool[token];
    }

    /// @notice Returns total supply of stablecoins across apps
    function getTotalSupply() external view returns (uint256){
        return totalSupply;
    }

    /// @notice Returns the vault balance of a user in value units
    function getVaultBalance(uint256 id, address user) external view returns (uint256) {
        return (vault[id][user]);
    }

    /**
     * @notice Internal helper to send pro-rata collateral basket
     * @dev Distributes `valueAmount` proportionally across all supported collateral tokens.
     *      Leaves minimal dust in the pool due to integer division rounding.
     * @param valueAmount Amount in value units to send
     */
    function _sendCollateralBasket(uint256 valueAmount, address to) internal {
        uint256 _totalPool = totalPool;
        uint256 _totalSent;
        uint256 len = globalCollateralSupported.length;

        for (uint256 i = 0; i < len; i++){
            address token = globalCollateralSupported[i];
            uint256 proRataValue = (valueAmount *  globalPool[token]) / _totalPool;
            globalPool[token] -= proRataValue;
            _totalSent += proRataValue;
            uint256 proRataRaw = proRataValue * globalCollateralConfig[token].scale;
            IERC20(token).safeTransfer(to, proRataRaw);
        }
        totalPool -= _totalSent;
    }

}