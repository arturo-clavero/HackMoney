// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../src/utils/ActionsLib.sol";

//used to check reverts...
contract BootstrapActions {

    function getGroupActions(
        bool canMint, 
        bool canHold, 
        bool canGetTransfer
        ) external pure returns (uint256 actions){
        return Actions.getGroupActions(canMint, canHold, canGetTransfer);
    }
    function allowed(uint256 userActions, uint256 appActions) external pure {
        Actions.allowed(userActions, appActions);
    }

    function transferMustHold(uint256 actions) external pure{
        Actions.transferMustHold(actions);
    }
}

contract ActionsTest is Test {

    BootstrapActions lib;

    function setUp() public {
        lib = new BootstrapActions();
    }

    function testGetGroupActions_AllTrue() public view {
        uint256 actions = lib.getGroupActions(true, true, true);

        assertTrue(actions & Actions.MINT != 0);
        assertTrue(actions & Actions.HOLD != 0);
        assertTrue(actions & Actions.TRANSFER != 0);
    }

    function testGetGroupActions_NoneTrue() public view {
        uint256 actions = lib.getGroupActions(false, false, false);
        assertEq(actions, 0);
    }

    function testAllowed_RevertsIfNoMint() public {
        uint256 userActions = Actions.HOLD;
        uint256 appActions = Actions.HOLD;

        vm.expectRevert();
        lib.allowed(userActions, appActions);
    }

    function testAllowed_RevertsIfNoHold() public {
        uint256 userActions = Actions.MINT;
        uint256 appActions = Actions.MINT;

        vm.expectRevert();
        lib.allowed(userActions, appActions);
    }

    function testAllowed_PassesValidCombo() public view {
        uint256 userActions = Actions.MINT | Actions.HOLD;
        uint256 appActions = 0;

        lib.allowed(userActions, appActions);
    }

    function testTransferMustHold_RevertsIfTransferWithoutHold() public {
        uint256 actions = Actions.TRANSFER;

        vm.expectRevert();
        lib.transferMustHold(actions);
    }

    function testTransferMustHold_PassesIfTransferWithHold() public view {
        uint256 actions = Actions.TRANSFER | Actions.HOLD;
        lib.transferMustHold(actions);
    }

    function testAllowed_RevertsIfOnlyAppHoldsAndTransfers() public {
        uint256 appActions =
            Actions.MINT |
            Actions.HOLD |
            Actions.TRANSFER;

        uint256 userActions =
            Actions.MINT;

        vm.expectRevert();
        lib.allowed(userActions, appActions);
    }

    function testAllowed_Passes_UserToApp() public view {
        uint256 userActions =
            Actions.MINT |
            Actions.HOLD;

        uint256 appActions =
            Actions.MINT |
            Actions.HOLD |
            Actions.TRANSFER;

        lib.allowed(userActions, appActions);
    }

    function testAllowed_Passes_UserToUser() public view {
        uint256 userActions =
            Actions.MINT |
            Actions.HOLD |
            Actions.TRANSFER;

        uint256 appActions =
            Actions.MINT;

        lib.allowed(userActions, appActions);
    }



    
}
