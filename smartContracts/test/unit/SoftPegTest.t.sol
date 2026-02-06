// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../src/Core/SoftPeg.sol";
import "@openzeppelin/token/ERC20/ERC20.sol";

import "../utils/BaseEconomicTest.t.sol";
import {MockToken} from "../mocks/MockToken.sol";

contract SoftPegUnitTest is BaseEconomicTest {

    uint256 ID;
    address minter;
    address user;
    MockToken token;
    MockToken weth;
    MockToken usdc;

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
        setUpBase(modes, decimals, _totalUsers, _totalApps);

        ID = appIDs[0];
        user = users[0];
        token = tokens[0];
        weth = tokens[1];
        usdc = tokens[2];
        minter = appOwners[ID];
    }

    function testX_() public {
        assert(1 == 1);
    }

//DEPOSITS:
    function testDeposit_basic() public {
        vm.startPrank(user);
        peg.deposit(ID, address(token), _raw(500, address(token)));

        uint256 shares = peg.getUserColShares(ID, user, address(token));
        assertGt(shares, 0);

        ColVault memory vault = peg.getCollateralVaults(address(token));
        assertEq(vault.totalAssets, 500);
        assertGt(vault.totalShares, 0);
        vm.stopPrank();
    }

    function test_deposit_firstDeposit() public {
        vm.startPrank(user);
        peg.deposit(ID, address(weth), _raw(10, address(weth)));
        vm.stopPrank();

        uint256 shares = peg.getUserColShares(ID, user, address(weth));
        ColVault memory vault = peg.getCollateralVaults(address(weth));

        assertEq(vault.totalAssets, 10);
        assertEq(vault.totalShares, shares);
    }

    function test_deposit_secondDeposit_sameRatio() public {
        vm.startPrank(user);
        peg.deposit(ID, address(weth), _raw(10, address(weth)));
        uint256 s1 = peg.getUserColShares(ID, user, address(weth));

        peg.deposit(ID, address(weth), _raw(10, address(weth)));
        uint256 s2 = peg.getUserColShares(ID, user, address(weth));
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

//mint

    function testMint_basic() public {
        _mintTokenTo(token, 500, minter);

        vm.startPrank(minter);
        assertEq(peg.getUsersMintCredit(ID, minter), 0);
        assertGt(peg.getCredit(address(token)), 0);

        peg.deposit(ID, address(token), _raw(500, address(token)));
        assertEq(peg.getUsersMintCredit(ID, minter), 250);

        peg.mint(ID, user, type(uint256).max);
        assertEq(peg.getUsersMintCredit(ID, minter), 0);

        uint256 debtShares = peg.getUserDebtShares(ID, user);
        assertGt(debtShares, 0);

        vm.expectRevert(Error.InsufficientCollateral.selector);
        peg.mint(ID, user, 1);
        vm.stopPrank();
    }

    function testWithdrawCollateral_basic() public {
        vm.startPrank(user);
        peg.deposit(ID, address(token), _raw(500, address(token)));

        peg.withdrawCollateral(ID, address(token), 100);

        uint256 shares = peg.getUserColShares(ID, user, address(token));
        assertLt(shares, 500);
        vm.stopPrank();
    }

    function testWithdrawCollateral_withDebtFails() public {
        _mintTokenTo(token, 500, minter);
        vm.startPrank(minter);
        peg.deposit(ID, address(token), _raw(500, address(token)));
        peg.mint(ID, user, type(uint256).max);
        vm.stopPrank();

        vm.startPrank(user);
        vm.expectRevert(Error.UserHasDebt.selector);
        peg.withdrawCollateral(ID, address(token), 1);
        vm.stopPrank();
    }
}