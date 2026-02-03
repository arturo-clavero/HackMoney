// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// import {CollateralManager} from "./CollateralManager.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";
// import {Timelock} from "../../Y_Timelock.sol";

/**
 * @title pausing & governance control contract
 * @notice Manages protocol-level access control and feature-level pausing for minting and withdrawals.
 *
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

abstract contract Security is Ownable{

    bool private mintPaused;
    bool private withdrawPaused;
    uint256 private globalDebtCap;
    uint256 private mintCapPerTransaction;
    address private timeLock;

    event MintPaused(address indexed by);
    // event MintUnpaused(address indexed by);
    event WithdrawPaused(address indexed by);
    // event WithdrawUnpaused(address indexed by);
    // event globalDebtCapUpdated(uint256 oldCap, uint256 newCap);
    // event mintCapPerTransactionUpdated(uint256 oldCap, uint256 newCap);

    error AlreadyPaused();
    error AlreadyUnpaused();
    error InvalidCapValue();

    constructor (
        uint256 _globalDebtCap, 
        uint256 _mintCapPerTx,
        address _owner,
        address _timelock 
    ) Ownable(_owner) {
        if (_globalDebtCap == 0) revert InvalidCapValue();
        if(_mintCapPerTx == 0) revert InvalidCapValue();
        if (_mintCapPerTx > _globalDebtCap) revert InvalidCapValue();
        timeLock = _timelock;
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
    modifier onlyTimeLock() {
        require(msg.sender == timeLock, "Not timelock");
        _;
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
    // function _isOwnerMultiSig() internal {
        
    // }
}