// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/interfaces/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";

import {IAggregatorV3} from "../../../src/interfaces/IAggregatorV3.sol";
import {IPrivateCoin} from "../../../src/interfaces/IPrivateCoin.sol";

import {CollateralConfig, CollateralInput} from "../../../src/Core/shared/CollateralManager.sol";
import {AppConfig, AppInput} from "../../../src/Core/shared/AppManager.sol";
import {PrivateCoin} from "../../../src/PrivateCoin.sol";

import "./Lib.sol";
//START //28649

abstract contract AccessManager {
    bool private isSetUp = false;
    address private owner;
    address private timelock;
    mapping(address user => uint256 roleBits) internal roles;
   
    constructor(address _owner, address _timelock) {
        owner = _owner;
        timelock = _timelock;
        roles[_owner] |= Shared.OWNER;
    }
    modifier onlyRole(uint256 role){
        if(roles[msg.sender] & role == 0)
            revert Error.InvalidAccess();
        _;
    }
    modifier onlyOwner(){
        if(msg.sender != owner)
            revert Error.InvalidAccess();
        _;
    }
//modified for testing:
    modifier onlyTimeLock() {
        if ( msg.sender != owner)
            revert Error.InvalidAccess();
        _;
    }

    modifier onlyAfterSetUp() {
        if (!isSetUp)
            revert Error.InvalidAccess();
        _;
    }

    // function hasRole(address user, uint256 role) external view returns (bool) {
    //     return roles[user] & role != 0;
    // }

    function grantRole(address user, uint256 role) external onlyOwner() {
        roles[user] |= role;
    }

    function revokeRole(address user, uint256 role) external onlyOwner {
        roles[user] &= ~role;
    }

    function finishSetUp(address transferOwnership) external onlyOwner {
        if (transferOwnership != address(0))
            owner = transferOwnership;
        isSetUp = true;
    }
}

//28325

abstract contract CollateralManager is AccessManager {
    uint256 private immutable i_allowedCollateralModes;
    uint256 private lastCollateralId = 1;
    mapping(address token => CollateralConfig) internal globalCollateralConfig;
    address[] internal globalCollateralSupported;


    constructor(uint256 pegType) {
        i_allowedCollateralModes = Shared.getAllowedCollateralMode(pegType);
    }

    function updateGlobalCollateral(CollateralInput calldata updatedCol) external onlyTimeLock(){
        if (i_allowedCollateralModes & updatedCol.mode == 0)
            revert Error.InvalidMode();
        CollateralConfig storage c = globalCollateralConfig[updatedCol.tokenAddress];
        
        if (c.id == 0){
            c.id = lastCollateralId++;
            c.tokenAddress = updatedCol.tokenAddress;
            uint8 decimals = updatedCol.tokenAddress == address(0) ? 18 : IERC20Metadata(updatedCol.tokenAddress).decimals();
            c.decimals = decimals;
            c.scale = 10 ** decimals;
            globalCollateralSupported.push(updatedCol.tokenAddress);
        }
        c.mode = updatedCol.mode | Shared.MODE_ACTIVE;
        c.oracleFeeds = updatedCol.oracleFeeds;
        c.LTV = updatedCol.LTV;
        c.liquidityThreshold = updatedCol.liquidityThreshold;
        c.debtCap = updatedCol.debtCap;
    }    
        
    function removeGlobalCollateral(address tokenAddress) external onlyTimeLock(){
        delete globalCollateralConfig[tokenAddress];
    }

    function pauseGlobalCollateral(address tokenAddress) external onlyTimeLock(){
        globalCollateralConfig[tokenAddress].mode &=  Shared.MODE_ACTIVE;
    }

    function unpauseGlobalCollateral(address tokenAddress) external onlyTimeLock(){
        globalCollateralConfig[tokenAddress].mode |= Shared.MODE_ACTIVE;
    }

    // function _isGlobalCollateralAllowed(address tokenAddress) internal view returns (bool){
    //     return globalCollateralConfig[tokenAddress].mode & Shared.MODE_ACTIVE != 0;
    // }

    // function _getGlobalCollateralID(address tokenAddress) internal view returns (uint256){
    //     return globalCollateralConfig[tokenAddress].id;
    // }

}

