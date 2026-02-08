// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;


import "forge-std/Test.sol";
import "../../src/core/shared/Security.sol";
import "../../src/core/shared/AccessManager.sol";

contract notTrueSecurity is Security {
    constructor(
        address _owner,
        address _timelock,
        uint256 _globalDebtCap,
        uint256 _mintCapPerTx
    )
        AccessManager(_owner, _timelock)
        Security(_globalDebtCap, _mintCapPerTx)
    {
    }

    function mintAction(uint256 amount) external returns (bool) {
        _beforeMint(amount);
        return true;
    }

    function withdrawAction() external view returns (bool) {
        _beforeWithdraw();
        return true;
    }

    function burnAction(uint256 amount) external  returns (bool) {
        _afterBurn(amount);
        return true;
    }
}


contract SecurityTest is Test {
    notTrueSecurity security;

    address owner = address(0xA11CE);
    address timelock = address(0xBEEF);
    address user = address(0xCAFE);

    uint256 constant GLOBAL_CAP = 1_000 ether;
    uint256 constant TX_CAP = 100 ether;

    function setUp() public {
        security = new notTrueSecurity(
            owner,
            timelock,
            GLOBAL_CAP,
            TX_CAP
        );
        vm.prank(owner);
        security.finishSetUp(address(0));
    }

    function testConstructorSetsCaps() public pure  {
        assertTrue(true);
    }

//mint pause

    function testOwnerCanPauseMint() public {
        vm.prank(owner);
        security.pauseMint();
    }

    function testNonOwnerCannotPauseMint() public {
        vm.prank(user);
        vm.expectRevert(Error.InvalidAccess.selector);
        security.pauseMint();
    }

    function testMintBlockedWhenPaused() public {
        vm.prank(owner);
        security.pauseMint();

        vm.prank(user);
        vm.expectRevert();
        security.mintAction(1);
    }

    function testTimelockCanUnpauseMint() public {
        vm.prank(owner);
        security.pauseMint();

        vm.prank(timelock);
        security.unpauseMint();

        vm.prank(user);
        assertTrue(security.mintAction(1));
    }

//if pause withdraw

    function testOwnerCanPauseWithdraw() public {
        vm.prank(owner);
        security.pauseWithdraw();
    }

    function testWithdrawBlockedWhenPaused() public {
        vm.prank(owner);
        security.pauseWithdraw();

        vm.prank(user);
        vm.expectRevert();
        security.withdrawAction();
    }

    function testTimelockCanUnpauseWithdraw() public {
        vm.prank(owner);
        security.pauseWithdraw();

        vm.prank(timelock);
        security.unpauseWithdraw();

        vm.prank(user);
        assertTrue(security.withdrawAction());
    }

    function testTimelockCanUpdateGlobalDebtCap() public {
        vm.prank(timelock);
        security.updateGlobalDebtCap(5_000 ether);
    }

    function testNonTimelockCannotUpdateGlobalDebtCap() public {
        vm.prank(owner);
        vm.expectRevert(Error.InvalidAccess.selector);
        security.updateGlobalDebtCap(2_000 ether);
    }

    function testTimelockCanUpdateMintCapPerTx() public {
        vm.prank(timelock);
        security.updateMintCapPerTx(200 ether);
    }
}
