// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/// @title IStablePeg
/// @notice Common interface for frontend to interact with any peg type
interface IStablePeg {
//setup
    function updateGlobalCollateral(CollateralInput calldata updatedCol) external;
    function getGlobalCollateralList() external view returns (address[] memory);

//app deployment
    function newInstance(AppInput calldata config) external returns (uint256 id);
    
//interactions
    function deposit(uint256 appId, address token, uint256 amount) external;
    function depositTo(uint256 appId, address to, address token, uint256 rawAmount) external;
    function withdrawCollateral(uint256 appId, uint256 amount) external;
    function withdrawCollateralTo(uint256 appId, address to, uint256 amount) external;
    function mint(uint256 appId, address to, uint256 amount) external;
    function redeem(uint256 appId, uint256 amount) external;

//app configurations
    function addUsers(uint256 id, address[] memory toAdd) external;
    function addAppCollateral(uint256 appID, address token) external;
    function removeAppCollateral(uint256 appID, address token) external;
}