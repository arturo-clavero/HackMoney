// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

library Error {
    error InvalidAccess();
    error InvalidPermission();
    error MaxArrayBoundsExceeded();
    error AtLeastOneCollateralSupported();
    error CollateralNotSupportedByProtocol();
    error CollateralNotSupportedByApp();
    error MaxCollateralTypesPerPosition();
    error InvalidTokenAddress();
    error InvalidMode();
    error InvalidAmount();
    error InsufficientCollateral();
    error UserHasDebt();
    error PositionIsHealthy();
    error LiquidationDust();
    error CapExceeded();
    error OutstandingDebt();
    error TxNotQueued();
    error TxStillLocked();
    error TxExpired();
    error TxFailed();
    error InvalidTarget();
    error InvalidSelector();
    error DebtTooSmall();
}   