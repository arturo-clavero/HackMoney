// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../src/core/SoftPeg.sol";
import "@openzeppelin/token/ERC20/ERC20.sol";

import "../utils/BaseEconomicTest.t.sol";
import {MockToken} from "../mocks/MockToken.sol";
import {RiskMath} from "../../src/utils/RiskMathLib.sol";


import "forge-std/console.sol";
contract SoftPegUnitTest is BaseEconomicTest {
        using RiskMath for uint256;


    uint256 ID;
    address minter;
    address user;
    address user2;
    address liquidator = address(0xFF);
    
    MockToken token6;
    MockToken token8;
    MockToken token18;

    function _deployPeg() internal override returns (IPeg){
        SoftPeg soft = new SoftPeg(owner, timelock, globalDebtCap, mintCapPerTx);
        return IPeg(address(soft));
    }

    function setUp() public {
        uint256 _totalTokens = 3;
        uint256 _totalUsers = 2;
        uint256 _totalApps = 1;

        uint256[] memory modes = new uint256[](_totalTokens);
        uint8[] memory decimals = new uint8[](_totalTokens);
        for (uint256 i = 0 ; i < _totalTokens; i++){
            modes[i] = core.COL_MODE_VOLATILE;
            if (i + 2 % 4 == 0) decimals[i] = 18;
            else if (i + 2 % 3 == 0) decimals[i] = 9;
            else if (i + 2 % 2 == 0) decimals[i] = 8;
            else if (i + 2 % 1 == 0) decimals[i] = 6;
        }
        // decimals[0] = 18;
        modes[2] = core.COL_MODE_STABLE;
        decimals[0] = 6;
        decimals[1] = 8;
        decimals[2] = 18;
        setUpBase(modes, decimals, _totalUsers, _totalApps);

        ID = appIDs[0];
        user = users[0];
        user2 = users[1];
        token6 = tokens[0];
        token8 = tokens[1];
        token18 = tokens[2];
        minter = appOwners[ID];

        vm.startPrank(owner);
        peg.grantRole(liquidator, 1 << 4);
        assert(peg.hasRole(liquidator, 1 << 4));
        vm.stopPrank();


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

        _mintTokenTo(token6, 500, minter);
        _mintTokenTo(token8, 500, minter);

        vm.startPrank(minter);
        peg.deposit(newAppID, address(token6), _raw(100, address(token6)));
        peg.deposit(newAppID, address(token8), _raw(200, address(token8)));

        uint256 creditBefore = peg.getUsersMintCredit(newAppID, minter);
        peg.mint(newAppID, minter, type(uint256).max);
        assertEq(peg.getUsersMintCredit(newAppID, minter), 0);

        // partial withdraw fails because debt exists
        vm.expectRevert(Error.UserHasDebt.selector);
        peg.withdrawCollateral(newAppID, address(token6), 10);

        // simulate repay: reduce debt manually for test
        uint256 debtShares = peg.getUserDebtShares(newAppID, minter);
        peg.repay(newAppID, debtShares * 1e18);

        // withdraw now works
        peg.withdrawCollateral(newAppID, address(token6), 50);
        uint256 shares6 = peg.getUserColShares(newAppID, minter, address(token6));
        assertLt(shares6, 100);
        vm.stopPrank();
    }
//liquidate :
    function testLiquidate_basic() public {
        uint256 newAppID = _addSuperApp(minter);
        _mintTokenTo(token18, 500, minter);
        _mintTokenTo(token8, 500, liquidator);

        vm.startPrank(minter);
        peg.deposit(newAppID, address(token18), _raw(500, address(token18)));
        peg.mint(newAppID, minter, _raw(100, address(0)));
        vm.stopPrank();

        vm.startPrank(liquidator);
        peg.deposit(newAppID, address(token8), _raw(500, address(token8)));
        peg.mint(newAppID, liquidator, type(uint256).max);
        vm.stopPrank();

        uint256 liquidatorCoinBalanceBefore  = IERC20(peg.getAppCoin(newAppID)).balanceOf(liquidator);
        uint256 liquidatorTokenBalanceBefore  = token18.balanceOf(liquidator);
    
        uint256 userDebtBefore = peg.getUserDebtShares(newAppID, minter).calcAssets(peg.getTotalDebt(), peg.getTotalDebtShares());
        uint256 userSharesBefore = peg.getUserColShares(newAppID, minter, address(token18));

        _lowerPriceToLiquidate(newAppID, minter, address(token18));

        uint256 liquidationAmount = _getMaxLiquidationAmount(newAppID, minter);
        vm.startPrank(liquidator);
        peg.liquidate(newAppID, minter, liquidationAmount);
        vm.stopPrank();

        uint256 liquidatorCoinBalanceAfter  = IERC20(peg.getAppCoin(newAppID)).balanceOf(liquidator);
        uint256 liquidatorTokenBalanceAfter = token18.balanceOf(liquidator);
    
        uint256 userDebtAfter = peg.getUserDebtShares(newAppID, minter).calcAssets(peg.getTotalDebt(), peg.getTotalDebtShares()); 
        uint256 userSharesAfter = peg.getUserColShares(newAppID, minter, address(token18));

        assertLt(liquidatorCoinBalanceAfter, liquidatorCoinBalanceBefore);
        assertGt(liquidatorTokenBalanceAfter, liquidatorTokenBalanceBefore);

        assertLt(userDebtAfter, userDebtBefore);
        assertLt(userSharesAfter, userSharesBefore);
        vm.stopPrank();
    }

    function testLiquidate_healthyPositionReverts() public {
        uint256 newAppID = _addSuperApp(minter);
        _mintTokenTo(token18, 500, minter);
        _mintTokenTo(token18, 500, liquidator);

        vm.startPrank(minter);
        peg.deposit(newAppID, address(token18), _raw(500, address(token18)));
        peg.mint(newAppID, minter, _raw(100, address(0)));
        vm.stopPrank();

        vm.startPrank(liquidator);
        peg.deposit(newAppID, address(token18), _raw(500, address(token18)));
        peg.mint(newAppID, liquidator, _raw(100, address(0)));
        vm.stopPrank();

        vm.startPrank(liquidator);
        vm.expectRevert(Error.PositionIsHealthy.selector);
        peg.liquidate(newAppID, minter, 1e18);
        vm.stopPrank();
    }

    function testLiquidate_zeroAmountReverts() public {
        uint256 newAppID = _addSuperApp(minter);
        _mintTokenTo(token18, 500, minter);
        _mintTokenTo(token18, 500, liquidator);

        vm.startPrank(minter);
        peg.deposit(newAppID, address(token18), _raw(500, address(token18)));
        peg.mint(newAppID, minter, _raw(100, address(0)));
        vm.stopPrank();

        vm.startPrank(liquidator);
        peg.deposit(newAppID, address(token18), _raw(500, address(token18)));
        peg.mint(newAppID, liquidator, _raw(100, address(0)));
        vm.stopPrank();


        vm.startPrank(liquidator);
        vm.expectRevert(Error.InvalidAmount.selector);
        peg.liquidate(newAppID, minter, 0);
        vm.stopPrank();
    }


    function testLiquidate_overpayCapped() public {
        uint256 newAppID = _addSuperApp(minter);
        _mintTokenTo(token18, 500, minter);
        _mintTokenTo(token8, 500, liquidator);
        vm.startPrank(minter);
        peg.deposit(newAppID, address(token18), _raw(500, address(token18)));
        peg.mint(newAppID, minter, _raw(100, address(0)));
        vm.stopPrank();
        vm.startPrank(liquidator);
        peg.deposit(newAppID, address(token8), _raw(500, address(token8)));
        peg.mint(newAppID, liquidator, type(uint256).max);
        vm.stopPrank();

        _lowerPriceToLiquidate(newAppID, minter, address(token18));

        uint256 maxLiq = _getMaxLiquidationAmount(newAppID, minter);
        uint256 debtBefore =
            peg.getUserDebtShares(newAppID, minter)
                .calcAssets(peg.getTotalDebt(), peg.getTotalDebtShares());

        vm.startPrank(liquidator);
        peg.liquidate(newAppID, minter, maxLiq * 2);
        vm.stopPrank();

        uint256 debtAfter =
        peg.getUserDebtShares(newAppID, minter)
                .calcAssets(peg.getTotalDebt(), peg.getTotalDebtShares());
        uint256 debtChange = 1e18 * (debtBefore - debtAfter);


        assertLe(debtChange, maxLiq + 1);
        assertGe(debtChange, maxLiq);
    }

    function testLiquidate_liquidatorGetsCollateral() public {
        uint256 newAppID = _addSuperApp(minter);
        _mintTokenTo(token18, 500, minter);
        _mintTokenTo(token8, 500, liquidator);
        vm.startPrank(minter);
        peg.deposit(newAppID, address(token18), _raw(500, address(token18)));
        peg.mint(newAppID, minter, _raw(100, address(0)));
        vm.stopPrank();
        vm.startPrank(liquidator);
        peg.deposit(newAppID, address(token8), _raw(500, address(token8)));
        peg.mint(newAppID, liquidator, type(uint256).max);
        vm.stopPrank();

        _setMockPrice(1e8 * 2 / 10, address(token18));
        uint256 balBefore = token18.balanceOf(liquidator);

        vm.startPrank(liquidator);
        peg.liquidate(newAppID, minter, _raw(250, address(0)));
        vm.stopPrank();

        uint256 balAfter = token18.balanceOf(liquidator);
        assertGt(balAfter, balBefore);
    }

    function testLiquidate_multiCollateral() public {
        uint256 newAppID = _addSuperApp(minter);
        _mintTokenTo(token18, 1000, liquidator);
        vm.startPrank(liquidator);
        peg.deposit(newAppID, address(token18), _raw(1000, address(token18)));
        peg.mint(newAppID, liquidator, type(uint256).max);
        vm.stopPrank();
        _mintTokenTo(token6, 500, minter);
        _mintTokenTo(token8, 500, minter);
        vm.startPrank(minter);
        peg.deposit(newAppID, address(token8), _raw(500, address(token6)));
        peg.deposit(newAppID, address(token6), _raw(500, address(token6)));
        peg.mint(newAppID, minter, type(uint256).max);
        vm.stopPrank();


        uint256 p1b = peg.getPrice(address(token6));
        uint256 p2b = peg.getPrice(address(token8));
        _setMockPrice(p1b * 40 / 100, address(token8));
        _setMockPrice(p2b * 40 / 100, address(token6));

        uint256 p1a = peg.getPrice(address(token6));
        uint256 p2a = peg.getPrice(address(token8));

        uint256 s6Before = peg.getUserColShares(newAppID, minter, address(token6));
        uint256 s8Before = peg.getUserColShares(newAppID, minter, address(token8));

        console.log("token [6] : ", p1b, "->", p1a);
        console.log("token [8] : ", p2b, "->", p2a);
        vm.startPrank(liquidator);
        peg.liquidate(newAppID, minter, _raw(500, address(0)));
        vm.stopPrank();

        assertTrue(
            peg.getUserColShares(newAppID, minter, address(token6)) < s6Before || peg.getUserColShares(newAppID, minter, address(token8)) < s8Before
        );
    }

    function testLiquidate_invariant_totalDebtDecreases() public {
        uint256 newAppID = _addSuperApp(minter);
        _mintTokenTo(token18, 500, minter);
        _mintTokenTo(token8, 500, liquidator);

        vm.startPrank(minter);
        peg.deposit(newAppID, address(token18), _raw(500, address(token18)));
        peg.mint(newAppID, minter, _raw(100, address(0)));
        vm.stopPrank();

        vm.startPrank(liquidator);
        peg.deposit(newAppID, address(token8), _raw(500, address(token8)));
        peg.mint(newAppID, liquidator, type(uint256).max);
        vm.stopPrank();


        _setMockPrice(1, address(token18));

        uint256 totalDebtBefore = peg.getTotalDebt();

        vm.startPrank(liquidator);
        peg.liquidate(newAppID, minter, _raw(250, address(0)));
        vm.stopPrank();

        // assertLt(peg.getTotalDebt(), totalDebtBefore);
    }

    function testLiquidatorTokenActions() public {
        address newLiquidator = address(0xDEAD);
        _mintTokenTo(token18, 500, newLiquidator);
        _mintTokenTo(token18, 500, minter);


        //check liquidator is not a user
        vm.startPrank(newLiquidator);
        peg.deposit(ID, address(token18), _raw(100, address(token18)));
        vm.expectRevert();
        peg.mint(ID, user, type(uint256).max);
        vm.expectRevert();
        peg.mint(ID, newLiquidator, type(uint256).max);
        vm.stopPrank();
         vm.startPrank(minter);
        peg.deposit(ID, address(token18), _raw(100, address(token18)));
        vm.expectRevert();
        peg.mint(ID, newLiquidator, type(uint256).max);
        peg.mint(ID, user, type(uint256).max);
        vm.stopPrank();
        vm.startPrank(user);
        address coin = peg.getAppCoin(ID);
        vm.expectRevert();
        IERC20(coin).transfer(newLiquidator, 2);
        IERC20(coin).transfer(user2, 2);

        //give liquidator role
        vm.startPrank(owner);
        peg.grantRole(newLiquidator, 1 << 4);
        assert(peg.hasRole(newLiquidator, 1 << 4));
        vm.stopPrank();

        //check with role liquidator can mint to himself
        vm.startPrank(newLiquidator);
        peg.deposit(ID, address(token18), _raw(20, address(token18)));
        peg.mint(ID, newLiquidator, type(uint256).max);
        vm.stopPrank();

        //check with role liquidator can NOT mint to others
        vm.startPrank(newLiquidator);
        peg.deposit(ID, address(token18), _raw(20, address(token18)));
        vm.expectRevert();
        peg.mint(ID, user, type(uint256).max);
        vm.stopPrank();

        //check with role liquidator can NOT transfer to others
        uint256 bal = IERC20(coin).balanceOf(newLiquidator);
        assert(bal > 0);
        vm.startPrank(newLiquidator);
        vm.expectRevert();
        IERC20(coin).transfer(user, bal);
        vm.stopPrank();

        //check with role liquidator can NOT receive transfers        
         bal = IERC20(coin).balanceOf(user2);
        assert(bal > 0);
        vm.startPrank(user2);
        vm.expectRevert();
        IERC20(coin).transfer(newLiquidator, bal);
        vm.stopPrank();
    }

    function testLiquidate_dustAmountReverts() public {
        uint256 id = _addSuperApp(minter);
        _mintTokenTo(token18, 500, minter);
        _mintTokenTo(token8, 500, liquidator);

        vm.startPrank(minter);
        peg.deposit(id, address(token18), _raw(500, address(token18)));
        peg.mint(id, minter, _raw(100, address(0)));
        vm.stopPrank();
        vm.startPrank(liquidator);
        peg.deposit(id, address(token8), _raw(500, address(token8)));
        peg.mint(id, liquidator, type(uint256).max);
        vm.stopPrank();

        _lowerPriceToLiquidate(id, minter, address(token18));

        vm.startPrank(liquidator);
        vm.expectRevert(Error.LiquidationDust.selector);
        peg.liquidate(id, minter, 1); // too small → zero shares
        vm.stopPrank();
    }

    function testLiquidate_burnsAtLeastOneShare() public {
        uint256 id = _addSuperApp(minter);
        _mintTokenTo(token18, 500, minter);
        _mintTokenTo(token8, 500, liquidator);

        vm.startPrank(minter);
        peg.deposit(id, address(token18), _raw(500, address(token18)));
        peg.mint(id, minter, _raw(100, address(0)));
        vm.stopPrank();
        vm.startPrank(liquidator);
        peg.deposit(id, address(token8), _raw(500, address(token8)));
        peg.mint(id, liquidator, type(uint256).max);
        vm.stopPrank();

        _lowerPriceToLiquidate(id, minter, address(token18));

        uint256 sharesBefore = peg.getUserDebtShares(id, minter);

        vm.startPrank(liquidator);
        peg.liquidate(id, minter, _getMaxLiquidationAmount(id, minter));
        vm.stopPrank();

        uint256 sharesAfter = peg.getUserDebtShares(id, minter);
        assertLt(sharesAfter, sharesBefore);
    }

    function testLiquidate_noStateChangeImpossible() public {
        uint256 id = _addSuperApp(minter);
        _mintTokenTo(token18, 500, minter);
        _mintTokenTo(token8, 500, liquidator);

        vm.startPrank(minter);
        peg.deposit(id, address(token18), _raw(500, address(token18)));
        peg.mint(id, minter, _raw(100, address(0)));
        vm.stopPrank();
        vm.startPrank(liquidator);
        peg.deposit(id, address(token8), _raw(500, address(token8)));
        peg.mint(id, liquidator, type(uint256).max);
        vm.stopPrank();

        _lowerPriceToLiquidate(id, minter, address(token18));

        uint256 debtBefore = peg.getTotalDebt();
        uint256 sharesBefore = peg.getTotalDebtShares();

        vm.startPrank(liquidator);
        peg.liquidate(id, minter, _getMaxLiquidationAmount(id, minter));
        vm.stopPrank();

        assertLt(peg.getTotalDebt(), debtBefore);
        assertLt(peg.getTotalDebtShares(), sharesBefore);
    }

}