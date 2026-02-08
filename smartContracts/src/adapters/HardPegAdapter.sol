// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./IStablePeg.sol";
import "../core/HardPeg.sol";

contract HardPegAdapter is IStablePeg {
    HardPeg public peg;

    constructor(address _peg) {
        peg = HardPeg(_peg);
    }

//interactions

    function deposit(uint256 appId, address token, uint256 amount) external override {
        peg.deposit(appId, token, amount);
    }

    function withdrawCollateral(uint256 appId, uint256 amount) external override {
        peg.withdrawCollateral(appId, amount);
    }

    function mint(uint256 appId, address to, uint256 amount) external override {
        peg.mint(appId, to, amount);
    }

    function redeem(uint256 appId, uint256 amount) external override {     
        peg.redeem(peg.getAppCoin(appId), amount);
    }


//shared logic
    function updateGlobalCollateral(CollateralInput calldata updatedCol) external{
        return peg.updateGlobalCollateral(updatedCol);
    }
    function getGlobalCollateralList() external view returns (address[] memory){
        return peg.getGlobalCollateralList();
    }
    function newInstance(AppInput calldata config) external returns (uint256 id){
        return peg.newInstance(config);
    }
    function addUsers(uint256 id, address[] memory toAdd) external {
        return peg.addUsers(id, toAdd);
    }
    function addAppCollateral(uint256 appID, address token) external {
        return peg.addAppCollateral(appID, token);
    }
    function removeAppCollateral(uint256 appID, address token) external{
        return peg.removeAppCollateral(appID, token);
    }

}