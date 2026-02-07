// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/Timelock.sol";
import "../mocks/MockTarget.sol";


contract TimelockTest is Test {
    Timelock timelock;
    MockTarget target;

    address owner = address(0x1);
    address oracle = address(0x2);
    address stranger = address(0x3);

    uint256 constant ORACLE_ROLE = 1;

    bytes4 constant SET_VALUE_SELECTOR =
        MockTarget.setValue.selector;

    function setUp() public {
        vm.startPrank(owner);

        target = new MockTarget();
        timelock = new Timelock();

        timelock.setTimelockOwner(owner);

        target.setRole(ORACLE_ROLE, oracle, true);

        timelock.setSelector(
            SET_VALUE_SELECTOR,
            CallConfig({
                role: ORACLE_ROLE,
                delay: 1 days,
                gracePeriod: 2 days
            })
        );

        vm.stopPrank();
    }

    function testOracleCanQueue() public {
        bytes memory data =
            abi.encodeWithSelector(SET_VALUE_SELECTOR, 123);

        vm.prank(oracle);
        bytes32 txHash = timelock.queue(address(target), data, ORACLE_ROLE);

        assertTrue(timelock.queuedTx(txHash));
    }

    function testNonRoleCannotQueue() public {
        bytes memory data =
            abi.encodeWithSelector(SET_VALUE_SELECTOR, 123);

        vm.prank(stranger);
        vm.expectRevert();
        timelock.queue(address(target), data, ORACLE_ROLE);
    }

    function testInvalidSelectorReverts() public {
        bytes memory data =
            abi.encodeWithSelector(bytes4(0xdeadbeef), 1);

        vm.prank(oracle);
        vm.expectRevert();
        timelock.queue(address(target), data, ORACLE_ROLE);
    }

    function testExecuteAfterDelay() public {
        bytes memory data =
            abi.encodeWithSelector(SET_VALUE_SELECTOR, 777);

        vm.prank(oracle);
        bytes32 txHash = timelock.queue(address(target), data, ORACLE_ROLE);

        uint256 deadline = block.timestamp + 1 days;

        vm.warp(deadline + 1);
        timelock.execute(address(target), data, deadline);

        assertEq(target.value(), 777);
        assertFalse(timelock.queuedTx(txHash));
    }

    function testCannotExecuteEarly() public {
        bytes memory data =
            abi.encodeWithSelector(SET_VALUE_SELECTOR, 777);

        vm.prank(oracle);
        timelock.queue(address(target), data, ORACLE_ROLE);

        uint256 deadline = block.timestamp + 1 days;

        vm.warp(deadline - 1);
        vm.expectRevert();
        timelock.execute(address(target), data, deadline);
    }

    function testCannotExecuteAfterGrace() public {
        bytes memory data =
            abi.encodeWithSelector(SET_VALUE_SELECTOR, 777);

        vm.prank(oracle);
        timelock.queue(address(target), data, ORACLE_ROLE);

        uint256 deadline = block.timestamp + 1 days;

        vm.warp(deadline + 2 days + 1);
        vm.expectRevert();
        timelock.execute(address(target), data, deadline);
    }

    function testOwnerCanCancel() public {
        bytes memory data =
            abi.encodeWithSelector(SET_VALUE_SELECTOR, 123);

        vm.prank(oracle);
        bytes32 txHash = timelock.queue(address(target), data, ORACLE_ROLE);

        vm.prank(owner);
        timelock.cancel(address(target), data, block.timestamp + 1 days);

        assertFalse(timelock.queuedTx(txHash));
    }

    function testNonOwnerCannotCancel() public {
        bytes memory data =
            abi.encodeWithSelector(SET_VALUE_SELECTOR, 123);

        vm.prank(oracle);
        timelock.queue(address(target), data, ORACLE_ROLE);

        vm.prank(stranger);
        vm.expectRevert();
        timelock.cancel(address(target), data, block.timestamp + 1 days);
    }
}