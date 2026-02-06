// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {AccessManager} from "./AccessManager.sol";
import {IERC20Metadata} from "@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";
import {Error} from "../../utils/ErrorLib.sol";

/**
 * @notice Input structure used when updating collateral configuration.
 */
struct CollateralInput {
    address     tokenAddress;
    uint256     mode;
    address[]   oracleFeeds;
    uint256     LTV;
    uint256     liquidityThreshold;
    uint256     debtCap;
}

/**
 * @notice Persistent configuration for a supported collateral asset.
 */
struct CollateralConfig {
    uint256     id;
    address     tokenAddress;
    uint256     decimals;
    uint256     scale;
    uint256     mode;
    address[]   oracleFeeds;
    uint256     LTV;
    uint256     liquidityThreshold;
    uint256     debtCap;
}

/**
 * @title CollateralManager
 * @notice Global registry and configuration layer for protocol collateral assets.
 *
 * @dev
 * Collateral support is enforced at the protocol level and shared by all apps.
 * Each collateral asset is assigned a stable, non-zero ID used for bitmasking
 * and downstream accounting.
 *
 * Collateral modes are expressed as bitflags, allowing a single asset to satisfy
 * multiple risk categories (e.g. stable + yield).
 *
 * After "set-up" all state-changing operations are restricted to the timelock to ensure
 * delayed execution and governance oversight.
 * During "set-up" all state-changing operations are restricted to the owner, to ensure
 * easy (non-delayed) configurations post-deployment.
 */
abstract contract CollateralManager is AccessManager {
    /// @dev Collateral classification flags
    uint256 public constant MODE_STABLE = 1 << 0;
    uint256 public constant MODE_VOLATILE = 1 << 1;
    uint256 public constant MODE_YIELD = 1 << 2;

    /// @dev Internal active/paused flag
    uint256 private constant MODE_ACTIVE = 1 << 3;

    /// @dev Canonical ETH placeholder (used by inheriting contracts)
    address internal constant ETH_ADDRESS = address(0);

    /// @dev Allowed collateral modes for this deployment (peg-type dependent)
    uint256 private immutable i_allowedCollateralModes;

    /// @dev Auto-incremented collateral identifier (starts at 1)
    uint256 private lastCollateralId = 1;

    /// @dev Token address => collateral configuration
    mapping(address token => CollateralConfig) internal globalCollateralConfig;

    /// @dev List of all collateral tokens ever registered
    address[] internal globalCollateralSupported;


    /**
     * @param pegType Determines which collateral modes are allowed.
     *
     * pegType semantics are deployment-specific, but typically represent:
     * - Stable-only pegs
     * - Stable + yield pegs
     * - Stable + volatile pegs
     */
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

    /**
     * @notice Adds a new collateral asset or updates an existing one.
     *
     * @dev
     * - Callable only through the timelock
     * - Enforces that the collateral mode is permitted for this deployment
     * - Newly added collateral receives a unique, non-zero ID
     * - Collateral is activated by default on update
     */
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
        c.mode = updatedCol.mode | MODE_ACTIVE;
        c.oracleFeeds = updatedCol.oracleFeeds;
        c.LTV = updatedCol.LTV;
        c.liquidityThreshold = updatedCol.liquidityThreshold;
        c.debtCap = updatedCol.debtCap;
    }    
        
    /**
     * @notice Removes collateral configuration entirely.
     * @dev Callable only through the timelock.
     */
    function removeGlobalCollateral(address tokenAddress) external onlyTimeLock(){
        delete globalCollateralConfig[tokenAddress];
    }


    /**
     * @notice Pauses a collateral asset without deleting configuration.
     * @dev Used for emergency risk mitigation.
     */
    function pauseGlobalCollateral(address tokenAddress) external onlyTimeLock(){
        globalCollateralConfig[tokenAddress].mode &= ~MODE_ACTIVE;
    }

    /**
     * @notice Reactivates a previously paused collateral asset.
     */
    function unpauseGlobalCollateral(address tokenAddress) external onlyTimeLock(){
        globalCollateralConfig[tokenAddress].mode |= MODE_ACTIVE;
    }


/////// HELPERS //////

    /**
     * @dev Returns true if collateral is active and usable.
     */
    function _isGlobalCollateralAllowed(address tokenAddress) internal view returns (bool){
        return globalCollateralConfig[tokenAddress].mode & MODE_ACTIVE != 0;
    }

    /**
     * @dev Returns the collateral ID for a token.
     */
    function _getGlobalCollateralID(address tokenAddress) internal view returns (uint256){
        return globalCollateralConfig[tokenAddress].id;
    }

    function getGlobalCollateral(address token) external view returns (CollateralConfig memory) {
        return globalCollateralConfig[token];
    }

    function getGlobalCollateralList() external view returns (address[] memory) {
        return globalCollateralSupported;
    }

}