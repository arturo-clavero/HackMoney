// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../src/PrivateCoin.sol";
import {BootstrapActions} from "./ActionsLibTest.t.sol";
import "../utils/CoreLib.t.sol";

contract PrivateCoinTest is Test {

    PrivateCoin coin;
    BootstrapActions lib;

    address engine = address(0xE);
    address app    = address(0xA);
    address user1;
    uint256 user1Pk;
    address user2  = address(0x2);
    address spender  = address(0x5);


    // all 3-bit combinations for MINT | HOLD | TRANSFER_DEST
    uint256[8] ACTION_SETS = [
        0,
        Actions.MINT,
        Actions.HOLD,
        Actions.TRANSFER_DEST,
        Actions.MINT | Actions.HOLD,
        Actions.MINT | Actions.TRANSFER_DEST,
        Actions.HOLD | Actions.TRANSFER_DEST,
        Actions.MINT | Actions.HOLD | Actions.TRANSFER_DEST
    ];

    function setUp() public {
        (user1, user1Pk) = makeAddrAndKey("alice");
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

    function setupCoin(uint256 appActions, uint256 userActions) internal returns (PrivateCoin pc) {
        vm.prank(engine);
        pc = new PrivateCoin(
            "TestCoin", 
            "TC", 
            appActions, 
            userActions, 
            new address[](0),
            app
        );
    }

    function grantUser(PrivateCoin c, address user) internal {
        address[] memory users = new address[](1);
        users[0] = user;
        vm.prank(engine);
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


    function _setUpTransfer(uint256 userActions, uint256 appActions) internal returns (PrivateCoin, address) {        

        if (!isValid(userActions, appActions)) return (setupCoin(Actions.MINT, Actions.HOLD), address(0));


        if (
            userActions & Actions.TRANSFER_DEST == 0 &&
            appActions & Actions.TRANSFER_DEST == 0
        ) return (setupCoin(Actions.MINT, Actions.HOLD), address(0));

        PrivateCoin c = setupCoin(appActions, userActions);
        grantUser(c, user1);
        grantUser(c, user2);

        address minter = (appActions & Actions.MINT != 0) ? app : user1;

        vm.prank(engine);
        c.mint(minter, user1, 2);

        return (c, minter);
    }

    function testTransfer_AllCombos() public {
        for (uint256 u = 0; u < ACTION_SETS.length; u++) {
            for (uint256 a = 0; a < ACTION_SETS.length; a++) {
                uint256 userActions = ACTION_SETS[u];
                uint256 appActions  = ACTION_SETS[a];
                (PrivateCoin c, address minter) = _setUpTransfer(userActions, appActions);
                if (minter == address(0)) continue;
            
                bool receiverCanReceive = (userActions & Actions.TRANSFER_DEST != 0);

                vm.startPrank(user1);
                if (receiverCanReceive) {
                    c.transfer(user2, 1);
                    assertEq(c.balanceOf(user2), 1);
                } else {
                    vm.expectRevert(Error.InvalidPermission.selector);
                    c.transfer(user2, 1);
                }
                vm.stopPrank();
            }
        }
    }

    function testTransferFrom_WithPermit_AllCombos() public {
        uint256 deadline = block.timestamp + 1 days;

        for (uint256 u = 0; u < ACTION_SETS.length; u++) {
            for (uint256 a = 0; a < ACTION_SETS.length; a++) {
                uint256 userActions = ACTION_SETS[u];
                uint256 appActions  = ACTION_SETS[a];
                (PrivateCoin c, address minter) = _setUpTransfer(userActions, appActions);
                if (minter == address(0)) continue;

                bytes32 digest = Core.getDigest(address(c), user1, spender, 1, deadline);
                (uint8 v, bytes32 r, bytes32 s) = vm.sign(user1Pk, digest);
                c.permit(user1, spender, 1, deadline, v, r, s);

                bool receiverCanReceive = (userActions & Actions.TRANSFER_DEST != 0);

                vm.prank(spender);
                if (receiverCanReceive) {
                    c.transferFrom(user1, user2, 1);
                    assertEq(c.balanceOf(user2), 1);
                } else {
                    vm.expectRevert(Error.InvalidPermission.selector);
                    c.transferFrom(user1, user2, 1);
                }
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

//engine-only :

    function testBurn_RevertsIfNotEngine() public {
        PrivateCoin c = setupCoin(Actions.MINT | Actions.HOLD | Actions.TRANSFER_DEST, Actions.MINT | Actions.HOLD | Actions.TRANSFER_DEST);
        grantUser(c, user1);

        vm.prank(user1);
        vm.expectRevert();
        c.burn(user1, 1);
    }

    function testMint_RevertsIfNotEngine() public {
        PrivateCoin c = setupCoin(
            Actions.MINT | Actions.HOLD,
            Actions.MINT | Actions.HOLD
        );
        grantUser(c, user1);

        vm.prank(user1);
        vm.expectRevert(Error.InvalidAccess.selector);
        c.mint(user1, user1, 1);
    }

    function testUpdateUserList_RevertsIfNotEngine() public {
        PrivateCoin c = setupCoin(
            Actions.MINT | Actions.HOLD,
            Actions.MINT | Actions.HOLD
        );

        address[] memory users = new address[](1);
        users[0] = user1;

        vm.prank(user1);
        vm.expectRevert(Error.InvalidAccess.selector);
        c.updateUserList(users, new address[](0));
    }

//batch overflow :
    function testConstructor_InitialUsersOverflow_EmitsEvent() public {
        uint256 len = Actions.MAX_ARRAY_LEN + 1;
        address[] memory users = new address[](len);

        for (uint256 i; i < len; i++) {
            users[i] = address(uint160(9000 + i));
        }

        vm.expectEmit(true, false, false, true);
        emit PrivateCoin.NeedToSetMorePermissions(users, new address[](0));

        vm.prank(engine);
        new PrivateCoin(
            "TestCoin",
            "TC",
            Actions.MINT | Actions.HOLD,
            Actions.MINT | Actions.HOLD,
            users,
            app
        );
    }

    function testGrantPermissions_EmitsNeedToSetMorePermissions() public {
        PrivateCoin c = setupCoin(
            Actions.MINT | Actions.HOLD,
            Actions.MINT | Actions.HOLD
        );

        uint256 len = Actions.MAX_ARRAY_LEN + 5;
        address[] memory users = new address[](len);

        for (uint256 i = 0; i < len; i++) {
            users[i] = address(uint160(i + 100));
        }

        vm.expectEmit(true, false, false, true);
        emit PrivateCoin.NeedToSetMorePermissions(users, new address[](0));

        vm.prank(engine);
        c.updateUserList(users, new address[](0));
    }

    function testRevokePermissions_EmitsNeedToSetMorePermissions() public {
        PrivateCoin c = setupCoin(
            Actions.MINT | Actions.HOLD,
            Actions.MINT | Actions.HOLD
        );

        uint256 len = Actions.MAX_ARRAY_LEN + 3;
        address[] memory users = new address[](len);

        for (uint256 i = 0; i < len; i++) {
            users[i] = address(uint160(i + 200));
        }

        vm.prank(engine);
        c.updateUserList(users, new address[](0));

        vm.expectEmit(true, false, false, true);
        emit PrivateCoin.NeedToSetMorePermissions(new address[](0), users);

        vm.prank(engine);
        c.updateUserList(new address[](0), users);
    }

    function testUpdateUserList_BothOverflow() public {
        PrivateCoin c = setupCoin(
            Actions.MINT | Actions.HOLD,
            Actions.MINT | Actions.HOLD
        );

        uint256 len = Actions.MAX_ARRAY_LEN + 1;

        address[] memory add = new address[](len);
        address[] memory remove = new address[](len);

        for (uint256 i; i < len; i++) {
            add[i] = address(uint160(1000 + i));
            remove[i] = address(uint160(2000 + i));
        }

        vm.expectEmit(true, true, false, true);
        emit PrivateCoin.NeedToSetMorePermissions(add, remove);

        vm.prank(engine);
        c.updateUserList(add, remove);
    }


//transfer

    function testTransferFrom_WithAllowance_AndPermission() public {
        PrivateCoin c = setupCoin(
            Actions.MINT | Actions.HOLD | Actions.TRANSFER_DEST,
            Actions.MINT | Actions.HOLD | Actions.TRANSFER_DEST
        );

        grantUser(c, user1);
        grantUser(c, user2);

        vm.prank(engine);
        c.mint(app, user1, 2);

        vm.prank(user1);
        c.approve(spender, 1);

        vm.prank(spender);
        c.transferFrom(user1, user2, 1);

        assertEq(c.balanceOf(user2), 1);
    }


    function testTransferFrom_RevertsIfDestinationNotAllowed() public {
        PrivateCoin c = setupCoin(
            Actions.MINT | Actions.HOLD,
            Actions.MINT | Actions.HOLD
        );

        grantUser(c, user1);
        grantUser(c, user2);

        vm.prank(engine);
        c.mint(app, user1, 1);

        vm.prank(spender);
        vm.expectRevert(Error.InvalidPermission.selector);
        c.transferFrom(user1, user2, 1);
    }

    function testRevokedUserCannotReceiveTransfer() public {
        PrivateCoin c = setupCoin(
            Actions.MINT | Actions.HOLD | Actions.TRANSFER_DEST,
            Actions.MINT | Actions.HOLD | Actions.TRANSFER_DEST
        );

        grantUser(c, user1);
        grantUser(c, user2);

        vm.prank(engine);
        c.mint(app, user1, 2);

        // revoke TRANSFER_DEST from user2
        address[] memory revoke = new address[](1);
        revoke[0] = user2;

        vm.prank(engine);
        c.updateUserList(new address[](0), revoke);

        vm.prank(user1);
        vm.expectRevert(Error.InvalidPermission.selector);
        c.transfer(user2, 1);
    }

//mint

    function testMint_RevertsIfFromLacksMintPermission() public {
        PrivateCoin c = setupCoin(
            Actions.HOLD | Actions.MINT,
            Actions.HOLD
        );

        grantUser(c, user1);

        vm.prank(engine);
        vm.expectRevert(Error.InvalidPermission.selector);
        c.mint(user1, user1, 1);
    }

}
