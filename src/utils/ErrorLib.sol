// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

library Error {
    error InvalidAccess();
    error InvalidPermission();
    error MaxArrayBoundsExceeded();
    error AtLeastOneCollateralSupported();
    error CollateralNotSupportedByProtocol();
    error CollateralNotSupportedByApp();
    error InvalidTokenAddress();
    error InvalidMode();
    error InvalidAmount();
}