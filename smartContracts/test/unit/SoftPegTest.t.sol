// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../src/Core/SoftPeg.sol";
import "@openzeppelin/token/ERC20/ERC20.sol";

import "../utils/BaseEconomicTest.t.sol";
import {MockToken} from "../mocks/MockToken.sol";


import "forge-std/console.sol";
contract SoftPegUnitTest is BaseEconomicTest {

    uint256 ID;
    address minter;
    address user;
    
    MockToken token6;
    MockToken token8;
    MockToken token18;

    function _deployPeg() internal override returns (IPeg){
        SoftPeg soft = new SoftPeg(owner, timelock, globalDebtcap, mintCapPerTx);
        return IPeg(address(soft));
    }

    function setUp() public {
        uint256 _totalTokens = 3;
        uint256 _totalUsers = 2;
        uint256 _totalApps = 1;

        uint256[] memory modes = new uint256[](_totalTokens);
        uint8[] memory decimals = new uint8[](_totalTokens);
        for (uint256 i = 0 ; i < _totalTokens; i++){
            modes[i] = Core.COL_MODE_VOLATILE;
            if (i + 2 % 4 == 0) decimals[i] = 18;
            else if (i + 2 % 3 == 0) decimals[i] = 9;
            else if (i + 2 % 2 == 0) decimals[i] = 8;
            else if (i + 2 % 1 == 0) decimals[i] = 6;
        }
        // decimals[0] = 18;
        modes[2] = Core.COL_MODE_STABLE;
        decimals[0] = 6;
        decimals[1] = 8;
        decimals[2] = 18;
        setUpBase(modes, decimals, _totalUsers, _totalApps);

        ID = appIDs[0];
        user = users[0];
        token6 = tokens[0];
        token8 = tokens[1];
        token18 = tokens[2];
        minter = appOwners[ID];
    }

    function testX_() public {
        assert(1 == 1);
    }

//DEPOSITS:
    function testDeposit_basic() public {
        vm.startPrank(user);
        peg.deposit(ID, address(token18), _raw(500, address(token18)));

        uint256 shares = peg.getUserColShares(ID, user, address(token18));
        assertGt(shares, 0);

        ColVault memory vault = peg.getCollateralVaults(address(token18));
        assertEq(vault.totalAssets, 500);
        assertGt(vault.totalShares, 0);
        vm.stopPrank();
    }

    function test_deposit_firstDeposit() public {
        vm.startPrank(user);
        peg.deposit(ID, address(token18), _raw(10, address(token18)));
        vm.stopPrank();

        uint256 shares = peg.getUserColShares(ID, user, address(token18));
        ColVault memory vault = peg.getCollateralVaults(address(token18));

        assertEq(vault.totalAssets, 10);
        assertEq(vault.totalShares, shares);
    }

    function test_deposit_secondDeposit_sameRatio() public {
        vm.startPrank(user);
        peg.deposit(ID, address(token18), _raw(10, address(token18)));
        uint256 s1 = peg.getUserColShares(ID, user, address(token18));

        peg.deposit(ID, address(token18), _raw(10, address(token18)));
        uint256 s2 = peg.getUserColShares(ID, user, address(token18));
        vm.stopPrank();

        assertEq(s2, s1 * 2);
    }

    function test_deposit_maxCollateralTypes() public {
        address appOwner = address(0xF);
        uint256 newAppID = _addTempAppInstance(appOwner);


        // add fake tokens until max
        uint256 MAX_COLLATERAL_TYPES = 5;

        for (uint256 i = 0; i < MAX_COLLATERAL_TYPES; i++) {
            vm.startPrank(user);
            MockToken t = new MockToken(18);
            t.mint(user, 1 ether);
            t.approve(address(peg), type(uint256).max);
            vm.stopPrank();
            _addNewToken(address(t), newAppID, appOwner);
            vm.prank(user);
            peg.deposit(newAppID, address(t), 1 ether);
        }

        vm.startPrank(user);
        MockToken overflow = new MockToken(18);
        overflow.mint(user, 1 ether);
        overflow.approve(address(peg), type(uint256).max);
        vm.stopPrank();
        _addNewToken(address(overflow), newAppID, appOwner);

        vm.startPrank(user);
        vm.expectRevert(Error.MaxCollateralTypesPerPosition.selector);
        peg.deposit(newAppID, address(overflow), 1 ether);
        vm.stopPrank();
    }

     function testDeposit_zeroAmountRevert() public {
        vm.startPrank(user);
        vm.expectRevert(Error.InvalidAmount.selector);
        peg.deposit(ID, address(token6), 0);
        vm.stopPrank();
    }

    function testDeposit_unsupportedTokenRevert() public {
        MockToken fake = new MockToken(18);
        vm.startPrank(user);
        vm.expectRevert(Error.CollateralNotSupportedByApp.selector);
        peg.deposit(ID, address(fake), 1e18);
        vm.stopPrank();
    }

    function testDeposit_differentDecimals() public {
        vm.startPrank(user);
        peg.deposit(ID, address(token6), _raw(100, address(token6)));
        peg.deposit(ID, address(token8), _raw(200, address(token8)));
        peg.deposit(ID, address(token18), _raw(300, address(token18)));

        uint256 shares6 = peg.getUserColShares(ID, user, address(token6));
        uint256 shares8 = peg.getUserColShares(ID, user, address(token8));
        uint256 shares18 = peg.getUserColShares(ID, user, address(token18));

        assertGt(shares6, 0);
        assertGt(shares8, 0);
        assertGt(shares18, 0);
        vm.stopPrank();
    }

    function testDeposit_partialWithdrawThenDeposit() public {
        vm.startPrank(user);
        peg.deposit(ID, address(token6), _raw(100, address(token6)));
        peg.withdrawCollateral(ID, address(token6), 40);
        peg.deposit(ID, address(token6), _raw(60, address(token6)));

        uint256 shares = peg.getUserColShares(ID, user, address(token6));
        ColVault memory vault = peg.getCollateralVaults(address(token6));
        assertEq(shares, vault.totalShares);
        vm.stopPrank();
    }


//withdraw

    function testWithdrawCollateral_basic() public {
        vm.startPrank(user);
        peg.deposit(ID, address(token18), _raw(500, address(token18)));

        peg.withdrawCollateral(ID, address(token18), 100);

        uint256 shares = peg.getUserColShares(ID, user, address(token18));
        assertLt(shares, 500);
        vm.stopPrank();
    }

    function testWithdrawCollateral_withDebtFails() public {
        _mintTokenTo(token18, 500, minter);
        vm.startPrank(minter);
        peg.deposit(ID, address(token18), _raw(500, address(token18)));
        peg.mint(ID, user, type(uint256).max);
        vm.stopPrank();

        vm.startPrank(minter);
        vm.expectRevert(Error.UserHasDebt.selector);
        peg.withdrawCollateral(ID, address(token18), 1);
        vm.stopPrank();
    }

    function testWithdraw_fullCollateralZeroShares() public {
        vm.startPrank(user);
        peg.deposit(ID, address(token6), _raw(50, address(token6)));
        peg.withdrawCollateral(ID, address(token6), 50);
        uint256 shares = peg.getUserColShares(ID, user, address(token6));
        assertEq(shares, 0);
        vm.stopPrank();
    }

    function testWithdraw_overAmountRevert() public {
        vm.startPrank(user);
        peg.deposit(ID, address(token6), _raw(50, address(token6)));
        vm.expectRevert();
        peg.withdrawCollateral(ID, address(token6), 100);
        vm.stopPrank();
    }

    function testWithdraw_withDebtRevert() public {
        _mintTokenTo(token6, 500, minter);
        vm.startPrank(minter);
        peg.deposit(ID, address(token6), _raw(100, address(token6)));
        peg.mint(ID, user, type(uint256).max);
        vm.stopPrank();

        vm.startPrank(minter);
        vm.expectRevert(Error.UserHasDebt.selector);
        peg.withdrawCollateral(ID, address(token6), 10);
        vm.stopPrank();
    }

//mint
    function testMint_basic() public {
        _mintTokenTo(token18, 500, minter);

        vm.startPrank(minter);
        assertEq(peg.getUsersMintCredit(ID, minter), 0);

        peg.deposit(ID, address(token18), _raw(500, address(token18)));
        assertEq(peg.getUsersMintCredit(ID, minter), 250);

        peg.mint(ID, user, type(uint256).max);
        assertEq(peg.getUsersMintCredit(ID, minter), 0);

        uint256 debtShares = peg.getUserDebtShares(ID, minter);
        assertGt(debtShares, 0);

        vm.expectRevert(Error.InsufficientCollateral.selector);
        peg.mint(ID, user, 1);
        vm.stopPrank();
    }

    function testMint_aboveMaxRevert() public {
        _mintTokenTo(token6, 500, minter);
        vm.startPrank(minter);
        peg.deposit(ID, address(token6), _raw(100, address(token6)));
        uint256 credit = peg.getUsersMintCredit(ID, minter);
        vm.expectRevert(Error.InsufficientCollateral.selector);
        peg.mint(ID, user, (credit * 1e18) + 1);
        vm.stopPrank();
    }

    function testMint_multipleCollateralTypes() public {
        _mintTokenTo(token6, 500, minter);
        _mintTokenTo(token8, 500, minter);

        vm.startPrank(minter);
        peg.deposit(ID, address(token6), _raw(100, address(token6)));
        peg.deposit(ID, address(token8), _raw(200, address(token8)));

        uint256 creditBefore = peg.getUsersMintCredit(ID, minter);
        peg.mint(ID, user, type(uint256).max);
        uint256 creditAfter = peg.getUsersMintCredit(ID, minter);
        assertEq(creditAfter, 0);

        uint256 debtShares = peg.getUserDebtShares(ID, minter);
        assertGt(debtShares, 0);
        assertEq(peg.getUsersMintCredit(ID, minter), 0);
        assertGt(peg.getUserDebtShares(ID, minter), 0);
        assertEq(peg.getUserDebtShares(ID, user), 0);

        vm.stopPrank();
    }

    function testMint_zeroAmountRevert() public {
        _mintTokenTo(token6, 500, minter);
        vm.startPrank(minter);
        peg.deposit(ID, address(token6), _raw(100, address(token6)));
        vm.expectRevert(Error.InvalidAmount.selector);
        peg.mint(ID, user, 0);
        vm.stopPrank();
    }

    function testMint_zeroCollateralRevert() public {
        _mintTokenTo(token6, 500, minter);
        vm.startPrank(minter);
        vm.expectRevert(Error.InsufficientCollateral.selector);
        peg.mint(ID, user, 1);
        vm.stopPrank();
    }


//repay:
    function testRepay_basic() public {
        uint256 newAppID = _addSuperApp(minter);

        _mintTokenTo(token18, 500, minter);

        vm.startPrank(minter);
        peg.deposit(newAppID, address(token18), _raw(500, address(token18)));
        uint256 maxCredit = peg.getUsersMintCredit(newAppID, minter);

        peg.mint(newAppID, minter, type(uint256).max);
        uint256 debtSharesBefore = peg.getUserDebtShares(newAppID, minter);
        uint256 mintCreditAfterMint = peg.getUsersMintCredit(newAppID, minter);
        assertEq(mintCreditAfterMint, 0);

        // repay half of debt
        uint256 repayAmount = maxCredit * 1e18 / 2 ;
        peg.repay(newAppID, repayAmount);

        uint256 debtSharesAfter = peg.getUserDebtShares(newAppID, minter);
        assertLt(debtSharesAfter, debtSharesBefore);
        assertGt(debtSharesAfter, 0);

        vm.stopPrank();
    }

    function testRepay_fullDebt() public {
        uint256 newAppID = _addSuperApp(minter);

        _mintTokenTo(token18, 500, minter);

        vm.startPrank(minter);
        peg.deposit(newAppID, address(token18), _raw(500, address(token18)));
        uint256 maxCredit = peg.getUsersMintCredit(newAppID, minter);

        peg.mint(newAppID, minter, type(uint256).max);
        uint256 debtSharesBefore = peg.getUserDebtShares(newAppID, minter);
        // repay full debt
        peg.repay(newAppID, maxCredit * 1e18);

        uint256 debtSharesAfter = peg.getUserDebtShares(newAppID, minter);

        assertEq(debtSharesAfter, 0);
        // now mint credit should be the same as before since all debt is covered
        assertEq(peg.getUsersMintCredit(newAppID, minter), maxCredit);

        vm.stopPrank();
    }

    function testRepay_zeroAmountRevert() public {
                uint256 newAppID = _addSuperApp(minter);

        _mintTokenTo(token18, 500, minter);

        vm.startPrank(minter);
        peg.deposit(newAppID, address(token18), _raw(500, address(token18)));
        peg.mint(newAppID, minter, type(uint256).max);

        vm.expectRevert(Error.InvalidAmount.selector);
        peg.repay(newAppID, 0);

        vm.stopPrank();
    }

    function testRepay_moreThanDebtReverts() public {
        uint256 newAppID = _addSuperApp(minter);
        _mintTokenTo(token18, 500, minter);

        vm.startPrank(minter);
        peg.deposit(newAppID, address(token18), _raw(500, address(token18)));
        uint256 maxCredit = peg.getUsersMintCredit(newAppID, minter);
        peg.mint(newAppID, minter, type(uint256).max);

        uint256 debtShares = peg.getUserDebtShares(newAppID, minter);

        vm.expectRevert();
        peg.repay(newAppID, (maxCredit + 1) * 1e18);
        vm.stopPrank();
    }

    function testRepay_partialMintWithdrawFlow() public {
                uint256 newAppID = _addSuperApp(minter);

        _mintTokenTo(token18, 500, minter);

        vm.startPrank(minter);
        peg.deposit(newAppID, address(token18), _raw(500, address(token18)));
        uint256 maxCredit = peg.getUsersMintCredit(newAppID, minter);

        // mint full credit
        peg.mint(newAppID, minter, type(uint256).max);
        assertEq(peg.getUsersMintCredit(newAppID, minter), 0);

        // partial repay
        peg.repay(newAppID, maxCredit / 2 * 1e18);
        uint256 debtAfterPartial = peg.getUserDebtShares(newAppID, minter);
        assertGt(debtAfterPartial, 0);

        // still cannot withdraw full collateral
        vm.expectRevert(Error.UserHasDebt.selector);
        peg.withdrawCollateral(newAppID, address(token18), 100);

        // repay remaining
        peg.repay(newAppID, maxCredit / 2 * 1e18);
        assertEq(peg.getUserDebtShares(newAppID, minter), 0);

        // now withdrawal works
        peg.withdrawCollateral(newAppID, address(token18), 100);
        vm.stopPrank();
    }

    function testMultiStepDepositMintWithdraw() public {
                uint256 newAppID = _addSuperApp(minter);

    //     _mintTokenTo(token6, 500, minter);
    //     _mintTokenTo(token8, 500, minter);

    //     vm.startPrank(minter);
    //     peg.deposit(newAppID, address(token6), _raw(100, address(token6)));
    //     peg.deposit(newAppID, address(token8), _raw(200, address(token8)));

    //     uint256 creditBefore = peg.getUsersMintCredit(newAppID, minter);
    //     peg.mint(newAppID, minter, type(uint256).max);
    //     assertEq(peg.getUsersMintCredit(newAppID, minter), 0);

    //     // partial withdraw fails because debt exists
    //     vm.expectRevert(Error.UserHasDebt.selector);
    //     peg.withdrawCollateral(newAppID, address(token6), 10);

    //     // simulate repay: reduce debt manually for test
    //     uint256 debtShares = peg.getUserDebtShares(newAppID, minter);
    //     peg._forceRepay(newAppID, minter, debtShares);

    //     // withdraw now works
    //     peg.withdrawCollateral(newAppID, address(token6), 50);
    //     uint256 shares6 = peg.getUserColShares(newAppID, minter, address(token6));
    //     assertLt(shares6, 100);
    //     vm.stopPrank();
    }

}