//reduction -> 28154

abstract contract AppManager is CollateralManager {
    
   

    uint256 private latestId = 1;

    mapping(uint256 id => AppConfig) private appConfig;
    mapping(address token => uint256 id) private stablecoins;
    
    event RegisteredApp(address indexed owner, uint256 indexed id, address coin);
 
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
        if (len > Shared.MAX_COLLATERAL_TYPES)
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
    function addUsers(uint256 id, address[] memory toAdd, address[] memory toRevoke) public {
        AppConfig storage thisApp = appConfig[id];
        if (msg.sender != thisApp.owner)
            revert Error.InvalidAccess();

        IPrivateCoin(thisApp.coin).addUsers(toAdd);
    }
    function addAppCollateral(uint256 appID, address token) external {
        AppConfig storage thisApp = appConfig[appID];
        if (msg.sender != thisApp.owner)
            revert Error.InvalidAccess();

        uint256 colID = globalCollateralConfig[token].id;
        if (colID == 0)
            revert Error.CollateralNotSupportedByProtocol();
        thisApp.tokensAllowed |= 1 << colID;
    }
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
    function _isAppCollateralAllowed(uint256 appID, address token) internal view returns (bool) {
        uint256 colID = globalCollateralConfig[token].id;
        return (appConfig[appID].tokensAllowed & 1 << colID != 0);
    }
    function _mintAppToken(uint256 appID, address to, uint256 value) internal{
        IPrivateCoin(appConfig[appID].coin).mint(msg.sender, to, value);
    }
    function _burnAppToken(uint256 appID, uint256 value) internal {
        IPrivateCoin(appConfig[appID].coin).burn(msg.sender, value);
    }
    // function _transferFromAppTokenPermit(uint256 appID, address from, address to, uint256 value) internal {
    //     IPrivateCoin(appConfig[appID].coin).transferFrom(from, to, value);
    // }
    function _getStablecoinID(address token) internal view returns (uint256 id) {
        id = stablecoins[token];
        if (id == 0)
            revert Error.InvalidTokenAddress();
    }
    // function _getAppConfig(uint256 id) internal view returns (AppConfig memory){
    //     return appConfig[id];
    // }
    // function getAppCoin(uint256 id) external view returns (address){
    //     require (id < latestId);
    //     return appConfig[id].coin;
    // }
}

//28006
abstract contract Security is AccessManager{
    bool private mintPaused;
    bool private withdrawPaused;
    uint256 private globalDebtCap;
    uint256 private mintCapPerTransaction;

    event MintPaused(address indexed by);
    event WithdrawPaused(address indexed by);

    constructor (
        uint256 _globalDebtCap, 
        uint256 _mintCapPerTx
    ) {
        if (_globalDebtCap == 0) revert Error.InvalidCapValue();
        if(_mintCapPerTx == 0) revert Error.InvalidCapValue();
        if (_mintCapPerTx > _globalDebtCap) revert Error.InvalidCapValue();
        globalDebtCap = _globalDebtCap;
        mintCapPerTransaction = _mintCapPerTx;
    }

    modifier mintAllowed() {
        require (mintPaused == false, "Mint is not allowed");
        _;

    }
    modifier withdrawAllowed() {
        require(withdrawPaused == false, "Withdraw is not allowed");
        _;
    }

    function pauseMint() external onlyOwner {
        if (mintPaused == true) revert Error.AlreadyPaused();
        mintPaused = true;
        emit MintPaused(msg.sender);
    }

    function unpauseMint() external onlyTimeLock {
        if (!mintPaused) revert Error.AlreadyUnpaused();
        mintPaused = false;
    }

    function pauseWithdraw() external onlyOwner {
        if (withdrawPaused) revert Error.AlreadyPaused();
        withdrawPaused = true;
        emit WithdrawPaused(msg.sender);
    }

    function unpauseWithdraw() external onlyTimeLock {
        if (!withdrawPaused) revert Error.AlreadyUnpaused();
        withdrawPaused = false;
    }

    function updateGlobalDebtCap(uint256 newGlobalDebtCap) external onlyTimeLock {
        if (newGlobalDebtCap == 0) revert Error.InvalidCapValue();
        if (mintCapPerTransaction > newGlobalDebtCap) revert Error.InvalidCapValue();
        globalDebtCap = newGlobalDebtCap;
    }
    function updateMintCapPerTx(uint256 newMintCapPerTransaction) external onlyTimeLock {
        if (newMintCapPerTransaction == 0) revert Error.InvalidCapValue();
        mintCapPerTransaction = newMintCapPerTransaction;
    }
}

