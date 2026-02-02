// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/token/ERC20/ERC20.sol"; 
import {ERC20Permit} from "@openzeppelin/token/ERC20/extensions/ERC20Permit.sol"; 
import {Actions} from "./utils/ActionsLib.sol";

/**
 * @notice ERC20-Private token for each App.
 *         Token minting and ownership restricted to a set of users. 
 *         ERC-20 functions only accessed by the "engine" protocol.
 *
 * @dev ERC20 modifications : Minting and burning are restricted to the engine, and direct transfers
 *      and approvals are disabled. Transfers can only happen via transferFrom - no allowance required, only callable by the "engine"
 *      Permissions : MINT, HOLD, TRANSFER_DEST permissions for the owner and a list of users.
 *      User lists can be updated by the App.
 */
contract PrivateCoin is ERC20, ERC20Permit{

    address private _engine;
    address private _app;
    uint256 private _userActions;
    uint256 private _appActions;
    mapping(address user => uint256 actions) private _permission;

    event NeedToSetMorePermissions(address[] toAdd, address[] toRevoke);

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
            emit NeedToSetMorePermissions(users, new address[](0));
    }

    modifier onlyEngine(){
        require(msg.sender == _engine, "Invalid access");
        _;
    }

    function mint(address from, address to, uint256 value) onlyEngine() external {
        _needsPermission(from, Actions.MINT);
        _needsPermission(to, Actions.HOLD);
        _mint(to, value);
    }

    function burn(address account, uint256 value) onlyEngine() external {
        _burn(account, value);
    }

    function transfer(address to, uint256 value) public override returns (bool) {
        _needsPermission(to, Actions.TRANSFER_DEST);
        return super.transfer(to, value);
    }

    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        _needsPermission(to, Actions.TRANSFER_DEST);
        return super.transferFrom(from, to, value);
    }

    //Permissions
    function updateUserList(address[] memory toAdd, address[] memory toRemove) external onlyEngine() {
        bool grantsNotFinished = _grantPermission(toAdd, _userActions);
        bool revokesNotFinished =_revokePermission(toRemove, _userActions);
        if (!grantsNotFinished && !revokesNotFinished)
            emit NeedToSetMorePermissions(toAdd, toRemove);
        else if (!grantsNotFinished)
            emit NeedToSetMorePermissions(toAdd, new address[](0));
        else if (!revokesNotFinished)
            emit NeedToSetMorePermissions(new address[](0), toRemove);
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

    function _revokePermission(address[] memory users, uint256 action) private returns (bool finished){
        finished = true;
        uint256 len = users.length;
        if (len > Actions.MAX_ARRAY_LEN){
            len = Actions.MAX_ARRAY_LEN;
            finished = false;
        }

        for (uint256 i = 0; i < len; i++){
            _permission[users[i]] &= ~action;
        }
    }

    function _needsPermission(address user, uint256 action) private view {
        require(_permission[user] & action != 0, "Invalid permission");
    }

}