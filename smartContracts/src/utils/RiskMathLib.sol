
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Math} from "@openzeppelin/utils/math/Math.sol";

library RiskMath {

    uint256 constant private WAD = 1e10;

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
        if (totalAssets == 0 || totalShares == 0)
            return 0;
        _assets = Math.mulDiv(_shares, totalAssets, totalShares);
        // _assets = (_shares * totalAssets) / totalShares;
    }

    function calcShares(
        uint256 _assets,
        uint256 totalAssets,
        uint256 totalShares
    ) internal pure returns (uint256 _shares) {
        if (totalAssets == 0 || totalShares == 0)
            return _assets;
        _shares = Math.mulDiv(_assets, totalShares, totalAssets);
        // _shares = (_assets * totalShares) / totalAssets;
    }
}