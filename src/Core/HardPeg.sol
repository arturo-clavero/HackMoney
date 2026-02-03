// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {AccessManager} from "./shared/AccessManager.sol";
import {CollateralManager} from "./shared/CollateralManager.sol";
import {Security} from "./shared/2_Security.sol";
import {AppManager} from "./shared/AppManager.sol";

import {RiskEngine} from "./../utils/RiskEngineLib.sol";

import {SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/interfaces/IERC20.sol";

/**
 * @notice Depending on the collateral the stablecoin will be a different "peg"
 * @dev Each peg system may or may not override certain functions in Engine to customize redemption liquidation and other actions
 *      Each peg system will specify different positions...
 */


/**
 * @notice Handles Stable Collateral
 */
 //No Oracle...

contract HardPeg is AppManager, Security {

    using SafeERC20 for IERC20;
    using RiskEngine for address;

    uint256 private constant WAD = 1e9;
    uint256 private constant DEFAULT_COIN_SCALE = 1e18;

    //value amount
    uint256 private totalPool;
    //value amount
    uint256 private totalSupply;                                     


    mapping(address colType => uint256 valueAmount) private globalPool; 
    mapping (uint256 id =>
        mapping(address user => uint256 valueAmount)) private vault; 
        

 //vault -> what tokens?
 //LOOP ITEARTIONS THROUGH ALL SUPPORTED COLLATERAL FOR THE APP

    constructor(address owner, address timelock)
    AccessManager(owner, timelock)
    CollateralManager(0)
    {}

    //should receive token / eth20 
    //increase vault amount by total deposit amount
    //increase global collateral by token... 
    function deposit(uint256 id, address token, uint256 rawAmount) external payable {
        require(_isAppCollateralAllowed(id, token), "invalid collateral");
        if (token == address(0)) {
            // ETH deposit 
            require(msg.value != 0, "Invalid amount");
            rawAmount = msg.value;
        } else { 
            //ERC20 deposit
            require(msg.value == 0, "Invalid amount");
            require(rawAmount != 0, "Invalid amount");
            IERC20(token).safeTransferFrom(msg.sender, address(this), rawAmount);
        }
        uint256 valueAmount = rawAmount / globalCollateralConfig[token].scale;
        vault[id][msg.sender] += valueAmount;
        globalPool[token] += valueAmount;
        totalPool += valueAmount;
    }

    //can mint amount or max uint256 takes max mint possible
    //mints 1:1 ratio of collateral
    //reducess collateral by 1:1 ratio
    //value or raw?
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

    //burns stbc give collateral basket back 1:1
    function redeam(address token, uint256 rawAmount) external {
        uint256 id = _getStablecoinID(token);
        require(rawAmount != 0, "Invalid amount");
        uint256 valueAmount = rawAmount / DEFAULT_COIN_SCALE;
        totalSupply -= valueAmount;
        _burnAppToken(id, rawAmount);
        _sendCollateralBasket(valueAmount);
    }

    //reduces collateral basket...
    //reduces user "free" collateral
    //sends back basket 1:1 amount
    function withdrawCollateral(uint256 id, uint256 valueAmount) external {
        uint256 maxValue = vault[id][msg.sender];
        if (valueAmount == type(uint256).max)
            valueAmount = maxValue;
        vault[id][msg.sender] = maxValue - valueAmount;
        _sendCollateralBasket(valueAmount);
    }

//GETTERS FOR TESTING
    function getTotalPool() external view returns (uint256){
        return totalPool;
    }

    function getGlobalPool(address token) external view returns (uint256){
        return globalPool[token];
    }

    function getTotalSupply() external view returns (uint256){
        return totalSupply;
    }


    function getVaultBalance(uint256 id, address user) external view returns (uint256) {
        return (vault[id][user]);
    }

    //user can not pick which collateral 
    //choose worse collateral? Oracle check ->  expensive but more secure
    //pro rata instead
    //leaves minimal dust in the pool ... 
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
        //left over dust from integer division roudnings
        // uint256 dustLeftinThePool = valueAmount - totalSpent;
        totalPool -= _totalSent;

    }
    //no liquidations... 
    // function liquidate() external {}
}