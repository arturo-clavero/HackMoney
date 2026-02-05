// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
 * @title Actions
 * @notice Permission and invariant validation library for PrivateCoin.
 *
 * @dev
 * This library defines the action bitflags used by PrivateCoin and enforces
 * global invariants over permission configurations.
 *
 * It is intentionally stateless and pure, and is used only at configuration
 * time to validate permission masks.
 */
library Actions {
    /// @dev Maximum number of users processed per permission update
    uint256 constant public MAX_ARRAY_LEN = 50;

    /// @dev Permission to initiate minting
    uint256 constant public MINT = 1 << 0;
    /// @dev Permission to hold a token balance
    uint256 constant public HOLD = 1 << 1;
    /// @dev Permission to receive transfers
    uint256 constant public TRANSFER_DEST = 1 << 2;

    /**
     * @notice Builds an action bitmask from boolean flags.
     */
    function getGroupActions(
        bool canMint, 
        bool canHold, 
        bool canGetTransfer
        ) internal pure returns (uint256 actions){
        if (canMint) actions |= MINT;
        if (canHold) actions |= HOLD;
        if (canGetTransfer) actions |= TRANSFER_DEST;
    }

    /**
     * @notice Validates a permission configuration for an app.
     *
     * @dev Enforced invariants:
     * - TRANSFER_DEST implies HOLD
     * - At least one actor can mint (user or app)
     * - At least one actor can hold tokens
     *
     * Reverts if the configuration violates any invariant.
     */
    function allowed(uint256 userActions, uint256 appActions) internal pure {
        transferMustHold(userActions);
        bool appTransfers = transferMustHold(appActions);
        if (appTransfers)
            require(userActions & HOLD != 0, "TRANSFERS require USERS");
        require(userActions & MINT != 0 || appActions & MINT != 0, "At least one MINTER");
        require(userActions & HOLD != 0 || appActions & HOLD != 0, "At least one HOLDER");
    }


    /**
     * @notice Enforces that transfer permissions imply holding permissions.
     *
     * @return canTransfer True if TRANSFER_DEST is enabled
     */
    function transferMustHold(uint256 actions) internal pure returns (bool canTransfer){
        canTransfer = actions & TRANSFER_DEST != 0;
        if (canTransfer)
            require(actions & HOLD != 0, "TRANSFER_DEST roles must also be HOLDER");
    }
}