contract HardPeg is AppManager, Security {

    using SafeERC20 for IERC20;

    uint256 private constant DEFAULT_COIN_SCALE = 1e18;

    uint256 private totalPool;

    uint256 private totalSupply;                                     

    mapping(address colType => uint256 valueAmount) private globalPool; 
    
    mapping (uint256 id =>
        mapping(address user => uint256 valueAmount)) private vault; 
        
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
    function deposit(uint256 id, address token, uint256 rawAmount) external {
        if (!_isAppCollateralAllowed(id, token))
            revert Error.CollateralNotSupportedByApp();
        if (rawAmount == 0)
            revert Error.InvalidAmount();
        IERC20(token).safeTransferFrom(msg.sender, address(this), rawAmount);
        uint256 valueAmount = rawAmount / globalCollateralConfig[token].scale;
        vault[id][msg.sender] += valueAmount;
        globalPool[token] += valueAmount;
        totalPool += valueAmount;
    }

    function mint(uint256 id, address to, uint256 rawAmount) public {
        uint256 maxValue = vault[id][msg.sender];
        uint256 valueAmount;
        if (rawAmount == type(uint256).max)
            rawAmount = maxValue * DEFAULT_COIN_SCALE;

        valueAmount = rawAmount / DEFAULT_COIN_SCALE;

        vault[id][msg.sender] = maxValue - valueAmount;
        totalSupply += valueAmount;
        _mintAppToken(id, to, rawAmount);
    }

    function redeam(address token, uint256 rawAmount) external {
        uint256 id = _getStablecoinID(token);
        if (rawAmount == 0)
            revert Error.InvalidAmount();
        uint256 valueAmount = rawAmount / DEFAULT_COIN_SCALE;
        totalSupply -= valueAmount;
        _burnAppToken(id, rawAmount);
        _sendCollateralBasket(valueAmount);
    }

    function withdrawCollateral(uint256 id, uint256 valueAmount) external {
        uint256 maxValue = vault[id][msg.sender];
        if (valueAmount == type(uint256).max)
            valueAmount = maxValue;
        vault[id][msg.sender] = maxValue - valueAmount;
        _sendCollateralBasket(valueAmount);
    }

    // function getTotalPool() external view returns (uint256){
    //     return totalPool;
    // }

    // function getGlobalPool(address token) external view returns (uint256){
    //     return globalPool[token];
    // }

    // function getTotalSupply() external view returns (uint256){
    //     return totalSupply;
    // }

    // function getVaultBalance(uint256 id, address user) external view returns (uint256) {
    //     return (vault[id][user]);
    // }

    function _sendCollateralBasket(uint256 valueAmount) internal {
        uint256 _totalPool = totalPool;
        uint256 _totalSent;
        uint256 len = globalCollateralSupported.length;

        for (uint256 i = 0; i < len; i++){
            address token = globalCollateralSupported[i];
            uint256 proRataValue = (valueAmount *  globalPool[token]) / _totalPool;
            globalPool[token] -= proRataValue;
            _totalSent += proRataValue;
            uint256 proRataRaw = proRataValue * globalCollateralConfig[token].scale;
            IERC20(token).safeTransfer(msg.sender, proRataRaw);
        }
        totalPool -= _totalSent;
    }

}

//27616