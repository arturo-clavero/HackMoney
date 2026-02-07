// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./IStablePeg.sol";
import "../core/MediumPeg.sol";

contract MediumPegAdapter is IStablePeg {
    MediumPeg public peg;

    constructor(address _peg) {
        peg = MediumPeg(_peg);
    }

    function deposit(uint256 appId, address, uint256 amount) external override {
        // MediumPeg deposit ignores token; wrap internal call
        peg.deposit(appId, amount);
    }

    function depositTo(uint256 appId, address to, address, uint256 amount) external override {
        peg.depositTo(appId, to, amount);
    }

    function withdrawCollateral(uint256 appId, uint256) external override {
        peg.withdrawCollateral(appId);
    }

    function withdrawCollateralTo(uint256 appId, address to, uint256) external override {
        peg.withdrawCollateralTo(appId, to);
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