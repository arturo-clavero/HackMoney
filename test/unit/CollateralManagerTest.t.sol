// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../src/Core/shared/CollateralManager.sol";
import "../../src/Core/shared/AccessManager.sol";

contract CollateralHarness is CollateralManager {
    constructor(address owner, address timelock, uint256 pegType)
        CollateralManager(pegType)
        AccessManager(owner, timelock)
    {}

    function getCollateral(address token)
        external
        view
        returns (CollateralConfig memory)
    {
        return collateralConfig[token];
    }

    function isAllowed(address token) external view returns (bool) {
        return _isCollateralAllowed(token);
    }
}

contract CollateralManagerTest is Test {
    address owner = address(0x1);
    address timelock = address(0x2);
    address user = address(0x3);

    uint256 constant MODE_STABLE   = 1 << 0;
    uint256 constant MODE_VOLATILE = 1 << 1;
    uint256 constant MODE_YIELD    = 1 << 2;
    uint256 constant MODE_ACTIVE   = 1 << 3;

    uint256 constant HARD_PEG = 0;
    uint256 constant MED_PEG  = 1;
    uint256 constant SOFT_PEG = 2;

//helpers 

    function _input(address token, uint256 mode)
        internal
        pure
        returns (CollateralInput memory)
    {
        return CollateralInput({
            tokenAddress: token,
            mode: mode,
            oracleFeeds: new address[](3),
            LTV: 50,
            liquidityThreshold: 80,
            debtCap: 1000
        });
    }

//constructor 

    function testHardPegAllowsStableOnly() public {
        CollateralHarness cm =
            new CollateralHarness(owner, timelock, HARD_PEG);

        vm.prank(timelock);
        cm.updateCollateral(_input(address(0xA), MODE_STABLE));

        vm.prank(timelock);
        vm.expectRevert();
        cm.updateCollateral(_input(address(0xB), MODE_YIELD));

        vm.prank(timelock);
        vm.expectRevert();
        cm.updateCollateral(_input(address(0xC), MODE_VOLATILE));
    }

    function testMedPegAllowsStableAndYield() public {
        CollateralHarness cm =
            new CollateralHarness(owner, timelock, MED_PEG);

        vm.prank(timelock);
        cm.updateCollateral(_input(address(0xA), MODE_STABLE));

        vm.prank(timelock);
        cm.updateCollateral(_input(address(0xB), MODE_YIELD));

        vm.prank(timelock);
        vm.expectRevert();
        cm.updateCollateral(_input(address(0xC), MODE_VOLATILE));
    }

    function testSoftPegAllowsStableAndVolatile() public {
        CollateralHarness cm =
            new CollateralHarness(owner, timelock, SOFT_PEG);

        vm.prank(timelock);
        cm.updateCollateral(_input(address(0xA), MODE_STABLE));

        vm.prank(timelock);
        cm.updateCollateral(_input(address(0xB), MODE_VOLATILE));

        vm.prank(timelock);
        vm.expectRevert();
        cm.updateCollateral(_input(address(0xC), MODE_YIELD));
    }

// core behavior

    function testAddCollateralAssignsIdAndActivates() public {
        CollateralHarness cm =
            new CollateralHarness(owner, timelock, HARD_PEG);

        vm.prank(timelock);
        cm.updateCollateral(_input(address(0xAAA), MODE_STABLE));

        CollateralConfig memory c = cm.getCollateral(address(0xAAA));
        assertEq(c.id, 1);
        assertTrue(c.mode & MODE_ACTIVE != 0);
    }

    function testUpdateKeepsSameId() public {
        CollateralHarness cm =
            new CollateralHarness(owner, timelock, HARD_PEG);

        vm.prank(timelock);
        cm.updateCollateral(_input(address(0xAAA), MODE_STABLE));

        CollateralInput memory updated = _input(address(0xAAA), MODE_STABLE);
        updated.LTV = 60;

        vm.prank(timelock);
        cm.updateCollateral(updated);

        assertEq(cm.getCollateral(address(0xAAA)).id, 1);
        assertEq(cm.getCollateral(address(0xAAA)).LTV, 60);
    }

    function testPauseAndUnpause() public {
        CollateralHarness cm =
            new CollateralHarness(owner, timelock, HARD_PEG);

        vm.prank(timelock);
        cm.updateCollateral(_input(address(0xAAA), MODE_STABLE));

        vm.prank(timelock);
        cm.pauseCollateral(address(0xAAA));
        assertFalse(cm.isAllowed(address(0xAAA)));

        vm.prank(timelock);
        cm.unpauseCollateral(address(0xAAA));
        assertTrue(cm.isAllowed(address(0xAAA)));
    }

    function testRemoveCollateralResetsState() public {
        CollateralHarness cm =
            new CollateralHarness(owner, timelock, HARD_PEG);

        vm.prank(timelock);
        cm.updateCollateral(_input(address(0xAAA), MODE_STABLE));

        vm.prank(timelock);
        cm.removeCollateral(address(0xAAA));

        CollateralConfig memory c = cm.getCollateral(address(0xAAA));
        assertEq(c.id, 0);
        assertEq(c.mode, 0);
    }

    function testOnlyTimelockCanMutate() public {
        CollateralHarness cm =
            new CollateralHarness(owner, timelock, HARD_PEG);

        vm.prank(user);
        vm.expectRevert();
        cm.updateCollateral(_input(address(0xAAA), MODE_STABLE));
    }
}
