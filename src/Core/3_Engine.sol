// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Oracle} from "./2_Oracle.sol";
import {Security} from "./2_Security.sol";
import {AppManager} from "./2_AppManager.sol";

import {SafeERC20} from "@openzeppelin/token/ERC20/SafeERC20.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/utils/ReentrancyGuardTransient.sol";

/**
 * @notice External interactions for main "stablecoin" functions
 * @dev handles collateral deposits, withdrawals, mints, burns, redeamption, liquidation etc
 */
abstract contract Engine is Oracle, Security, AppManager, ReentrancyGuardTransient {

    using SafeERC20 for IERC20;

    function depositCollateral(uint256 id, address token, uint256 amount) external {
        require(_isAppCollateralAllowed(id, token));
        if (token == address(0)) {
            // ETH deposit 
            require(msg.value != 0, "Invalid amount");
            amount = msg.value;
        } else { 
            //ERC20 deposit
            require(msg.value == 0, "Invalid amount");
            require(amount != 0, "Invalid amount");
            safeTransferFrom
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        }
        _updatePosition(id, msg.sender, token, amount, true, false);
        //NO HEALTH CHECKS HERE ....
    }

    function withdrawCollateral(uint256 id, address token, uint256 amount) external nonReentrant() {
        require(amount != 0, "Invalid amount");
        _updatePosition(id, msg.sender, token, amount, false, true); //reverts if unhealthy...

        if (token == address(0)) {
            // ETH withdrawal
            (bool ok, ) = msg.sender.call{value: amount}("");
            require(ok, "ETH transfer failed");
        } else {
            // ERC20 withdrawal
            IERC20(token).safeTransfer(msg.sender, amount);
        }
        _isPositionHealthy(msg.sender); // should health check after this if update positon already checked?
    }

    function mintStablecoin(uint256 id, address to, uint256 amount) external {
        require(amount != 0, "Invalid amount");
        
        // _isMintingSafe(amount); -->security module
        _updatePosition(id, msg.sender, amount, true, true); //reverts if unhealthy...
        _mintAppToken(id, to, amount);
        //should health check ? -> update position already health checks.. mint app token is MY TRUSTED contract...
    }

    function repayStablecoin(uint256 id, uint256 amount) external {
        require(amount != 0, "Invalid amount");

        _updatePosition(id, msg.sender, amount, false, false);
        _burnAppToken(id, amount);//burn user's = msg.sender
        //NO HEALTH CHECKS HERE ....
    }

    //liquidate a single user... 
    function liquidate(uint256 id, address user, uint256 amount) external {
        require (!_isPositionHealthy(id, msg.sender));

        uint256 max = _updatePosition(id, msg.sender, amount, false, false);
        _burnAppToken(id, max);//burn liquidator's = msg.sender
    }
    
    //if no updates to transfer mark as NO_RISK_FT (like updateUserList) and move to APP MANAGER
    function transferStablecoin(uint256 id, address to, uint256 amount) external {
        require(amount != 0, "Invalid amount");
        _transferAppToken(id, to, amount);
        //NO HEALTH CHECKS HERE ....
    }

    //HELPERS TO INTERACT WITH POSITIONS
    function _updatePosition(uint256 id, address user, address token, uint256 collateralAmount, bool increase, bool checkHealth) internal virtual {}
    // function _updatePosition(uint256 id, address user, address token, uint256 collateralAmount, bool increase, uint256 debtAmount, bool increase, bool checkHealth);
    function _updatePosition(uint256 id, address user, uint256 debtAmount, bool increase, bool checkHealth) returns (uint256 max) internal virtual {}
    function _isPositionHealthy(uint256 id, address acount) internal virtual returns(bool){}
}


struct SinglePosition {
    uint256 collateral;
    uint256 debt;
}

contract HardPeg is Engine {
    mapping(address id => mapping(address user => SinglePosition)) private _positions;

    constructor(address owner, address timelock) 
    Storage(owner, timelock, 0){}

    function _updatePosition(uint256 id, address user, address token, uint256 collateralAmount, bool increase, bool checkHealth) internal override {}
    function _updatePosition(uint256 id, address user, uint256 debtAmount, bool increase, bool checkHealth) returns (uint256 max) internal override {}
    function _isPositionHealthy(uint256 id, address acount) internal override returns(bool){}
}

struct DoublePosition {
    uint256 stableCollateral;
    uint256 yieldCollateral;
    uint256 debt;
}

contract MediumPeg is Engine {
    mapping(address id => mapping(address user => DoublePosition)) private _positions;

    constructor(address owner, address timelock) 
    Storage(owner, timelock, 1){}

    function _updatePosition(uint256 id, address user, address token, uint256 collateralAmount, bool increase, bool checkHealth) internal override {}
    function _updatePosition(uint256 id, address user, uint256 debtAmount, bool increase, bool checkHealth) returns (uint256 max) internal override {}
    function _isPositionHealthy(uint256 id, address acount) internal override returns(bool){}
}

struct MultiCollateral {
    mapping(address collateral => uint256 amount) collateral;
    uint256 debt;
}

contract SoftPeg is Engine {
    mapping(address user => MultiPosition) private _positions;
    uint256 globalDebt;//??

    constructor(address owner, address timelock) 
    Storage(owner, timelock, 2){}

    function _updatePosition(uint256 id, address user, address token, uint256 collateralAmount, bool increase, bool checkHealth) internal override {}
    function _updatePosition(uint256 id, address user, uint256 debtAmount, bool increase, bool checkHealth) returns (uint256 max) internal override {}
    function _isPositionHealthy(uint256 id, address acount) internal override returns(bool){}
}