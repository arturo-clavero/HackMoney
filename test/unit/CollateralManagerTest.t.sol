// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../src/Core/shared/CollateralManager.sol";
import "../../src/Core/shared/AccessManager.sol";
import "../utils/CoreLib.t.sol";

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
        return globalCollateralConfig[token];
    }

    function isAllowed(address token) external view returns (bool) {
        return _isGlobalCollateralAllowed(token);
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
        vm.prank(owner);
        cm.finishSetUp(address(0));

        CollateralInput memory input;

        vm.startPrank(timelock);
        input = Core._collateralInput(Core._newToken(), Core.COL_MODE_STABLE);
        cm.updateGlobalCollateral(input);

        input = Core._collateralInput(Core._newToken(), Core.COL_MODE_YIELD);
        vm.expectRevert();
        cm.updateGlobalCollateral(input);

        input = Core._collateralInput(Core._newToken(), Core.COL_MODE_VOLATILE);
        vm.expectRevert();
        cm.updateGlobalCollateral(input);

        vm.stopPrank();
    }

    function testMedPegAllowsStableAndYield() public {
        CollateralHarness cm =
            new CollateralHarness(owner, timelock, Core.PEG_MED);
        vm.prank(owner);
        cm.finishSetUp(address(0));

        CollateralInput memory input;

        vm.startPrank(timelock);
        input = Core._collateralInput(Core._newToken(), Core.COL_MODE_STABLE);
        cm.updateGlobalCollateral(input);

        input = Core._collateralInput(Core._newToken(), Core.COL_MODE_YIELD);
        cm.updateGlobalCollateral(input);

        input = Core._collateralInput(Core._newToken(), Core.COL_MODE_VOLATILE);
        vm.expectRevert();
        cm.updateGlobalCollateral(input);

        vm.stopPrank();
    }

    function testSoftPegAllowsStableAndVolatile() public {
        CollateralHarness cm =
            new CollateralHarness(owner, timelock, Core.PEG_SOFT);
        vm.prank(owner);
        cm.finishSetUp(address(0));

        CollateralInput memory input;

        vm.startPrank(timelock);
        input = Core._collateralInput(Core._newToken(), Core.COL_MODE_STABLE);
        cm.updateGlobalCollateral(input);

        input = Core._collateralInput(Core._newToken(), Core.COL_MODE_YIELD);
        vm.expectRevert();
        cm.updateGlobalCollateral(input);

        input = Core._collateralInput(Core._newToken(), Core.COL_MODE_VOLATILE);
        cm.updateGlobalCollateral(input);

        vm.stopPrank();
    }

// core behavior

    function testAddCollateralAssignsIdAndActivates() public {
        CollateralHarness cm =
            new CollateralHarness(owner, timelock, Core.PEG_HARD);
        vm.prank(owner);
        cm.finishSetUp(address(0));

        address tok = Core._newToken();
        vm.prank(timelock);
        cm.updateGlobalCollateral(Core._collateralInput(tok, Core.COL_MODE_STABLE));

        CollateralConfig memory c = cm.getCollateral(tok);
        assertEq(c.id, 1);
        assertTrue(c.mode & Core.COL_MODE_ACTIVE != 0);
    }

    function testUpdateKeepsSameId() public {
        CollateralHarness cm =
            new CollateralHarness(owner, timelock, Core.PEG_HARD);
        vm.prank(owner);
        cm.finishSetUp(address(0));

        address tok = Core._newToken();
        vm.prank(timelock);
        cm.updateGlobalCollateral(Core._collateralInput(tok, Core.COL_MODE_STABLE));

        CollateralInput memory updated = Core._collateralInput(tok, Core.COL_MODE_STABLE);
        updated.LTV = 60;

        vm.prank(timelock);
        cm.updateGlobalCollateral(updated);

        assertEq(cm.getCollateral(tok).id, 1);
        assertEq(cm.getCollateral(tok).LTV, 60);
    }

    function testPauseAndUnpause() public {
        CollateralHarness cm =
            new CollateralHarness(owner, timelock, Core.PEG_HARD);
        vm.prank(owner);
        cm.finishSetUp(address(0));
        
        address tok = Core._newToken();
        vm.prank(timelock);
        cm.updateGlobalCollateral(Core._collateralInput(tok, Core.COL_MODE_STABLE));

        vm.prank(timelock);
        cm.pauseGlobalCollateral(tok);
        assertFalse(cm.isAllowed(tok));

        vm.prank(timelock);
        cm.unpauseGlobalCollateral(tok);
        assertTrue(cm.isAllowed(tok));
    }

    function testremoveGlobalCollateralResetsState() public {
        CollateralHarness cm =
            new CollateralHarness(owner, timelock, Core.PEG_HARD);
        vm.prank(owner);
        cm.finishSetUp(address(0));

        address tok = Core._newToken();

        vm.prank(timelock);
        cm.updateGlobalCollateral(Core._collateralInput(tok, Core.COL_MODE_STABLE));

        vm.prank(timelock);
        cm.removeGlobalCollateral(tok);

        CollateralConfig memory c = cm.getCollateral(tok);
        assertEq(c.id, 0);
        assertEq(c.mode, 0);
    }

    function testOnlyTimelockCanMutate() public {
        CollateralHarness cm =
            new CollateralHarness(owner, timelock, Core.PEG_HARD);
        vm.prank(owner);
        cm.finishSetUp(address(0));

        address tok = Core._newToken();

        vm.startPrank(user);
        vm.expectRevert();
        cm.updateGlobalCollateral(Core._collateralInput(tok, Core.COL_MODE_STABLE));
        vm.stopPrank();
    }

    function testOwnerCanUpdateCollateral_PreSetup() public {
        CollateralHarness cm = new CollateralHarness(owner, timelock, Core.PEG_HARD);

        address tok = Core._newToken();

        vm.prank(owner);
        cm.updateGlobalCollateral(Core._collateralInput(tok, Core.COL_MODE_STABLE));

        CollateralConfig memory c = cm.getCollateral(tok);
        assertEq(c.id, 1);
        assertTrue(c.mode & Core.COL_MODE_ACTIVE != 0);
    }

}
