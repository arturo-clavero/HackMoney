// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/token/ERC20/ERC20.sol"; 

library Actions {
    uint256 constant public MAX_ARRAY_LEN = 50;

    //groups
    uint256 constant public ONLY_APP = 0;
    uint256 constant public APP_AND_USER = 1;
    uint256 constant public ONLY_USER = 2;

    //actions
    uint256 constant public MINT = 1 << 0;
    uint256 constant public HOLD = 1 << 1;
    uint256 constant public TRANSFER = 1 << 1;

    function getGroupActions(
        bool canMint, 
        bool canHold, 
        bool canGetTransfer
        ) internal pure returns (uint256 actions){
        if (canMint) actions |= MINT;
        if (canHold) actions |= HOLD;
        if (canGetTransfer) actions |= TRANSFER;
    }   
}


struct Collateral {
    address     tokenAddress;//0 -> ETH
    address[]   oracleFeeds;
    uint256     LTV;
    uint256     liquidityThreshold;
    uint256     debtCap;
    uint256       mode;
}

struct Position {
    mapping(address token => uint256 amount) collateral;
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

    uint256 private _userActions;
    uint256 private _appActions;
    mapping(address user => uint256 actions) private _permission;

    mapping(address token => Collateral) private _supportedCollateral;
    address[] allowedTokens;
    mapping(address user => Position) private _positions;

    event NeedToSetMorePermissions(uint256 actions, address[] users);
    
    constructor (
        address protocol,
        address owner,
        string memory name,
        string memory symbol,
        uint256 appActions,
        uint256 userActions,
        address[] memory users,
        Collateral[] memory cacheCollateral
    ) ERC20(name, symbol) {

        _protocol = protocol;
        _app = owner;
        _userActions = userActions;
        _appActions = appActions;
        _permission[owner] |= appActions;
        grantPermission(users, userActions);

        //collateral
        uint256 len = supportedTokens.length;
        require (len < Actions.MAX_ARRAY_LEN);
        for (uint256 i = 0; i < len; i ++){
            _supportedCollateral[cacheCollateral[i].tokenAddress] = cacheCollateral[i];
        }

        if (users.length > Actions.MAX_ARRAY_LEN)
            emit NeedToSetMorePermissions(userActions, users);
    }

    modifier onlyProtocol(){
        require(msg.sender == _protocol);
        _;
    }

    modifier onlyApp(){
        require(msg.sender == _app);
        _;
    }
    

    function deposit(address token, uint256 value) external {
        _needsPermission(msg.sender, Actions.MINT);
        require(_supportedCollateral[token].liquidityThreshold > 0);
        if (token == address(0)) {// ETH deposit 
            require(msg.value > 0);
            value = msg.value;
        } else { //ERC20 deposit
            require(msg.value == 0);
            require(value > 0);
            //safe transfer?
            IERC20(token).transferFrom(msg.sender, address(this), value);
            _positions[msg.sender].collateral[token] += value;
        }   
        _positions[msg.sender].collateral[address(0)] += value;
        // Position storage pos = _positions[msg.sender];
        // pos.collateral[token] += value;
    }
        

    function mint(address account, uint256 value) external {
        _needsPermission(msg.sender, Actions.MINT);
        _needsPermission(account, Actions.HOLD);
        //secure_mint
        Position storage pos = _positions[account];
        require(value < _calculateMaxMint(pos, value));
        pos.debt += value;
        _mint(account, value);

        require(_isPositionHealthy(account));
    }

    function burn(address account, uint256 value) onlyProtocol() external {
        _burn(account, value);
        _positions[account].debt -= value;
        require(_isPositionHealthy(account));
    }

     function transfer(address account, uint256 value) public override returns (bool) {
        _needsPermission(account, Actions.TRANSFER);
        return super.transfer(account, value);
    }

    function approve(address, uint256) public override returns (bool) {
        revert("Approvals disabled");
    }

//Permissions
    function updateUserList(address[] calldata toAdd, address[] calldata toRemove) external onlyApp() {
        grantPermission(toAdd, _userActions);
        revokePermission(toRemove, _userActions);
    }

    function grantPermission(address[] memory users, uint256 action) internal {
        uint256 len = users.length;
        if (len > Actions.MAX_ARRAY_LEN){
            len = Actions.MAX_ARRAY_LEN;
            emit NeedToSetMorePermissions(action, users);
        }

        for (uint256 i = 0; i < len; i++){
            _permission[users[i]] |= action;
        }
    }

    function revokePermission(address[] calldata users, uint256 action) internal {
        uint256 len = users.length;
        if (len > Actions.MAX_ARRAY_LEN){
            len = Actions.MAX_ARRAY_LEN;
            emit NeedToSetMorePermissions(action, users);
        }

        for (uint256 i = 0; i < len; i++){
            _permission[users[i]] &= ~action;
        }
    }

    function _needsPermission(address user, uint256 action) internal view {
        require(_permission[user] & action != 0);
    }

//helpers :
    function _isPositionHealthy(address user) internal returns (bool) {
        Position storage pos = _positions[user];
        uint256 colValue;
        uint256 len = tokensAllowed.length;
        for (uint256 i = 0; i < len; i ++){
            address token = tokensAllowed[i];
            uint256 amount = pos.collateral[token];
            uint256 price = getPrice(token, amount); //cross contract !
            colValue += collateral[token].liquidityThreshold * price * amount;
        }
        return (colValue < pos.debt);
    }

    function _calculateMaxMint(Positions storage pos) internal returns(uint256 maxMint) {
        uint256 maxMint;
        uint256 len = tokensAllowed.length;
        for (uint256 i = 0; i < len; i ++){
            address token = tokensAllowed[i];
            uint256 amount = pos.collateral[token];
            uint256 price = getPrice(token, amount); //cross contract !
            maxMint += collateral[token].LTV * price * amount;
        }
        maxMint -= debt;
    }
}