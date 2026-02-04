// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Error} from "../../utils/ErrorLib.sol";

/**
 * @title AccessManager
 * @notice Centralized role-based access control for protocol-level permissions.
 *
 * @dev
 * Roles are stored as bitflags inside a single uint256 for gas efficiency.
 * A single address may hold multiple roles simultaneously.
 *
 * Role management is intentionally centralized:
 * - Only the OWNER can grant or revoke roles.
 * - Timelock execution is enforced for sensitive global configuration updates.
 *
 * This contract is intended to be inherited by core protocol modules.
 */
abstract contract AccessManager {
    /**
     * @dev OWNER
     * Protocol owner with full administrative control.
     *
     * Expected to be a multisig or governance-controlled security module.
     * Capabilities:
     * - Grant and revoke all roles
     * - Emergency intervention (via inheriting contracts)
     */
    uint256 constant private OWNER = 1 << 0;
    
    /**
     * @dev COLLATERAL_MANAGER
     * Manages protocol-wide collateral configuration.
     *
     * Capabilities:
     * - Add or update supported collateral assets
     * - Modify global collateral parameters
     *
     * Note:
     * Applications may only use collateral that has been approved
     * and configured at the protocol level.
     */
    uint256 constant public COLLATERAL_MANAGER = 1 << 1;

    /**
     * @dev ORACLE_MANAGER
     * Manages oracle configuration and price feed security.
     *
     * Capabilities:
     * - Register or update oracle sources
     * - Maintain oracle-related risk parameters
     */
    uint256 constant public ORACLE_MANAGER = 1 << 2;

    /**
     * @dev GOVERNOR
     * Emergency control role.
     *
     * Capabilities:
     * - Pause critical protocol actions
     *
     * Intended for risk mitigation and incident response.
     */
    uint256 constant public GOVERNOR = 1 << 3;
    
    /// @dev Immutable protocol owner
    address immutable private owner;

    /// @dev External timelock contract used for delayed execution
    address private timelock;

    /// @dev Mapping of user address to assigned role bitmask
    mapping(address user => uint256 roleBits) internal roles;

    /**
     * @param _owner Protocol owner (expected to be multisig)
     * @param _timelock Timelock contract used for queued execution
     */    
     constructor(address _owner, address _timelock) {
        owner = _owner;
        timelock = _timelock;
        roles[_owner] |= OWNER;
    }

    /**
     * @dev Restricts access to accounts holding a specific role.
     */
    modifier onlyRole(uint256 role){
        if(roles[msg.sender] & role == 0)
            revert Error.InvalidAccess();
        _;
    }

    /**
     * @dev Restricts access to the protocol owner.
     */
    modifier onlyOwner(){
        if(msg.sender != owner)
            revert Error.InvalidAccess();
        _;
    }

    /**
     * @dev Restricts execution to the timelock contract.
     *
     * Used for functions that modify global or high-risk parameters.
     */
    modifier onlyTimeLock() {
        if (msg.sender != timelock)
            revert Error.InvalidAccess();
        _;
    }

    /**
     * @notice Checks whether a user holds a specific role.
     * @param user Address to query
     * @param role Role bit to check
     */
    function hasRole(address user, uint256 role) external view returns (bool) {
        return roles[user] & role != 0;
    }

    /**
     * @notice Grants a role to a user.
     * @dev Only callable by the OWNER.
     */
    function grantRole(address user, uint256 role) external onlyOwner() {
        roles[user] |= role;
    }

    /**
     * @notice Revokes a role from a user.
     * @dev Only callable by the OWNER.
     */
    function revokeRole(address user, uint256 role) external onlyOwner {
        roles[user] &= ~role;
    }
}