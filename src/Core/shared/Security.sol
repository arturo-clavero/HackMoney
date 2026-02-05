// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {AccessManager} from "./AccessManager.sol";

/**
 * @title pausing & governance control contract
 * @notice Manages protocol-level access control and feature-level pausing for minting and withdrawals.
 * @notice globalDebtCap mintCapPerTransaction should b changed through timelock
 * @dev This abstract contract provides the following:
 *      1. Feature-level pausing: minting and withdrawals can be paused/unpaused by governance.
 *      2. Role-based access: only the owner (or timelock/governance) can change protocol-critical parameters.
 *      3. Configurable caps: global debt cap and per-transaction mint cap to limit protocol exposure.
 *      4. Modifiers (_mintAllowed, _withdrawAllowed) to enforce checks before executing mint or withdraw functions.
 *
 *      The contract does NOT automatically pause or enforce limits; all actions require explicit calls
 *      by authorized governance entities. Global emergency pause can be added separately if needed.
 *
 *      Intended usage:
 *      - Inherit this contract in protocol modules that handle minting, withdrawing, or debt management.
 *      - Apply modifiers to functions to enforce feature-level restrictions.
 *      - Governance (owner or timelock) manages the flags and caps via the provided external functions.
 */

 //Check if current mint by user is safe...
 //     - mint paused
 //     - global debt cap = check + update
 //     - mint cap per tx/ per block = check + update

//Deliverables : function is mint allowed for this user right now ? 

abstract contract Security is AccessManager{
    bool private mintPaused;
    bool private withdrawPaused;
    uint256 private globalDebtCap;
    uint256 private mintCapPerTransaction;
    uint256 public totalDebt; // total across the protocol

    event MintPaused(address indexed by);
    // event MintUnpaused(address indexed by);
    event WithdrawPaused(address indexed by);
    // event WithdrawUnpaused(address indexed by);
    // event globalDebtCapUpdated(uint256 oldCap, uint256 newCap);
    // event mintCapPerTransactionUpdated(uint256 oldCap, uint256 newCap);

    error AlreadyPaused();
    error AlreadyUnpaused();
    error InvalidCapValue();
    error MintIsPaused();
    error InvalidAmount();
    error CapExceeded();
    error GlobalCapExceeded();

    constructor (
        uint256 _globalDebtCap, 
        uint256 _mintCapPerTx
    ) {
        if (_globalDebtCap == 0) revert InvalidCapValue();
        if(_mintCapPerTx == 0) revert InvalidCapValue();
        if (_mintCapPerTx > _globalDebtCap) revert InvalidCapValue();
        globalDebtCap = _globalDebtCap;
        mintCapPerTransaction = _mintCapPerTx;
    }

    modifier mintAllowed() {
        require (mintPaused == false, "Mint is not allowed");
        _;

    }
    modifier withdrawAllowed() {
        require(withdrawPaused == false, "Withdraw is not allowed");
        _;
    }

     /// @notice security gate for the peg
    function beforeMint(uint256 valueAmount) internal {
        if (mintPaused) revert MintIsPaused();
        if (valueAmount == 0) revert InvalidAmount();
        if (valueAmount > mintCapPerTransaction)
            revert CapExceeded();
        uint256 newDebt = totalDebt + valueAmount;
        if (newDebt > globalDebtCap)
            revert GlobalCapExceeded();
        totalDebt = newDebt;
    }
    /// @notice Pauses minting. Can only be called by the owner.
    function pauseMint() external onlyOwner {
        if (mintPaused == true) revert AlreadyPaused();
        mintPaused = true;
        emit MintPaused(msg.sender);
    }

    /// @notice Unpauses minting. Can only be called by governance timelock.
    function unpauseMint() external onlyTimeLock {
        if (!mintPaused) revert AlreadyUnpaused();
        mintPaused = false;
        // emit MintUnpaused(msg.sender);
    }

    /// @notice Pauses withdrawals. Can only be called by the owner.
    function pauseWithdraw() external onlyOwner {
        if (withdrawPaused) revert AlreadyPaused();
        withdrawPaused = true;
        emit WithdrawPaused(msg.sender);
    }

    /// @notice Unpauses withdrawals. Can only be called by governance timelock.
    function unpauseWithdraw() external onlyTimeLock {
        if (!withdrawPaused) revert AlreadyUnpaused();
        withdrawPaused = false;
        // emit WithdrawUnpaused(msg.sender);
    }

    ///  @notice Updates the global debt cap. Requires timelock governance.
    function updateGlobalDebtCap(uint256 newGlobalDebtCap) external onlyTimeLock {
        if (newGlobalDebtCap == 0) revert InvalidCapValue();
        if (mintCapPerTransaction > newGlobalDebtCap) revert InvalidCapValue();
        // uint256 oldCap = globalDebtCap;
        globalDebtCap = newGlobalDebtCap;
        // emit globalDebtCapUpdated(oldCap, newGlobalDebtCap);
    }
    /// @notice Updates the maximum mint per transaction. Can only be called by governance timelock.
    function updateMintCapPerTx(uint256 newMintCapPerTransaction) external onlyTimeLock {
        if (newMintCapPerTransaction == 0) revert InvalidCapValue();
        // uint256 oldCap = mintCapPerTransaction;
        mintCapPerTransaction = newMintCapPerTransaction;
        // emit mintCapPerTransactionUpdated(oldCap, newMintCapPerTransaction);
    }
}