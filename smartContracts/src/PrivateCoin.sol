// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/token/ERC20/ERC20.sol"; 
import {ERC20Permit} from "@openzeppelin/token/ERC20/extensions/ERC20Permit.sol"; 
import {Actions} from "./utils/ActionsLib.sol";
import "./utils/ErrorLib.sol";

/**
 * @title PrivateCoin
 * @notice App-scoped ERC20 with enforced permissioned ownership and transfers.
 *
 * @dev
 * Each app deploys its own PrivateCoin instance. The token intentionally deviates
 * from standard ERC20 behavior:
 *
 * - Minting and burning are restricted to the protocol engine
 * - Token ownership is permissioned
 * - Transfers are destination-restricted
 * - Allowances are bypassed; transferFrom is engine-driven
 *
 * This design enables strict compliance, gated circulation, and
 * account-abstraction–friendly flows without exposing approval risk.
 */
contract PrivateCoin is ERC20, ERC20Permit{
    /// @dev Protocol engine authorized to mint, burn, and manage users
    address private _engine;

    /// @dev App owner controlling user permissions
    address private _app;

    /// @dev Action bitmask granted to regular users
    uint256 private _userActions;

    /// @dev Action bitmask granted to the app owner
    uint256 private _appActions;

    /// @dev Address => permission bitmask
    mapping(address account => uint256 actions) private _permission;

    /**
     * @notice Emitted when a permission update exceeds the processing limit.
     * @dev Caller must retry with the remaining addresses.
     */
    event NeedToSetMorePermissions(address[] toAdd);

    /**
     * @param name ERC20 token name
     * @param symbol ERC20 token symbol
     * @param appActions Permissions granted to the app owner
     * @param userActions Permissions granted to regular users
     * @param users Initial authorized user list
     * @param app App owner address
     */
    constructor (
        string memory name,
        string memory symbol,
        uint256 appActions,
        uint256 userActions,
        address[] memory users,   
        address app
    ) ERC20(name, symbol) ERC20Permit(name) {
        Actions.allowed(userActions, appActions);
        _engine = msg.sender;
        _app = app;
        _userActions = userActions;
        _appActions = appActions;
        _permission[app] |= appActions;
        if (!_grantPermission(users, userActions))
            emit NeedToSetMorePermissions(users);
    }

    /**
     * @dev Restricts execution to the protocol engine.
     */
    modifier onlyEngine(){
        if (msg.sender != _engine)
            revert Error.InvalidAccess();
        _;
    }

    /**
     * @notice Mints tokens to an authorized recipient.
     *
     * @dev
     * - `from` must have mint permission
     * - `to` must be permitted to hold tokens
     */
    function mint(address from, address to, uint256 value, bool isLiquidator) onlyEngine() external {
        if (!(isLiquidator && from == to)) {
            _needsPermission(from, Actions.MINT);
            _needsPermission(to, Actions.HOLD);
        }
        _mint(to, value);
    }

    /**
     * @notice Burns tokens from an account.
     * @dev No need for permissions, 'holder' checks are already enforced by mint and transfer
     */
    function burn(address account, uint256 value) onlyEngine() external {
        _burn(account, value);
    }

     /**
     * @notice Transfers tokens to an approved destination.
     *
     * @dev
     * Transfer destination must explicitly allow receiving transfers.
     * Holding and transfer permissions are intentionally decoupled.
     * Source restrictions are enforced to disable LIQUIDATORS from tranferring
     */    
    function transfer(address to, uint256 value) public override returns (bool) {
        _needsPermission(msg.sender, Actions.HOLD);
        _needsPermission(to, Actions.TRANSFER_DEST);
        return super.transfer(to, value);
    }

    /**
     * @notice Transfers tokens without allowance enforcement.
     *
     * @dev
     * - Permit signatures are supported, (allowances are intentionally unrestricted)
     * - Destination restrictions are still enforced
     * - Source restrictions are enforced to disable LIQUIDATORS from tranferring
     *
     * This enables account abstraction, bundling, and gas-efficient flows
     * without expanding the token's circulation surface.
     */
    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        _needsPermission(from, Actions.HOLD);
        _needsPermission(to, Actions.TRANSFER_DEST);
        return super.transferFrom(from, to, value);
    }

///////PERMISSION MANAGEMENT////////


    /**
     * @notice Extends the authorized user list.
     *
     * @dev
     * - Callable only by the protocol engine
     * - Processes users in bounded batches
     * - Emits an event if additional calls are required
     */
    function addUsers(address[] memory toAdd) external onlyEngine() {
        bool grantsNotFinished = _grantPermission(toAdd, _userActions);
        if (!grantsNotFinished)
            emit NeedToSetMorePermissions(toAdd);
    }

    function _grantPermission(address[] memory users, uint256 action) private returns (bool finished) {
        finished = true;
        uint256 len = users.length;
        if (len > Actions.MAX_ARRAY_LEN){
            len = Actions.MAX_ARRAY_LEN;
            finished = false;
        }

        for (uint256 i = 0; i < len; i++){
            _permission[users[i]] |= action;
        }
    }

    function _needsPermission(address user, uint256 action) private view {
        if(_permission[user] & action == 0)
            revert Error.InvalidPermission();
    }

}