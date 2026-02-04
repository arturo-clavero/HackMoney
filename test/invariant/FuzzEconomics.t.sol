// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../src/Core/HardPeg.sol";
import "../utils/BaseEconomicTest.t.sol";
import "../mocks/MockRandomOracle.sol";
import {MockToken} from "../mocks/MockToken.sol";

enum AgentType {
    RETAIL,
    ARB,
    WHALE,
    GRIEFER
}

abstract contract FuzzEconomicTest is BaseEconomicTest {

    MockOracle public oracle;
    uint256 public seed;

    mapping(address => AgentType) public agentOf;


    function setUpFuzz(
        uint256 _seed,
        uint256[] memory initialPrice,
        uint256[] memory volatilityBps
    ) internal {
        seed = _seed;
        oracle = new MockOracle(seed);
        for (uint256 i = 0; i < tokens.length; i++){
            oracle.setAsset(address(tokens[i]), initialPrice[i], volatilityBps[i]);
        }
        // _assignAgents();
    }

    function _updateFuzz(
        uint256[] memory initialPrice,
        uint256[] memory volatilityBps
    ) internal {
        oracle = new MockOracle(seed);
        for (uint256 i = 0; i < tokens.length; i++){
            oracle.setAsset(address(tokens[i]), initialPrice[i], volatilityBps[i]);
        }
        // _assignAgents();
    }

    function runFuzzAccounting(uint256 _ticks) internal {
        for (uint256 t = 0; t < _ticks; t++) {
            simulation(t, false, false);
            _assertConservation();
            _assertSolvency();
        }
    }

    function runFuzzOracleValue(uint256 _ticks) internal {
        for (uint256 t = 0; t < _ticks; t++) {
            simulation(t, true, false);
            _assertConservation();
            _assertValueSolvency();
        }
    }

    function runFuzzAgents(uint256 _ticks) internal {
        _assignAgents();
        for (uint256 t = 0; t < _ticks; t++) {
            simulation(t, true, true);
            _assertConservation();
            _assertValueSolvency();
        }
    }

    function simulation(uint256 t, bool useOracle, bool useAgents) internal {
        uint256 userIdx = _random(users.length, t);
        address user = users[userIdx];
        uint256 appIdx = _random(appIDs.length, t);
        uint256 appId = appIDs[appIdx];
        uint256 tokenIdx = _random(tokens.length, t);
        MockToken token = tokens[tokenIdx];

        
        uint256 currentPrice;
        if (useOracle){
            for (uint256 i = 0; i < tokens.length; i++){
                try oracle.update(address(tokens[i])) {} catch {}
            }
            currentPrice = oracle.priceView(address(token));

        }
        if (useAgents) {
            AgentType agent = agentOf[user];
            if (agent == AgentType.RETAIL) {
                _actRetail(user, appId, token, t);
            } else if (agent == AgentType.ARB) {
                _actArb(user, appId, token, currentPrice, t);
            } else if (agent == AgentType.WHALE) {
                _actWhale(user, appId, token, t);
            } else {
                _actGriefer(user, appId, token, t);
            }
        }
        else {
            uint256 action = _random(5, t); 
            if (action == 0) 
                _fuzzDeposit(user, appId, token, t);
            else if (action == 1) 
                _fuzzWithdraw(user, appId, t);
            else if (action == 2) 
                _fuzzMint(user, appId, t);
            else if (action == 3 && (!useOracle || _isProfitable(currentPrice)))
                _fuzzRedeem(user, appId, t);
            else if (action == 4) 
                _fuzzTransfer(user, appId, t);
        }              
    }
        // ---------- FUZZ AGENTSS ----------

    function _actRetail(
        address user,
        uint256 appId,
        MockToken token,
        uint256 t
    ) internal {
        uint256 r = _random(100, t);

        if (r < 40) _fuzzDeposit(user, appId, token, t);
        else if (r < 60) _fuzzMint(user, appId, t);
        else if (r < 85) _fuzzTransfer(user, appId, t);
        else _fuzzWithdraw(user, appId, t);
    }

    function _actArb(
        address user,
        uint256 appId,
        MockToken token,
        uint256 price,
        uint256 t
    ) internal {
        if (_isProfitable(price)) {
            _fuzzRedeem(user, appId, t);
        } else {
            // occasionally prep inventory
            if (_random(10, t) == 0) {
                _fuzzDeposit(user, appId, token, t);
            }
        }
    }

    function _actWhale(
        address user,
        uint256 appId,
        MockToken token,
        uint256 t
    ) internal {
        uint256 r = _random(100, t);

        if (r < 50) _fuzzDeposit(user, appId, token, t);
        else if (r < 75) _fuzzMint(user, appId, t);
        else _fuzzRedeem(user, appId, t);
    }

    function _actGriefer(
        address user,
        uint256 appId,
        MockToken token,
        uint256 t
    ) internal {
        uint256 r = _random(5, t);

        if (r == 0) _fuzzWithdraw(user, appId, t);
        else if (r == 1) _fuzzMint(user, appId, t);
        else if (r == 2) _fuzzRedeem(user, appId, t);
        else if (r == 3) _fuzzTransfer(user, appId, t);
        else _fuzzDeposit(user, appId, token, t);
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

    function _assignAgents() internal {
        for (uint256 i = 0; i < users.length; i++) {
            uint256 r = uint256(keccak256(abi.encode(seed, i))) % 100;

            if (r < 45) agentOf[users[i]] = AgentType.RETAIL;
            else if (r < 70) agentOf[users[i]] = AgentType.ARB;
            else if (r < 90) agentOf[users[i]] = AgentType.WHALE;
            else agentOf[users[i]] = AgentType.GRIEFER;
        }
    }

    function _random(uint256 max, uint256 t) internal view returns (uint256) {
        return uint256(keccak256(abi.encode(seed, block.timestamp, block.number, t))) % max;
    }

/// could change per peg:

    function _isProfitable(uint256 price) internal pure returns (bool) {
        return (price > 1.01e18 || price < 0.99e18);
    }


    function _assertValueSolvency() internal {

        uint256[] memory prices = new uint256[](totalTokens);
        for (uint256 i = 0; i < totalTokens; i++){
            prices[i] = oracle.priceView(address(tokens[i]));
        }

        uint256 totalCollateralUsd = _calculateTotalCollateral(true, prices);
        uint256 totalDebtUsd =  _calculateTotalDebt();

        assert(totalCollateralUsd >= totalDebtUsd);
    }



   

}
