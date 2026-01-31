// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Storage} from "./1_Storage.sol";

struct AppUXConfig {
    bytes32 userListRoot;
    address app;
    //separate int
    uint8 minterGroup;
    uint8 minterToGroup;
    uint8 transferToGroup;

    //separate int
    address[] collateralAllowed;
}

struct MinStoredConfig {
    bytes32 userListRoot;
    address appOwner;
    uint256 configMode;
    uint256 collateralSupported;
    //+
    address coin;

    //??
    // mapping(address=>Positions) positions
}

/**
 * @notice Management for each app instance
 * @dev stores app specific configurations and manages adding new instances
 */
abstract contract AppManager is Storage {
    uint256 private latestId;
    mapping(uint256 AppId => MinStoredConfig) internal appData;

    function newInstance(AppUXConfig calldata config) external {
        //new address
        //add address and other data to store in intsance
        //set app data + 1
        //set app coins + 1
        //new ROLE APP+ID? //
        //new ROLE MINTER+ID?
    }

    function updateUserList() external {}
}