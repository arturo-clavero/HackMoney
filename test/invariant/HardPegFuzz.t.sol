// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../utils/FuzzEconomics.t.sol";

contract HardPegFuzzTest is FuzzEconomicTest {

    function setUp() public {
        uint256 _totalTokens = 2;
        uint256 _totalUsers = 3;
        uint256 _totalApps = 2;

        uint256[] memory modes = new uint256[](_totalTokens);
        uint8[] memory decimals = new uint8[](_totalTokens);
        modes[0] = Core.COL_MODE_STABLE;
        modes[1] = Core.COL_MODE_STABLE;
        decimals[0] = 6;
        decimals[1] = 18;

        setUpBase(modes, decimals, _totalUsers, _totalApps);
        setUpFuzz(
            100,    // ticks
            12345,   // seed
            1e18,    // initial oracle price
            10      // volatility bps
        );
    }

    function testFuzzEconomics() public {
        runFuzz();
    }
}
