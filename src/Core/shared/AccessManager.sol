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
 * - isSetUp flag: ensures protocol configuration phase is protected
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


    /**
    * @dev The `isSetUp` flag ensures there is a **protected deployment/configuration phase**:
    * - Prevents accidental use of uninitialized protocol modules
    * - Guarantees atomicity for initial collateral registration, app creation permissions, etc.
    * - All app instances and user-facing interactions are disabled until setup is finished
    */
    bool private isSetUp = false;
    
    /// @dev protocol owner
    address private owner;

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
    * @dev The `onlyTimeLock` modifier dynamically switches behavior:
    * - During initial deployment (`!isSetUp`), the OWNER can call timelock-protected functions
    *   to perform setup tasks like registering collateral, configuring protocol parameters, etc.
    * - After setup (`isSetUp`), only the timelock contract can call these functions, ensuring
    *   delayed execution and governance control.
    */
    modifier onlyTimeLock() {
        if (isSetUp && msg.sender != timelock)
            revert Error.InvalidAccess();
        else if (!isSetUp && msg.sender != owner)
            revert Error.InvalidAccess();
        _;
    }

    modifier onlyAfterSetUp() {
        if (!isSetUp)
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

    /**
    * @notice Marks protocol as fully configured.
    *
    * @dev FinishSetUp performs two key tasks atomically:
    * 1. Sets `isSetUp = true`, which:
    *    - Prevents further calls that are only allowed during initial deployment
    *    - Enables app instance creation
    *    - Locks certain protocol-level configurations to timelock-only execution
    * 2. Optionally transfers ownership to the final governance or multisig address
    *
    * Security notes:
    * - `transferOwnership` should typically be the multisig or governance contract
    * - Must only be called **once** to prevent multiple handovers
    * - Any temporary deployer privileges exist only during deployment and setup
    */
    function finishSetUp(address transferOwnership) external onlyOwner {
        if (transferOwnership != address(0))
            owner = transferOwnership;
        isSetUp = true;
    }
}
