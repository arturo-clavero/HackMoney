// test/HardPeg.unit.t.sol
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../src/Core/HardPeg.sol";
import "../utils/BaseEconomicTest.t.sol";
import {MockToken} from "../mocks/MockToken.sol";

contract HardPegUnitTest is BaseEconomicTest {

    uint256 ID;
    address minter;
    address alice;
    address bob;
    MockToken usdc;
    MockToken dai;

    function setUp() public {
        uint256 _totalTokens = 2;
        uint256 _totalUsers = 2;
        uint256 _totalApps = 1;

        uint256[] memory modes = new uint256[](_totalTokens);
        uint8[] memory decimals = new uint8[](_totalTokens);
        for (uint256 i = 0 ; i < _totalTokens; i++){
            modes[i] = Core.COL_MODE_STABLE;
            if (i + 2 % 4 == 0) decimals[i] = 18;
            else if (i + 2 % 3 == 0) decimals[i] = 9;
            else if (i + 2 % 2 == 0) decimals[i] = 8;
            else if (i + 2 % 1 == 0) decimals[i] = 6;
        }

        setUpBase(modes, decimals, _totalUsers, _totalApps);

        ID = appIDs[0];
        alice = users[0];
        bob = users[1];
        usdc = tokens[0];
        dai = tokens[1];
        minter = appOwners[ID];
    }

//deposit
    function testDepositERC20_() public {
        _mintTokenTo(usdc, 100, alice);
        vm.startPrank(alice);
        peg.deposit(ID, address(usdc), _raw(100, address(usdc)));
        vm.stopPrank();

        assertEq(peg.getVaultBalance(ID, alice), 100);
        assertEq(peg.getGlobalPool(address(usdc)), 100);
        assertEq(peg.getTotalPool(), 100);
    }

    function testDepositERC20ZeroReverts() public {
        vm.prank(alice);
        vm.expectRevert(Error.InvalidAmount.selector);
        peg.deposit(ID, address(usdc), 0);
    }

    function testDepositERC20WithETHReverts() public {
        vm.deal(alice, 2 ether);
        _mintTokenTo(usdc, 10, alice);
        
        assert(alice.balance >= 1 ether);
        assert(usdc.balanceOf(alice) >= _raw(10, address(usdc)));

        vm.startPrank(alice);
        uint256 rawAmount = _raw(10, address(usdc));
        vm.expectRevert();
        peg.deposit{value: 1 ether}(ID, address(usdc), rawAmount);
        vm.stopPrank();
    }

    function testDepositETHReverts() public {
        _addNewToken(address(0), ID);
        vm.deal(alice, 10 ether);

        vm.prank(alice);
        vm.expectRevert();
        peg.deposit{value: 10 ether}(ID, address(0), 0);
    }

//mint:
    function testMintExact() public {
        _mintTokenTo(usdc, 100, minter);
        vm.startPrank(minter);
        peg.deposit(ID, address(usdc), _raw(100, address(usdc)));
        assertEq(peg.getVaultBalance(ID, minter), 100);
        assertEq(peg.getVaultBalance(ID, alice), 0);

        peg.mint(ID, alice, _raw(40, address(0)));
        assertEq(peg.getVaultBalance(ID, minter), 60);
        assertEq(peg.getVaultBalance(ID, alice), 0);
        vm.stopPrank();

        assertEq(
            IERC20(peg.getAppCoin(ID)).balanceOf(alice),
            _raw(40, address(0))
        );
        assertEq(
            IERC20(peg.getAppCoin(ID)).balanceOf(minter),
            0
        );
    }

    function testMintMax() public {
        _mintTokenTo(usdc, 100, minter);
        vm.startPrank(minter);
        peg.deposit(ID, address(usdc), _raw(100, address(usdc)));
        peg.mint(ID, alice, type(uint256).max);
        vm.stopPrank();

        assertEq(peg.getVaultBalance(ID, minter), 0);
        assertEq(
            IERC20(peg.getAppCoin(ID)).balanceOf(alice),
            _raw(100, address(0))
        );
        assertEq(
            IERC20(peg.getAppCoin(ID)).balanceOf(minter),
            0
        );
    }

    function testMintOverVaultReverts() public {
        _mintTokenTo(usdc, 100, minter);
        vm.startPrank(minter);
        peg.deposit(ID, address(usdc), _raw(10, address(usdc)));
        vm.expectRevert(); // underflow
        peg.mint(ID, alice, _raw(11, address(0)));
        vm.stopPrank();
    }

    //redeam :
    function testRedeemProRata() public {
        uint256 usdcBefore = usdc.balanceOf(alice);
        uint256 daiBefore  = dai.balanceOf(alice);


        _mintTokenTo(usdc, 100, minter);
        _mintTokenTo(dai, 300, minter);
        vm.startPrank(minter);
        peg.deposit(ID, address(usdc), _raw(100, address(usdc)));
        peg.deposit(ID, address(dai), _raw(300, address(dai)));
        peg.mint(ID, alice, _raw(400, address(0)));
        vm.stopPrank();

        assertEq(IERC20(peg.getAppCoin(ID)).balanceOf(alice), _raw(400, address(0)));

        uint256 poolBefore = peg.getTotalPool();

        vm.startPrank(alice);
        peg.redeam(peg.getAppCoin(ID), _raw(120, address(0)));
        vm.stopPrank();

        uint256 usdcOut = usdc.balanceOf(alice) - usdcBefore;
        uint256 daiOut  = dai.balanceOf(alice)  - daiBefore;

        // Alice balance should decrease
        assertEq(IERC20(peg.getAppCoin(ID)).balanceOf(alice), _raw(280, address(0)));

    //assume dust:
        assertGt(usdcOut, _raw(29, address(usdc)));
        assertLe(usdcOut, _raw(31, address(usdc)));
        assertGt(daiOut, _raw(89, address(dai)));
        assertLe(daiOut, _raw(91, address(dai)));

        uint256 poolAfter = peg.getTotalPool();

        // The pool decreased by the value amount in total (approximate)
        assertGt(poolBefore - poolAfter, 119);
        assertLe(poolBefore - poolAfter, 121);
    }

    function testRedeemZeroReverts_() public {
        vm.startPrank(alice);
        address tok = peg.getAppCoin(ID);
        vm.expectRevert();
        peg.redeam(tok, 0);
        vm.stopPrank();
    }

//withdraw :
    function testWithdrawExact() public {
        uint256 prevBal = usdc.balanceOf(alice);
        _mintTokenTo(usdc, 100, alice);
        vm.startPrank(alice);
        peg.deposit(ID, address(usdc), _raw(100, address(usdc)));
        peg.withdrawCollateral(ID, 40);
        vm.stopPrank();

        assertEq(usdc.balanceOf(alice) - prevBal, _raw(40, address(usdc)));
        assertEq(peg.getVaultBalance(ID, alice), 60);
    }

    function testWithdrawMax() public {
        uint256 prevBal = usdc.balanceOf(alice);
        _mintTokenTo(usdc, 100, alice);
        vm.startPrank(alice);
        peg.deposit(ID, address(usdc), _raw(100, address(usdc)));
        peg.withdrawCollateral(ID, type(uint256).max);
        vm.stopPrank();

        assertEq(usdc.balanceOf(alice) - prevBal, _raw(100, address(usdc)));
        assertEq(peg.getVaultBalance(ID, alice), 0);
    }

    function testWithdrawOverReverts() public {
        _mintTokenTo(usdc, 10, alice);
        vm.startPrank(alice);
        peg.deposit(ID, address(usdc), _raw(10, address(usdc)));
        vm.expectRevert(); 
        peg.withdrawCollateral(ID, 11);
        vm.stopPrank();
    }

    function testSendBasketUpdatesgetGlobalPool() public {
        _mintTokenTo(usdc, 100, alice);
        vm.startPrank(alice);
        peg.deposit(ID, address(usdc), _raw(100, address(usdc)));
        peg.withdrawCollateral(ID, 30);
        vm.stopPrank();

        assertEq(peg.getGlobalPool(address(usdc)), 70);
    }

}

