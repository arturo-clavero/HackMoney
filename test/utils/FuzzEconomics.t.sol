// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../src/Core/HardPeg.sol";
import "../utils/BaseEconomicTest.t.sol";
import "../mocks/MockRandomOracle.sol";
import {MockToken} from "../mocks/MockToken.sol";

abstract contract FuzzEconomicTest is BaseEconomicTest {

    MockOracle public oracle;
    uint256 public ticks;
    uint256 public seed;

    function setUpFuzz(
        uint256 _ticks,
        uint256 _seed,
        uint256 initialPrice,
        uint256 volatilityBps
    ) internal {
        ticks = _ticks;
        seed = _seed;

        oracle = new MockOracle(initialPrice, volatilityBps, seed);
    }

    function runFuzz() internal {
        for (uint256 t = 0; t < ticks; t++) {

            // 1. Update oracle price
            try oracle.update() {} catch {}
            uint256 currentPrice = oracle.priceView();

            // 2. Randomly pick a user and action
            uint256 userIdx = _random(users.length, t);
            address user = users[userIdx];

            uint256 appIdx = _random(appIDs.length, t);
            uint256 appId = appIDs[appIdx];

            uint256 tokenIdx = _random(tokens.length, t);
            MockToken token = tokens[tokenIdx];

            uint256 action = _random(5, t); 
            
            // 0=deposit,1=withdraw,2=mint,3=redeem,4=transfer
            if (action == 0) _fuzzDeposit(user, appId, token, t);
            else if (action == 1) _fuzzWithdraw(user, appId, t);
            else if (action == 2) _fuzzMint(user, appId, t);
            else if (action == 3) _fuzzRedeem(user, appId, t);
            else if (action == 4) _fuzzTransfer(user, appId, t);

            _assertConservation();
            _assertSolvency();
        }
    }

    // ---------- FUZZ ACTIONS ----------

    function _fuzzDeposit(address user, uint256 appId, MockToken token, uint256 t) internal {
        uint256 maxAmount = token.balanceOf(user);
        if (maxAmount == 0) return;

        uint256 amount = _random(maxAmount, t) + 1;
        vm.startPrank(user);
        try peg.deposit(appId, address(token), amount) {} catch {}
        vm.stopPrank();
    }

    function _fuzzWithdraw(address user, uint256 appId, uint256 t) internal {
        uint256 vaultBal = peg.getVaultBalance(appId, user);
        if (vaultBal == 0) return;

        uint256 amount = _random(vaultBal, t) + 1;
        vm.startPrank(user);
        try peg.withdrawCollateral(appId, amount) {} catch {}
        vm.stopPrank();
    }

    function _fuzzMint(address user, uint256 appId, uint256 t) internal {
        uint256 vaultBal = peg.getVaultBalance(appId, user);
        if (vaultBal == 0) return;

        uint256 amount = _random(vaultBal, t) + 1;
        vm.startPrank(user);
        try peg.mint(appId, user, amount) {} catch {}
        vm.stopPrank();
    }

    function _fuzzRedeem(address user, uint256 appId, uint256 t) internal {
        address coin = peg.getAppCoin(appId);
        uint256 bal = IERC20(coin).balanceOf(user);
        if (bal == 0) return;

        uint256 amount = _random(bal, t) + 1;
        vm.startPrank(user);
        try peg.redeam(coin, amount) {} catch {}
        vm.stopPrank();
    }

    function _fuzzTransfer(address user, uint256 appId, uint256 t) internal {
        address coin = peg.getAppCoin(appId);
        uint256 bal = IERC20(coin).balanceOf(user);
        if (bal == 0 || totalUsers <= 1) return;

        uint256 amount = _random(bal, t) + 1;
        uint256 recipientIdx = _random(totalUsers - 1, t);
        address recipient = users[recipientIdx];
        if (recipient == user) return;

        vm.startPrank(user);
        try IERC20(coin).transfer(recipient, amount) {} catch {}
        vm.stopPrank();
    }

    // ---------- HELPERS ----------

    function _random(uint256 max, uint256 t) internal view returns (uint256) {
        return uint256(keccak256(abi.encode(seed, block.timestamp, block.number, t))) % max;
    }
}
