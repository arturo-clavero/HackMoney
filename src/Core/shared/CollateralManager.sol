// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {AccessManager} from "./AccessManager.sol";

struct CollateralConfig { //using in contract storage
    uint256     id;
    address     tokenAddress;
    uint256     mode;
    address[]   oracleFeeds;
    uint256     LTV;
    uint256     liquidityThreshold;
    uint256     debtCap;
}

struct CollateralInput { //from front-end (function inputs)
    address     tokenAddress;
    uint256     mode;
    address[]   oracleFeeds;
    uint256     LTV;
    uint256     liquidityThreshold;
    uint256     debtCap;
}

/**
 * @dev Collateral modes are bitflags, so multiple modes can be allowed for a peg type:
 *      - STABLE = 1 << 0
 *      - VOLATILE = 1 << 1
 *      - YIELD = 1 << 2
 *      - PAUSED = 1 << 3
 *
 *      `i_allowedCollateralModes` defines which modes are permitted for this Storage instance.
 */

abstract contract CollateralManager is AccessManager {
    uint256 public constant MODE_STABLE = 1 << 0;
    uint256 public constant MODE_VOLATILE = 1 << 1;
    uint256 public constant MODE_YIELD = 1 << 2;
    uint256 private constant MODE_ACTIVE = 1 << 3;
    address internal constant ETH_ADDRESS = address(0);

    uint256 private immutable i_allowedCollateralModes;
    uint256 private lastCollateralId = 1;
    mapping(address token => CollateralConfig) internal collateralConfig;
    address[] internal globalCollateralSupport;

    constructor(uint256 pegType) {
        if (pegType == 0) {
            i_allowedCollateralModes |= MODE_STABLE;
        }
        else if (pegType == 1){
            i_allowedCollateralModes |= MODE_STABLE;
            i_allowedCollateralModes |= MODE_YIELD;
        }
        else {
            i_allowedCollateralModes |= MODE_STABLE;
            i_allowedCollateralModes |= MODE_VOLATILE;
        }
    }

    //add new collateral or update previously added
    function updateCollateral(CollateralInput calldata updatedCol) external onlyTimeLock(){
        require(i_allowedCollateralModes & updatedCol.mode != 0);
        CollateralConfig storage c = collateralConfig[updatedCol.tokenAddress];
        
        if (c.id == 0){
            c.id = lastCollateralId++;
            c.tokenAddress = updatedCol.tokenAddress;
            globalCollateralSupport.push(updatedCol.tokenAddress);
        }
        c.mode = updatedCol.mode | MODE_ACTIVE;
        c.oracleFeeds = updatedCol.oracleFeeds;
        c.LTV = updatedCol.LTV;
        c.liquidityThreshold = updatedCol.liquidityThreshold;
        c.debtCap = updatedCol.debtCap;
    }    
        

    function removeCollateral(address tokenAddress) external onlyTimeLock(){
        delete collateralConfig[tokenAddress];
    }

    function pauseCollateral(address tokenAddress) external onlyTimeLock(){
        collateralConfig[tokenAddress].mode &= ~MODE_ACTIVE;
    }

    function unpauseCollateral(address tokenAddress) external onlyTimeLock(){
        collateralConfig[tokenAddress].mode |= MODE_ACTIVE;
    }

//helpers:
    function _isCollateralAllowed(address tokenAddress) internal view returns (bool){
        return collateralConfig[tokenAddress].mode & MODE_ACTIVE != 0;
    }

    function _getCollateralID(address tokenAddress) internal view returns (uint256){
        return collateralConfig[tokenAddress].id;
    }

}