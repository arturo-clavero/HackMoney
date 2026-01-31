// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/token/ERC20/ERC20.sol"; 

struct Position {
    mapping(address token => uint256 amount);
    uint256 debt;
}

/**
 * @notice ERC20 token controlled by a central engine contract.
 *          One token deployed per new App Instance.
 * @dev Minting and burning are restricted to the engine, and approvals
 *      are disabled to limit how the token can be used.
 */
contract Coin is ERC20 {

    address private _protocol;
    address private _app;
    
    //groups
    uint256 constant public ONLY_APP = 0;
    uint256 constant public APP_AND_USER = 1;
    uint256 constant public ONLY_USER = 2;

    //actions
    uint256 constant public MINT = 1 << 0;
    uint256 constant public HOLD = 1 << 1;
    uint256 constant public TRANSFER = 1 << 1;
    uint256 private _userActions;
    uint256 private _appActions;
    mapping(address user => uint256 actions) private permission;

    mapping(address token => Collateral) private supportedCollateral;
    mapping(address user => Position) private positions;

    constructor (
        address protocol,
        string memory name,
        string memory symbol,
        uint256 appActions,
        uint256 userActions,
        address[] users
    ) ERC20(name, symbol) {
        _protocol = protocol;
        _app = msg.sender;
        _userActions = userActions;
        _appActions = appActions;
        permission[msg.sender] |= appActions;
        grantPermission(users, userActions);
        if (users.length > MAX_ARRAY_LEN)
            emit event NeedToSetMorePermissions(userActions, users);
    }
    modifier onlyProtocol(){
        require(msg.sender == _protocol);
        _;
    }

    modifier onlyApp(){
        require(msg.sender == _app);
        _;
    }

//test constructor
    function getGroupActions(
        bool canMint, 
        bool canHold, 
        bool canGetTransfer
        ) external view returns (uint256 actions){
        if (canMint) actions |= MINT;
        if (canHold) actions |= HOLD;
        if (canGetTransfer) actions |= TRANSFER;
    }   

//main interactions... 
    function deposit(address token, uint256 value) external {
        _needsPermission(msg.sender, MINT);
        _isTokenSupported(token);
        //if token != address(0)
            //value == msg.value;
        // require(value > 0 || msg.value > 0);
        //transfer here
        positions[msg.sender].collateral[token] += value;
    }

    function mint(address account, uint256 value) external {
        _needsPermission(msg.sender, MINT);
        _needsPermission(account, HOLD);
        
        Position storage pos = positions[msg.sender];
        _calculateMaxMint(pos, value);
        pos.debt += value;
        _mint(account, value);

        require(_isPositionHealthy(msg.sender));
    }

    function burn(address account, uint256 value) onlyProtocol() external {
        _burn(account, value);
        positions[msg.sender].debt -= value;
        require(_isPositionHealthy(msg.sender));
    }

     function transfer(address account, uint256 value) public override returns (bool) {
        _needsPermission(account, TRANSFER);
        super.transfer(account, value);
    }

    function approve(address, uint256) public override returns (bool) {
        revert("Approvals disabled");
    }

//Permissions
    function updateUserList(address[] toAdd, address[] toRemove) external onlyApp(){}
    {
        grantPermission(toAdd, userActions);
        revokePermission(toRemove, userActions);
    }

    function _needsPermission(address user, uint256 action) internal {
        require(permission[user] & action != 0);
    }

    function grantPermission(address[] user, uint256 action) internal {
        uint256 len = user.length;
        require(len <= MAX_ARRAY_LEN);

        for (uint256 i = 0; i < len; i++){
            permission[user] |= action;
        }
    }

    function revokePermission(address[] user, uint256 action) internal {
        uint256 len = user.length;
        require(len <= MAX_ARRAY_LEN);

        for (uint256 i = 0; i < len; i++){
            permission[user] &= ~action;
        }
    }

//NO use cases?
    // function hasPermission(address[] user, uint256 action) external onlyApp() returns (bool){
    //     uint256 len = user.length;
    //     require(len <= MAX_ARRAY_LEN);

    //     for (uint256 i = 0; i < len; i++){
    //         if (permission[user] & action == 0)
    //             return false;
    //     }
    //     return true;
    // }


}