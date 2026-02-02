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

    mapping(address colType => uint256 amount) private globalPool;
    uint256 private totalPool;

    mapping (uint256 id =>
        mapping(address user => uint256 amount)) private vault;
    
    constructor(address owner, address timelock)
    AccessManager(owner, timelock)
    CollateralManager(0)
    {}

    //should receive token / eth20 
    //increase vault amount by total deposit amount
    //increase global collateral by token... 
    function deposit(uint256 id, address token, uint256 amount) external payable {
        require(_isAppCollateralAllowed(id, token));
        if (token == address(0)) {
            // ETH deposit 
            require(msg.value != 0, "Invalid amount");
            amount = msg.value;
        } else { 
            //ERC20 deposit
            require(msg.value == 0, "Invalid amount");
            require(amount != 0, "Invalid amount");
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        }
        vault[id][msg.sender] += amount;
        globalPool[token] += amount;
        totalPool += amount;
    }

    //can mint amount or max uint256 takes max mint possible
    //mints 1:1 ratio of collateral
    //reducess collateral by 1:1 ratio
    function mint(uint256 id, address to, uint256 amount) public {
        uint256 max = vault[id][msg.sender];
        if (amount == type(uint256).max)
            amount = max;

        vault[id][msg.sender] = max - amount;
        _mintAppToken(id, to, amount);
    }

    //burns stbc give collateral basket back 1:1
    function redeam(address token, uint256 amount) external {
        uint256 id = _getStablecoinID(token);
        require(amount != 0, "Invalid amount");
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        _burnAppToken(id, amount);

        _sendCollateralBasket(id, msg.sender, amount);
    }

    //reduces collateral basket...
    //reduces user "free" collateral
    //sends back basket 1:1 amount
    function withdrawCollateral(uint256 id, uint256 amount) external {
        uint256 max = vault[id][msg.sender];
        if (amount == type(uint256).max)
            amount = max;
        vault[id][msg.sender] = max - amount; 
        _sendCollateralBasket(id, msg.sender, amount);
    }

    //user can not pick which collateral 
    //choose worse collateral? Oracle check ->  expensive but more secure
    //pro rata instead
    function _sendCollateralBasket(uint256 id, address to, uint256 amount) internal {
        uint256 _totalPool = totalPool;
        uint256 len = globalCollateralSupported.length;

        for (uint256 i = 0; i < len; i++){
            address token = globalCollateralSupported[i];
            uint256 proRata = (amount *  globalPool[token]) / totalPool;
            globalPool[token] -= proRata;
            IERC20(token).safeTransfer(msg.sender, proRata);
        }
    }

    //no liquidations... 
    // function liquidate() external {}
}