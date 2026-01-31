// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {Storage, Collateral} from "../../src/Core/Storage.sol";


contract TestPeg is Storage {
    constructor(address _owner, address _timelock, uint256 pegType) 
        Storage(_owner, _timelock, pegType) {}

    function getCollateralData(address tok) external view returns (Collateral memory){
    return Storage.collateralData[tok]; }

}

contract StorageTest is Test {
    TestPeg storageContract;
    address owner = address(0x1);
    address timelock = address(0x2);
    address user = address(0x3);
    uint256 COLLATERAL_MANAGER;

    function setUp() public {
        storageContract = new TestPeg(owner, timelock, 1);
        COLLATERAL_MANAGER = storageContract.COLLATERAL_MANAGER();
    }

    // Role tests
    function testGrantAndRevokeRole() public {
        vm.startPrank(owner);
        storageContract.grantRole(user, COLLATERAL_MANAGER);
        vm.stopPrank();
        assertTrue(storageContract.hasRole(user, COLLATERAL_MANAGER));

        vm.startPrank(owner);
        storageContract.revokeRole(user, COLLATERAL_MANAGER);
        vm.stopPrank();
        assertFalse(storageContract.hasRole(user, COLLATERAL_MANAGER));
    }

    function testOnlyOwnerFailsForNonOwner() public {
        vm.prank(user);
        vm.expectRevert();
        storageContract.grantRole(user, COLLATERAL_MANAGER);
    }

//COLLATERAL TESTS:
    function testUpdateCollateral() public {
        Collateral memory col = Collateral(address(0x123), new address[](4) , 50, 50, 1000, 1 << 0);

        vm.prank(timelock);
        storageContract.updateCollateral(col);

        Collateral memory stored = storageContract.getCollateralData(address(0x123));
        assertEq(stored.LTV, 50);
        assertEq(stored.debtCap, 1000);
    }

    function testRemoveCollateral() public {
        Collateral memory col = Collateral(address(0x123), new address[](6), 50, 50, 1000, 1 << 0);

        vm.prank(timelock);
        storageContract.updateCollateral(col);

        vm.prank(timelock);
        storageContract.removeCollateral(address(0x123));
        assertEq(storageContract.getCollateralData(address(0x123)).tokenAddress, address(0));
    }

    function testPauseAndUnpauseCollateral() public {
        Collateral memory col = Collateral(address(0x123), new address[](8) , 50, 50, 1000, 1 << 0);

        vm.prank(timelock);
        storageContract.updateCollateral(col);

        // Pause
        vm.prank(timelock);
        storageContract.pauseCollateral(address(0x123));
        assertEq(storageContract.getCollateralData(address(0x123)).mode & (1 << 3), 1 << 3);

        // Unpause
        vm.prank(timelock);
        storageContract.unpauseCollateral(address(0x123));
        assertEq(storageContract.getCollateralData(address(0x123)).mode & (1 << 3), 0);
    }

    function testUpdateCollateralFailsForInvalidMode() public {
        Collateral memory col = Collateral(address(0x123), new address[](3), 50, 50, 1000, storageContract.VOLATILE()); // VOLATILE not allowed in pegType 1

        vm.prank(timelock);
        vm.expectRevert();
        storageContract.updateCollateral(col);
    }
}
