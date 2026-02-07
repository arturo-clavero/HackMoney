// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./FuzzEconomics.t.sol";

contract HardPegFuzzTest is FuzzEconomicTest {

    function setUp() public {
        uint256 _totalTokens = 2;
        uint256 _totalUsers = 3;
        uint256 _totalApps = 2;

        (uint256[] memory modes, 
        uint8[] memory decimals,
        uint256[] memory initialPrices,
        uint256[] memory volatilitysBps) = _getTokenValues(_totalTokens);

        setUpBase(modes, decimals, _totalUsers, _totalApps);
        
        setUpFuzz(
            12345,          // seed
            initialPrices,  // initial oracle price
            volatilitysBps  // volatility bps
        );
    }

    // function testXX()public {
    //     assert(1 == 1);
    // }


    /// SET UP HELPERS

    function _updateSetUp(uint256 _totalTokens, uint256 _totalUsers, uint256 _totalApps) private {
        (uint256[] memory modes, 
        uint8[] memory decimals,
        uint256[] memory initialPrices,
        uint256[] memory volatilitysBps) = _getTokenValues(_totalTokens);

        _updateBase(modes, decimals, _totalUsers, _totalApps);
        
        _updateFuzz(
            initialPrices,  // initial oracle price
            volatilitysBps  // volatility bps
        );
    }

    function _getTokenValues(uint256 _totalTokens) internal pure returns (
        uint256[] memory modes,
        uint8[] memory decimals,
        uint256[] memory initialPrices,
        uint256[] memory volatilitysBps
    ){
        modes = new uint256[](_totalTokens);
        decimals = new uint8[](_totalTokens);
        initialPrices = new uint256[](_totalTokens);
        volatilitysBps = new uint256[](_totalTokens);

        for(uint256 i = 0; i < _totalTokens; i++){
            initialPrices[i] = 1e18;
            volatilitysBps[i] = _randomStableVol(i);
            modes[i] = core.COL_MODE_STABLE;
            decimals[i] = _randomDecimals(i);
        }
    }

    function _randomStableVol(uint256 i) internal pure returns (uint256) {
        uint256 r = uint256(keccak256(abi.encode(i))) % 100;

        if (r < 70) {
            return 1 + (r % 5);          // 1–5 bps
        } else if (r < 90) {
            return 10 + (r % 40);        // 10–50 bps
        } else {
            return 100 + (r % 400);      // 100–500 bps
        }
    }

    function _randomDecimals(uint256 i) internal pure returns (uint8) {
        uint256 r = uint256(keccak256(abi.encode(i))) % 100;
        if (r < 70) {
            return 18;              // ERC20 standard
        } else if (r < 90) {
            return 6;               // USDC / USDT
        } else if (r < 95) {
            return 8 + uint8(r % 2); // 8 or 9
        } else {
            return uint8(r % 3);    // 0, 1, or 2 (evil edge cases)
        }
    }



    //TEST FUNCTIONS 


    function testFuzzEconomics_Accounting() public {
        //500 = n of loops (ticks)
        _updateSetUp(3, 8, 10);
        uint256 n = 20;
        runFuzzAccounting(n);
    }

    function testFuzzEconomics_Value() public {
        //100 = n of loops (ticks)
        _updateSetUp(5, 2, 2);
        uint256 n = 10;
        runFuzzOracleValue(n);
    }

    function testFuzzEconomics_Agents() public {
        //100 = n of loops (ticks)
        _updateSetUp(5, 2, 2);
        uint256 n = 10;
        runFuzzAgents(n);
    }
}
