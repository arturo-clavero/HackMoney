// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../src/core/shared/AccessManager.sol";

contract AccessHarness is AccessManager {
    constructor(address _owner, address _timelock)
        AccessManager(_owner, _timelock)
    {}

    function onlyOwnerFn() external onlyOwner {}
    function onlyTimelockFn() external onlyTimeLock {}
    function onlyRoleFn(uint256 role) external onlyRole(role) {}
    function afterSetupFn() external onlyAfterSetUp {}

}

contract AccessTest is Test {
    AccessHarness access;

    address owner = address(0x1);
    address timelock = address(0x2);
    address user = address(0x3);

    uint256 constant OWNER = 1 << 0;
    uint256 constant COLLATERAL_MANAGER = 1 << 1;

    function setUp() public {
        access = new AccessHarness(owner, timelock);
    }

    function testGrantRole() public {
        vm.prank(owner);
        access.grantRole(user, COLLATERAL_MANAGER);

        assertTrue(access.hasRole(user, COLLATERAL_MANAGER));
    }

    function testRevokeRole() public {
        vm.startPrank(owner);
        access.grantRole(user, COLLATERAL_MANAGER);
        access.revokeRole(user, COLLATERAL_MANAGER);
        vm.stopPrank();

        assertFalse(access.hasRole(user, COLLATERAL_MANAGER));
    }

    function testOnlyOwnerCanGrant() public {
        vm.prank(user);
        vm.expectRevert();
        access.grantRole(user, COLLATERAL_MANAGER);
    }

    function testOnlyOwnerCanRevoke() public {
        vm.prank(user);
        vm.expectRevert();
        access.revokeRole(owner, OWNER);
    }

    function testOnlyOwner() public {
        vm.prank(owner);
        access.onlyOwnerFn();

        vm.prank(user);
        vm.expectRevert();
        access.onlyOwnerFn();
    }

    function testOnlyRole() public {
        vm.prank(owner);
        access.grantRole(user, COLLATERAL_MANAGER);
        vm.prank(user);
        access.onlyRoleFn(COLLATERAL_MANAGER);

        vm.prank(owner);
        access.revokeRole(user, COLLATERAL_MANAGER);
        vm.prank(user);
        vm.expectRevert();
        access.onlyRoleFn(COLLATERAL_MANAGER);
    }

    function testOnlyTimelockDuringAndAfterSetup() public {
        vm.prank(owner);
        access.onlyTimelockFn();
        vm.prank(timelock);
        vm.expectRevert();
        access.onlyTimelockFn();

        vm.prank(owner);
        access.finishSetUp(address(0));

        vm.prank(owner);
        vm.expectRevert();
        access.onlyTimelockFn();
        vm.prank(timelock);
        access.onlyTimelockFn();
    }

    function testOnlyAfterSetUp() public {
        vm.prank(owner);
        vm.expectRevert();
        access.afterSetupFn();

        vm.prank(owner);
        access.finishSetUp(address(0));

        vm.prank(owner);
        access.afterSetupFn();
    }

    function testFinishSetUpTransfersOwnership() public {
        address newOwner = address(0x99);

        vm.prank(owner);
        access.finishSetUp(newOwner);

        vm.prank(owner);
        vm.expectRevert();
        access.onlyOwnerFn();

        vm.prank(newOwner);
        access.onlyOwnerFn();
    }

    function testOnlyTimeLockModifierPhaseSensitive() public {
        vm.prank(owner);
        access.onlyTimelockFn();

        vm.prank(timelock);
        vm.expectRevert();
        access.onlyTimelockFn();

        vm.prank(owner);
        access.finishSetUp(address(0));

        vm.prank(owner);
        vm.expectRevert();
        access.onlyTimelockFn();

        vm.prank(timelock);
        access.onlyTimelockFn();
    }

    function testFinishSetUpOnlyOwner() public {
        vm.prank(user);
        vm.expectRevert();
        access.finishSetUp(address(0));
    }

    function testFinishSetUpWithZeroAddressKeepsOwner() public {
        vm.prank(owner);
        access.finishSetUp(address(0));

        vm.prank(owner);
        access.onlyOwnerFn();
    }

}