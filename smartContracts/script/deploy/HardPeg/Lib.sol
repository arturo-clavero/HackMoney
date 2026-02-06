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
    error Oracle__NoFeedConfigured(address token);
    error Oracle__StalePrice(address feed, uint256 updatedAt, uint256 threshold);
    error Oracle__InvalidPrice(address feed, int256 price);
    error Oracle__IncompleteRound(address feed, uint80 roundId, uint80 answeredInRound);
    error AlreadyPaused();
    error AlreadyUnpaused();
    error InvalidCapValue();

}

library Shared {
    //ACCESS
    uint256 constant internal OWNER = 1 << 0;
    uint256 constant internal COLLATERAL_MANAGER = 1 << 1;
    uint256 constant internal ORACLE_MANAGER = 1 << 2;
    uint256 constant internal GOVERNOR = 1 << 3;

    //COLLATERAL MANAGER
    uint256 internal constant MODE_STABLE = 1 << 0;
    uint256 internal constant MODE_VOLATILE = 1 << 1;
    uint256 internal constant MODE_YIELD = 1 << 2;
    uint256 internal constant MODE_ACTIVE = 1 << 3;
    address internal constant ETH_ADDRESS = address(0);

    function getAllowedCollateralMode(uint256 pegType) internal returns (uint256 allowedCollateralModes) {
        
        if (pegType == 0) {
            allowedCollateralModes |= MODE_STABLE;
        }
        else if (pegType == 1){
            allowedCollateralModes |= MODE_STABLE;
            allowedCollateralModes |= MODE_YIELD;
        }
        else {
            allowedCollateralModes |= MODE_STABLE;
            allowedCollateralModes |= MODE_VOLATILE;
        }
    }

    //APP MANAGER 
     uint256 internal constant MAX_COLLATERAL_TYPES = 5;

    //ORACLE
    uint256 public constant STALENESS_THRESHOLD = 24 hours;
    uint8 public constant PRICE_DECIMALS = 8;
  
}