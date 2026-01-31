// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../src/X_Coin.sol";

contract CoinTest is Test {
    Coin coin;
    address protocol = vm.addr(1);
    address app = vm.addr(2);
    address user1 = address(0x456);
    address user2 = address(0x789);
    address[] users = [user1, user2, vm.addr(2), vm.addr(3), vm.addr(4)];
    address[] supportedTokens = [vm.addr(4), vm.addr(5), vm.addr(6)];
    // address[] users;
    // address[] supportedTokens;

    function setUp() public {
        // coin = new Coin(engine, "TestCoin", "T");
        
        uint256 appActions = 1 << 0;
        uint256 userActions = 1 << 1;
        // address[] memory users = new address[](3);

        coin = new Coin(
            protocol,
            app,
            "name",
            "n",
            appActions,
            userActions,
            users,
            supportedTokens
        );

        vm.label(protocol, "Protocol");
        vm.label(user1, "User1");
        vm.label(user2, "User2");

        vm.startPrank(app);
        coin.mint(user1, 1000);
        coin.mint(user2, 1000);
        vm.stopPrank();
    }

    function testConstructor() public view {
        assertEq(coin.name(), "name");
        assertEq(coin.symbol(), "n");
    }

    function testBurnByProtocol() public {
        uint256 prevBalance = coin.balanceOf(user1);

        vm.prank(app);
        coin.mint(user1, 1000);

        vm.prank(protocol);
        coin.burn(user1, 400);

        assertEq(coin.balanceOf(user1), prevBalance + 600);
    }

    function testBurnByNonProtocolFails() public {
        vm.prank(app);
        coin.mint(user1, 1000);

        vm.prank(user1);
        vm.expectRevert();
        coin.burn(user1, 100);
    }

    function testTransferFromByEngine() public {
        uint256 prevBalance1 = coin.balanceOf(user1);
        uint256 prevBalance2 = coin.balanceOf(user2);
        
        vm.startPrank(protocol);
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

}
