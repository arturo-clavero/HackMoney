// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../src/X_PrivateCoin.sol";
import {BootstrapActions} from "./ActionsLib.t.sol";

contract PrivateCoinTest is Test {

    PrivateCoin coin;
    BootstrapActions lib;

    address engine = address(0xE);
    address app    = address(0xA);
    address user1  = address(0x1);
    address user2  = address(0x2);


    // all 3-bit combinations for MINT | HOLD | TRANSFER
    uint256[8] ACTION_SETS = [
        0,
        Actions.MINT,
        Actions.HOLD,
        Actions.TRANSFER,
        Actions.MINT | Actions.HOLD,
        Actions.MINT | Actions.TRANSFER,
        Actions.HOLD | Actions.TRANSFER,
        Actions.MINT | Actions.HOLD | Actions.TRANSFER
    ];

    function setUp() public {
        lib = new BootstrapActions();
    }

//helpers

    function isValid(uint256 userAction, uint256 appAction) internal view returns (bool) {
        try lib.allowed(userAction, appAction) {
        } catch {
            return false;
        }
        return true;
    }

    function setupCoin(uint256 appActions, uint256 userActions) internal returns (PrivateCoin) {
        return new PrivateCoin(engine, app, appActions, userActions, new address[](0),"TestCoin", "TC");
    }

    function grantUser(PrivateCoin c, address user) internal {
        address[] memory users = new address[](1);
        users[0] = user;
        vm.prank(app);
        c.updateUserList(users, new address[](0));
    }

//constructor:

    function testConstructor_AllCombos() public {
        for (uint256 u = 0; u < ACTION_SETS.length; u++) {
            for (uint256 a = 0; a < ACTION_SETS.length; a++) {
                uint256 userActions = ACTION_SETS[u];
                uint256 appActions  = ACTION_SETS[a];

                if (isValid(userActions, appActions)) {
                    setupCoin(appActions, userActions);
                } else {
                    vm.expectRevert();
                    setupCoin(appActions, userActions);
                }
            }
        }
    }

//mint :

    function testMint_AllCombos() public {
        for (uint256 u = 0; u < ACTION_SETS.length; u++) {
            for (uint256 a = 0; a < ACTION_SETS.length; a++) {
                uint256 userActions = ACTION_SETS[u];
                uint256 appActions  = ACTION_SETS[a];

                if (!isValid(userActions, appActions)) continue;

                PrivateCoin c = setupCoin(appActions, userActions);
                grantUser(c, user1);

                vm.startPrank(engine);

                bool senderCanMint   = (userActions & Actions.MINT != 0);
                bool receiverCanHold = (userActions & Actions.HOLD != 0);

                if (senderCanMint && receiverCanHold) {
                    c.mint(user1, user1, 1);
                    assertEq(c.balanceOf(user1), 1);
                } else {
                    vm.expectRevert();
                    c.mint(user1, user1, 1);
                }

                vm.stopPrank();
            }
        }
    }

//transfer: 

    function testTransferFrom_AllCombos() public {
        for (uint256 u = 0; u < ACTION_SETS.length; u++) {
            for (uint256 a = 0; a < ACTION_SETS.length; a++) {
                uint256 userActions = ACTION_SETS[u];
                uint256 appActions  = ACTION_SETS[a];

                if (!isValid(userActions, appActions)) continue;
                if (userActions & Actions.TRANSFER == 0 && appActions & Actions.TRANSFER == 0) continue;
                address minter;
                if (appActions & Actions.MINT != 0)
                    minter = app;
                else
                    minter = user1;

                PrivateCoin c = setupCoin(appActions, userActions);
                grantUser(c, user1);
                grantUser(c, user2);

                vm.prank(engine);
                c.mint(minter, user1, 2);

                vm.startPrank(engine);

                bool receiverCanTransfer = (userActions & Actions.TRANSFER != 0);

                if (receiverCanTransfer) {
                    c.transferFrom(user1, user2, 1);
                    assertEq(c.balanceOf(user2), 1);
                } else {
                    vm.expectRevert();
                    c.transferFrom(user1, user2, 1);
                }

                vm.stopPrank();
            }
        }
    }

//burn :

    function testBurn_AllCombos() public {
        for (uint256 u = 0; u < ACTION_SETS.length; u++) {
            for (uint256 a = 0; a < ACTION_SETS.length; a++) {
                uint256 userActions = ACTION_SETS[u];
                uint256 appActions  = ACTION_SETS[a];

                if (!isValid(userActions, appActions)) continue;

                address minter;
                if (appActions & Actions.MINT != 0)
                    minter = app;
                else
                    minter = user1;
                address holder;
                if (userActions & Actions.HOLD != 0)
                    holder = user1;
                else
                    holder = app;

                PrivateCoin c = setupCoin(appActions, userActions);
                grantUser(c, user1);

                vm.prank(engine);
                c.mint(minter, holder, 2);

                vm.startPrank(engine);
                c.burn(holder, 1);
                assertEq(c.balanceOf(holder), 1);
                vm.stopPrank();
            }
        }
    }

    function testBurn_RevertsIfNotEngine() public {
        PrivateCoin c = setupCoin(Actions.MINT | Actions.HOLD | Actions.TRANSFER, Actions.MINT | Actions.HOLD | Actions.TRANSFER);
        grantUser(c, user1);

        vm.prank(user1);
        vm.expectRevert();
        c.burn(user1, 1);
    }

//disabled actions:

    function testApproveAlwaysReverts() public {
        PrivateCoin c = setupCoin(Actions.MINT | Actions.HOLD | Actions.TRANSFER, Actions.MINT | Actions.HOLD | Actions.TRANSFER);
        vm.expectRevert();
        c.approve(user2, 100);
    }

    function testTransferAlwaysReverts() public {
        PrivateCoin c = setupCoin(Actions.MINT | Actions.HOLD | Actions.TRANSFER, Actions.MINT | Actions.HOLD | Actions.TRANSFER);
        vm.expectRevert();
        c.transfer(user2, 100);
    }

}
