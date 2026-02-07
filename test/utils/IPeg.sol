// src/interfaces/IPeg.sol
pragma solidity ^0.8.13;

import {CollateralInput} from "../../src/Core/shared/CollateralManager.sol";
import {AppInput} from "../../src/Core/shared/AppManager.sol";

interface IPeg {
    // core actions
    function deposit(uint256 id, address token, uint256 amount) external payable;
    function mint(uint256 id, address to, uint256 amount) external;
    function redeam(address token, uint256 amount) external;
    function withdrawCollateral(uint256 id, uint256 amount) external;

    // accounting
    function getTotalPool() external view returns (uint256);
    function getGlobalPool(address token) external view returns (uint256);
    function getTotalSupply() external view returns (uint256);
    function getVaultBalance(uint256 id, address user) external view returns (uint256);

    // config
    function finishSetUp(address transferOwnership) external;
    function updateGlobalCollateral(CollateralInput calldata updatedCol) external;
    function addAppCollateral(uint256 appID, address token) external;
    function newInstance(AppInput calldata config) external returns (uint256 id);
    function getAppCoin(uint256 id) external view returns (address);
    
}