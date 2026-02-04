// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {CollateralManager} from "./CollateralManager.sol";
import {PrivateCoin} from "./../../PrivateCoin.sol";
import {IPrivateCoin} from "./../../interfaces/IPrivateCoin.sol";
import {Error} from "../../utils/ErrorLib.sol";

/**
 * @notice Input parameters used when registering a new app instance.
 */
struct AppInput {
    string name;
    string symbol;
    uint256 appActions;
    uint256 userActions;
    address[] users;
    address[] tokens;
}

/**
 * @notice Persistent configuration for a registered app.
 */
struct AppConfig {
    address owner;
    address coin;
    uint256 tokensAllowed;
    // address[] tokens;
}

/**
 * @title AppManager
 * @notice Factory and configuration layer for protocol app instances.
 *
 * @dev
 * Each app represents an isolated stablecoin instance with:
 * - Its own PrivateCoin (ERC-20 & ERC20-Permit)
 * - Its own access-controlled user list
 * - A scoped set of supported collateral assets
 *
 * For users depositing, collateral eligibility is enforced in two layers:
 * 1. Protocol-level support via CollateralManager
 * 2. App-level opt-in via bitmasked collateral IDs
 *
 * This contract does not implement minting/burning/transfer logic directly;
 * it provides validated internal helpers for inheriting modules.
 */
abstract contract AppManager is CollateralManager {
    
    /// @dev Maximum number of collateral types an app may enable
    uint256 private constant MAX_COLLATERAL_TYPES = 5;

    /// @dev Auto-incremented app identifier (starts at 1)
    uint256 private latestId = 1;

    /// @dev App ID => configuration
    mapping(uint256 id => AppConfig) private appConfig;

    /// @dev Stablecoin address => app ID  
    mapping(address token => uint256 id) private stablecoins;
    
    /// @dev Emitted when a new app instance is registered.
    event RegisteredApp(address indexed owner, uint256 indexed id, address coin);
 
    /**
     * @notice Registers a new app instance and deploys its PrivateCoin.
     *
     * @dev
     * - Deploys a new PrivateCoin bound to the app
     * - Assigns a unique app ID
     * - Computes the app's allowed collateral set
     * - Enforces at least one valid collateral
     *
     * Collateral tokens must already be supported by the protocol.
     */
    function newInstance(AppInput calldata config) external returns (uint256 id) {
        id = latestId;
        latestId = id + 1;

        address coin = address(new PrivateCoin(
            config.name,
            config.symbol,
            config.appActions,
            config.userActions,
            config.users,
            msg.sender
        ));

        uint256 tokensAllowed;
        uint256 len = config.tokens.length;
        if (len > MAX_COLLATERAL_TYPES)
            revert Error.MaxArrayBoundsExceeded();
        for (uint256 i = 0; i < len; i ++){
            uint256 colID = globalCollateralConfig[config.tokens[i]].id;
            if (colID == 0) continue;
            tokensAllowed |= 1 << colID;
        }
        if (tokensAllowed == 0)
            revert Error.AtLeastOneCollateralSupported();
        
        appConfig[id] = AppConfig(
            msg.sender,
            coin,
            tokensAllowed
        );

        stablecoins[coin] = id;

        emit RegisteredApp(msg.sender, id, coin);
    }

    /**
     * @notice Updates the authorized user list for an app.
     * @dev Only callable by the app owner.
     */
    function updateUserList(uint256 id, address[] memory toAdd, address[] memory toRevoke) public {
        AppConfig storage thisApp = appConfig[id];
        if (msg.sender != thisApp.owner)
            revert Error.InvalidAccess();

        IPrivateCoin(thisApp.coin).updateUserList(toAdd, toRevoke);
    }

    /**
     * @notice Enables an additional collateral asset for an app.
     * @dev Collateral must already be protocol-supported.
     */
    function addAppCollateral(uint256 appID, address token) external {
        AppConfig storage thisApp = appConfig[appID];
        if (msg.sender != thisApp.owner)
            revert Error.InvalidAccess();

        uint256 colID = globalCollateralConfig[token].id;
        if (colID == 0)
            revert Error.CollateralNotSupportedByProtocol();
        thisApp.tokensAllowed |= 1 << colID;
    }

    /**
     * @notice Removes collateral support from an app.
     * @dev At least one collateral must remain enabled.
     */
    function removeAppCollateral(uint256 appID, address token) external {
        AppConfig storage thisApp = appConfig[appID];
        if (msg.sender != thisApp.owner)
            revert Error.InvalidAccess();

        uint256 colID = globalCollateralConfig[token].id;
        if (colID == 0)
            revert Error.CollateralNotSupportedByProtocol();
        thisApp.tokensAllowed &= ~ (1 << colID);
        if (thisApp.tokensAllowed == 0)
            revert Error.AtLeastOneCollateralSupported();
    }

    /**
     * @dev Checks whether a collateral token is enabled for an app.
     */
    function _isAppCollateralAllowed(uint256 appID, address token) internal view returns (bool) {
        uint256 colID = globalCollateralConfig[token].id;
        return (appConfig[appID].tokensAllowed & 1 << colID != 0);
    }

    /**
     * @dev Mints app-specific stablecoin.
     */
    function _mintAppToken(uint256 appID, address to, uint256 value) internal{
        IPrivateCoin(appConfig[appID].coin).mint(msg.sender, to, value);
    }

    /**
     * @dev Burns app-specific stablecoin.
     */
    function _burnAppToken(uint256 appID, uint256 value) internal {
        IPrivateCoin(appConfig[appID].coin).burn(msg.sender, value);
    }

    /**
     * @dev Transfers app-specific stablecoin using permit approval.
     */
    function _transferFromAppTokenPermit(uint256 appID, address from, address to, uint256 value) internal {
        IPrivateCoin(appConfig[appID].coin).transferFrom(from, to, value);
    }

    /**
     * @dev Resolves an app ID from a stablecoin address.
     */
    function _getStablecoinID(address token) internal view returns (uint256 id) {
        id = stablecoins[token];
        if (id == 0)
            revert Error.InvalidTokenAddress();
    }

    /**
     * @dev Returns app configuration.
     */
    function _getAppConfig(uint256 id) internal view returns (AppConfig memory){
        return appConfig[id];
    }

    /**
     * @notice Returns app's private coin interface, for testing
     */
    function getAppCoin(uint256 id) external view returns (address){
        return appConfig[id].coin;
    }
}


// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {AppManager} from "./AppManager.sol";
import {Security} from "./2_Security.sol";
import {SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/interfaces/IERC20.sol";
import {RiskEngine} from "./../utils/RiskEngineLib.sol";
import {Error} from "../../utils/ErrorLib.sol";


contract HardPeg is AppManager, Security {
    using SafeERC20 for IERC20;
    using RiskEngine for address;

    /// @notice Internal scaling factor for value-to-raw conversions
    uint256 private constant DEFAULT_COIN_SCALE = 1e18;

    /// @notice Internal scaling factor used for other math (WAD)
    uint256 private constant WAD = 1e9;

    /// @notice Total value of all collateral across all apps (in "value units")
    uint256 private totalPool;

    /// @notice Total supply of all app stablecoins (in "value units")
    uint256 private totalSupply;

    /// @notice Collateral type => total value amount
    mapping(address => uint256) private globalPool;

    /// @notice App ID => user address => value amount deposited
    mapping(uint256 => mapping(address => uint256)) private vault;

    /**
     * @notice Constructor
     * @param owner Protocol owner address
     * @param timelock Protocol timelock address
     */
    constructor(address owner, address timelock)
        AppManager()
        Security()
    {
        AccessManager(owner, timelock);
        CollateralManager(0);
    }

    /**
     * @notice Deposit collateral into the app
     * @dev Only supported collateral is accepted. `rawAmount` is in token units.
     * @param id App ID
     * @param token Collateral token address
     * @param rawAmount Amount of collateral tokens to deposit
     */
    function deposit(uint256 id, address token, uint256 rawAmount) external {
        if (!_isAppCollateralAllowed(id, token))
            revert Error.CollateralNotSupportedByApp();
        if (rawAmount == 0) revert Error.InvalidAmount();

        IERC20(token).safeTransferFrom(msg.sender, address(this), rawAmount);
        uint256 valueAmount = rawAmount / globalCollateralConfig[token].scale;

        vault[id][msg.sender] += valueAmount;
        globalPool[token] += valueAmount;
        totalPool += valueAmount;
    }

  
    function mint(uint256 id, address to, uint256 rawAmount) public {
        uint256 maxValue = vault[id][msg.sender];
        uint256 valueAmount;

        if (rawAmount == type(uint256).max) rawAmount = maxValue * DEFAULT_COIN_SCALE;

        valueAmount = rawAmount / DEFAULT_COIN_SCALE;

        vault[id][msg.sender] = maxValue - valueAmount;
        totalSupply += valueAmount;
        _mintAppToken(id, to, rawAmount);
    }

    function redeam(address token, uint256 rawAmount) external {
        uint256 id = _getStablecoinID(token);
        if (rawAmount == 0) revert Error.InvalidAmount();

        uint256 valueAmount = rawAmount / DEFAULT_COIN_SCALE;
        totalSupply -= valueAmount;

        _burnAppToken(id, rawAmount);
        _sendCollateralBasket(valueAmount);
    }

  
    function withdrawCollateral(uint256 id, uint256 valueAmount) external {
        uint256 maxValue = vault[id][msg.sender];
        if (valueAmount == type(uint256).max) valueAmount = maxValue;

        vault[id][msg.sender] = maxValue - valueAmount;
        _sendCollateralBasket(valueAmount);
    }

    /// @notice Returns total value of all collateral across apps
    function getTotalPool() external view returns (uint256) {
        return totalPool;
    }

    /// @notice Returns total value of a specific collateral token
    function getGlobalPool(address token) external view returns (uint256) {
        return globalPool[token];
    }

    /// @notice Returns total supply of stablecoins across apps
    function getTotalSupply() external view returns (uint256) {
        return totalSupply;
    }

    /// @notice Returns the vault balance of a user in value units
    function getVaultBalance(uint256 id, address user) external view returns (uint256) {
        return vault[id][user];
    }

    /**
     * @notice Internal helper to send pro-rata collateral basket
     * @dev Distributes `valueAmount` proportionally across all supported collateral tokens.
     *      Leaves minimal dust in the pool due to integer division rounding.
     * @param valueAmount Amount in value units to send
     */
    function _sendCollateralBasket(uint256 valueAmount) internal {
        uint256 _totalPool = totalPool;
        uint256 _totalSent;
        uint256 len = globalCollateralSupported.length;

        for (uint256 i = 0; i < len; i++) {
            address token = globalCollateralSupported[i];
            uint256 proRataValue = (valueAmount * globalPool[token]) / _totalPool;

            globalPool[token] -= proRataValue;
            _totalSent += proRataValue;

            uint256 proRataRaw = proRataValue * globalCollateralConfig[token].scale;
            IERC20(token).safeTransfer(msg.sender, proRataRaw);
        }

        totalPool -= _totalSent;
    }
}
