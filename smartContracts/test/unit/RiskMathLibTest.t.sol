// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../src/utils/RiskMathLib.sol";

contract RiskMathTest is Test {
    using RiskMath for uint256;


    function testCalcNewShare_basic() public {
        uint256 assetChange = 100;
        uint256 totalAssets = 1000;
        uint256 totalShares = 500;

        uint256 shares = assetChange.calcNewShare(totalAssets, totalShares);

        // shares = 100 * 500 / 1000 = 50
        assertEq(shares, 50);
    }

    function testCalcNewShare_zeroTotalAssets() public {
        uint256 assetChange = 100;
        uint256 shares = assetChange.calcNewShare(0, 0);

        // first deposit, should mint 1:1
        assertEq(shares, 100);
    }

    function testCalcAssets_basic() public {
        uint256 shares = 50;
        uint256 totalShares = 500;
        uint256 totalAssets = 1000;

        uint256 assets = shares.calcAssets(totalShares, totalAssets);

        // 50 * 1000 / 500 = 100
        assertEq(assets, 100);
    }

    function testCalcShares_basic() public {
        uint256 assets = 100;
        uint256 totalAssets = 1000;
        uint256 totalShares = 500;

        uint256 shares = assets.calcShares(totalAssets, totalShares);

        // 100 * 500 / 1000 = 50
        assertEq(shares, 50);
    }
}