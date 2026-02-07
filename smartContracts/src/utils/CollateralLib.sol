// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

library Collateral {
     /// @dev Canonical ETH placeholder (used by inheriting contracts)
    address internal constant ETH_ADDRESS = address(0);
    /// @dev Collateral classification flags
    uint256 internal constant MODE_STABLE = 1 << 0;
    uint256 internal constant MODE_VOLATILE = 1 << 1;
    uint256 internal constant MODE_YIELD = 1 << 2;

    /// @dev Internal active/paused flag for collateral
    uint256 internal constant MODE_ACTIVE = 1 << 3;

    function allowedCollateralModes(uint256 pegType) internal pure returns (uint256 allowedModes) {
        if (pegType == 0) {
            allowedModes = 0 | MODE_STABLE;
        }
        else if (pegType == 1){
            allowedModes = 0 | MODE_STABLE | MODE_YIELD;
        }
        else {
            allowedModes = 0 | MODE_STABLE | MODE_VOLATILE;
        }
    }
}