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
 * Important: App registration is gated by protocol setup.
 * - The `newInstance` function can only be called after the protocol
 *   has finished its setup phase (`isSetUp = true` in AccessManager).
 * - This ensures global collateral configuration and access controls
 *   are initialized by the owner before any apps are deployed.
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

    /// @dev Emitted when an app's user list is updated.
    event UserListUpdated(uint256 indexed id, address[] added);
 
    /**
     * @notice Registers a new app instance and deploys its PrivateCoin.
     *
     * @dev
     * - Callable only after protocol setup (`onlyAfterSetUp`).
     * - Deploys a new PrivateCoin bound to the app
     * - Assigns a unique app ID
     * - Computes the app's allowed collateral set
     * - Enforces at least one valid collateral
     *
     * Collateral tokens must already be supported by the protocol.
     */
    function newInstance(AppInput calldata config) external onlyAfterSetUp() returns (uint256 id)  {
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
     * @notice Extends the authorized user list for an app.
     * @dev Only callable by the app owner.
     */
    function addUsers(uint256 id, address[] memory toAdd) public {
        AppConfig storage thisApp = appConfig[id];
        if (msg.sender != thisApp.owner)
            revert Error.InvalidAccess();

        IPrivateCoin(thisApp.coin).addUsers(toAdd);
        emit UserListUpdated(id, toAdd);
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
    function _mintAppToken(uint256 appID, address to, uint256 value) internal virtual {
        IPrivateCoin(appConfig[appID].coin).mint(msg.sender, to, value, false);
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
    function getAppCoin(uint256 id) public view returns (address){
        require (id < latestId);
        return appConfig[id].coin;
    }

    function getAppConfig(uint256 id) external view returns (AppConfig memory) {
        return appConfig[id];
    }

    function isAppCollateralAllowed(uint256 appID, address token) external view returns (bool) {
        return _isAppCollateralAllowed(appID, token);
    }
}