// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../src/Core/shared/CollateralManager.sol";
import "../../src/Core/shared/AccessManager.sol";
import "./helpers/CoreLib.t.sol";

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


//constructor

    function testHardPegAllowsStableOnly() public {
        CollateralHarness cm =
            new CollateralHarness(owner, timelock, Core.PEG_HARD);

        vm.prank(timelock);
        cm.updateCollateral(Core._collateralInput(address(0xA), Core.COL_MODE_STABLE));

        vm.prank(timelock);
        vm.expectRevert();
        cm.updateCollateral(Core._collateralInput(address(0xB), Core.COL_MODE_YIELD));

        vm.prank(timelock);
        vm.expectRevert();
        cm.updateCollateral(Core._collateralInput(address(0xC), Core.COL_MODE_VOLATILE));
    }

    function testMedPegAllowsStableAndYield() public {
        CollateralHarness cm =
            new CollateralHarness(owner, timelock, Core.PEG_MED);

        vm.prank(timelock);
        cm.updateCollateral(Core._collateralInput(address(0xA), Core.COL_MODE_STABLE));

        vm.prank(timelock);
        cm.updateCollateral(Core._collateralInput(address(0xB), Core.COL_MODE_YIELD));

        vm.prank(timelock);
        vm.expectRevert();
        cm.updateCollateral(Core._collateralInput(address(0xC), Core.COL_MODE_VOLATILE));
    }

    function testSoftPegAllowsStableAndVolatile() public {
        CollateralHarness cm =
            new CollateralHarness(owner, timelock, Core.PEG_SOFT);

        vm.prank(timelock);
        cm.updateCollateral(Core._collateralInput(address(0xA), Core.COL_MODE_STABLE));

        vm.prank(timelock);
        cm.updateCollateral(Core._collateralInput(address(0xB), Core.COL_MODE_VOLATILE));

        vm.prank(timelock);
        vm.expectRevert();
        cm.updateCollateral(Core._collateralInput(address(0xC), Core.COL_MODE_YIELD));
    }

// core behavior

    function testAddCollateralAssignsIdAndActivates() public {
        CollateralHarness cm =
            new CollateralHarness(owner, timelock, Core.PEG_HARD);

        vm.prank(timelock);
        cm.updateCollateral(Core._collateralInput(address(0xAAA), Core.COL_MODE_STABLE));

        CollateralConfig memory c = cm.getCollateral(address(0xAAA));
        assertEq(c.id, 1);
        assertTrue(c.mode & Core.COL_MODE_ACTIVE != 0);
    }

    function testUpdateKeepsSameId() public {
        CollateralHarness cm =
            new CollateralHarness(owner, timelock, Core.PEG_HARD);

        vm.prank(timelock);
        cm.updateCollateral(Core._collateralInput(address(0xAAA), Core.COL_MODE_STABLE));

        CollateralInput memory updated = Core._collateralInput(address(0xAAA), Core.COL_MODE_STABLE);
        updated.LTV = 60;

        vm.prank(timelock);
        cm.updateCollateral(updated);

        assertEq(cm.getCollateral(address(0xAAA)).id, 1);
        assertEq(cm.getCollateral(address(0xAAA)).LTV, 60);
    }

    function testPauseAndUnpause() public {
        CollateralHarness cm =
            new CollateralHarness(owner, timelock, Core.PEG_HARD);

        vm.prank(timelock);
        cm.updateCollateral(Core._collateralInput(address(0xAAA), Core.COL_MODE_STABLE));

        vm.prank(timelock);
        cm.pauseCollateral(address(0xAAA));
        assertFalse(cm.isAllowed(address(0xAAA)));

        vm.prank(timelock);
        cm.unpauseCollateral(address(0xAAA));
        assertTrue(cm.isAllowed(address(0xAAA)));
    }

    function testRemoveCollateralResetsState() public {
        CollateralHarness cm =
            new CollateralHarness(owner, timelock, Core.PEG_HARD);

        vm.prank(timelock);
        cm.updateCollateral(Core._collateralInput(address(0xAAA), Core.COL_MODE_STABLE));

        vm.prank(timelock);
        cm.removeCollateral(address(0xAAA));

        CollateralConfig memory c = cm.getCollateral(address(0xAAA));
        assertEq(c.id, 0);
        assertEq(c.mode, 0);
    }

    function testOnlyTimelockCanMutate() public {
        CollateralHarness cm =
            new CollateralHarness(owner, timelock, Core.PEG_HARD);

        vm.prank(user);
        vm.expectRevert();
        cm.updateCollateral(Core._collateralInput(address(0xAAA), Core.COL_MODE_STABLE));
    }
}
