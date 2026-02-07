
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Math} from "@openzeppelin/utils/math/Math.sol";

library RiskMath {

     /// @dev constant used for decimal math
    uint256 internal constant WAD = 1e18;

    /// @notice Internal scaling factor for value-to-raw conversions
    uint256 internal constant DEFAULT_COIN_SCALE = 1e18;
    
    function calcNewShare(
        uint256 assetChange,     
        uint256 totalAssets, 
        uint256 totalShares
        ) internal pure returns (uint256 newShare) {
        if (totalAssets == 0 || totalShares == 0)
            return assetChange;
        newShare = Math.mulDiv(assetChange, totalShares, totalAssets);
        // newShare = (assetChange * totalShares) / totalAssets;
    }

    function calcAssets(
        uint256 _shares,
        uint256 totalShares,
        uint256 totalAssets
    ) internal pure returns (uint256 _assets) {
        _assets = safeMulDiv(_shares, totalAssets, totalShares);
        // _assets = (_shares * totalAssets) / totalShares;
    }

    function calcShares(
        uint256 _assets,
        uint256 totalAssets,
        uint256 totalShares
    ) internal pure returns (uint256 _shares) {
        _shares = safeMulDiv(_assets, totalShares, totalAssets);
        // _shares = (_assets * totalShares) / totalAssets;
    }

    function safeMulDiv(uint256 n1, uint256 n2, uint256 divisor) internal pure returns (uint256) {
        if (divisor == 0)
            return 0;
        return Math.mulDiv(n1, n2, divisor);
    }

    function safeFirstMulDiv(uint256 n1, uint256 n2, uint256 divisor) internal pure returns (uint256) {
        if (divisor == 0 || n2 == 0)
            return n1;
        return Math.mulDiv(n1, n2, divisor);
    }
}