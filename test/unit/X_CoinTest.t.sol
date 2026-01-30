// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../src/X_Coin.sol";

contract CoinTest is Test {
    Coin coin;
    address engine = address(0x123);
    address user1 = address(0x456);
    address user2 = address(0x789);

    function setUp() public {
        coin = new Coin(engine, "TestCoin", "T");

        vm.label(engine, "Engine");
        vm.label(user1, "User1");
        vm.label(user2, "User2");

        vm.startPrank(engine);
        coin.mint(user1, 1000);
        coin.mint(user2, 1000);
        coin.mint(engine, 1000);
        vm.stopPrank();
    }

    function testConstructor() public view {
        assertEq(coin.name(), "TestCoin");
        assertEq(coin.symbol(), "T");
    }

    function testMintByEngine() public {
        uint256 prevBalance = coin.balanceOf(user1);

        vm.prank(engine);
        coin.mint(user1, 1000);

        assertEq(coin.balanceOf(user1), prevBalance + 1000);
    }

    function testMintByNonEngineFails() public {
        vm.prank(user1);
        vm.expectRevert();
        coin.mint(user1, 1000);
    }

    function testBurnByEngine() public {
        uint256 prevBalance = coin.balanceOf(user1);

        vm.prank(engine);
        coin.mint(user1, 1000);

        vm.prank(engine);
        coin.burn(user1, 400);

        assertEq(coin.balanceOf(user1), prevBalance + 600);
    }

    function testBurnByNonEngineFails() public {
        vm.prank(engine);
        coin.mint(user1, 1000);

        vm.prank(user1);
        vm.expectRevert();
        coin.burn(user1, 100);
    }

    function testTransferFromByEngine() public {
        uint256 prevBalance1 = coin.balanceOf(user1);
        uint256 prevBalance2 = coin.balanceOf(user2);
        
        vm.startPrank(engine);
        coin.mint(user1, 1000);
        coin.transferFrom(user1, user2, 500);
        vm.stopPrank();

        assertEq(coin.balanceOf(user2), prevBalance2 + 500);
        assertEq(coin.balanceOf(user1), prevBalance1 + 500);
    }

    function testTransferFromByNonEngineFails() public {
        vm.prank(user1);
        vm.expectRevert();
        coin.transferFrom(user1, user2, 500);

        vm.prank(user2);
        vm.expectRevert();
        coin.transferFrom(user1, user2, 500);
    }

    function testApproveAlwaysFails() public {
        vm.prank(user1);
        vm.expectRevert();
        coin.approve(user2, 100);

        vm.prank(engine);
        vm.expectRevert();
        coin.approve(user1, 100);
    }

    function testTransferAlwaysFails() public {
        vm.prank(user1);
        vm.expectRevert();
        coin.transfer(user2, 100);

        vm.prank(engine);
        vm.expectRevert();
        coin.transfer(user1, 100);
    }
}
