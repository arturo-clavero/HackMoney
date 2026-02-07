// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../src/core/shared/Oracle.sol";
import "../../src/core/shared/CollateralManager.sol";
import "../../src/core/shared/AccessManager.sol";
import "../mocks/MockOracle.sol";
import "../utils/CoreLib.t.sol";

/// @notice Test harness - makes Oracle concrete so we can deploy it
contract OracleHarness is Oracle {
    constructor(address owner, address timelock, uint256 pegType)
        CollateralManager(pegType)
        AccessManager(owner, timelock)
    {}
}

contract OracleTest is Test {
    OracleHarness oracle;
    MockAggregator mockFeed;

    address owner = address(0x1);
    address timelock = address(0x2);
    address aUSDC;

    function setUp() public {
        oracle = new OracleHarness(owner, timelock, core.PEG_MED);
        mockFeed = new MockAggregator("aUSDC / USD", 8);
        aUSDC = core._newToken();
        vm.prank(owner);
        oracle.finishSetUp(address(0));
        vm.prank(timelock);
        oracle.updateGlobalCollateral(
            core._collateralInputWithFeed(aUSDC, core.COL_MODE_YIELD, address(mockFeed))
        );
    }

    function test_getPrice_ReturnsCorrectPrice() public {
        // Set price to $1.05 (yield token appreciated)
        // Chainlink uses 8 decimals: 1e8 = $1.00
        mockFeed.setPrice(105_000_000);

        uint256 price = oracle.getPrice(aUSDC);

        assertEq(price, 105_000_000);
    }

    function test_getPrice_RevertsOnZeroPrice() public {
        mockFeed.setPrice(0);

        // vm.expectRevert tells Foundry: "the next call MUST revert"
        // We pass the expected error selector + arguments
        vm.expectRevert(
            abi.encodeWithSelector(
                Oracle.Oracle__InvalidPrice.selector,
                address(mockFeed),
                int256(0)
            )
        );
        oracle.getPrice(aUSDC);
    }

    function test_getPrice_RevertsOnStalePrice() public {
        mockFeed.setPrice(100_000_000);

        // vm.warp sets block.timestamp to a specific value
        // Jump 25 hours into the future (past the 24h threshold)
        vm.warp(block.timestamp + 25 hours);

        vm.expectRevert();  // Just check it reverts (simpler form)
        oracle.getPrice(aUSDC);
    }

    function test_getPrice_RevertsOnNoFeed() public {
        address unknownToken = address(0xDEAD);

        vm.expectRevert(
            abi.encodeWithSelector(
                Oracle.Oracle__NoFeedConfigured.selector,
                unknownToken
            )
        );
        oracle.getPrice(unknownToken);
    }

    // FUZZ TEST: Foundry generates random values for `rawPrice`
    // and runs this test 256 times (by default)
    function testFuzz_AcceptsAnyPositivePrice(int256 rawPrice) public {
        // vm.assume = "skip this run if condition is false"
        vm.assume(rawPrice > 0);

        mockFeed.setPrice(rawPrice);
        uint256 price = oracle.getPrice(aUSDC);

        assertEq(price, uint256(rawPrice));
    }
}
