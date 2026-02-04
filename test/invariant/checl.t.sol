// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.13;

// contract STSBRLTest is Test {
//     MockOracle oracle;
//     STSBRLCoin coin;

//     function setUp() external {
//         oracle = new MockOracle(
//             1e18, // initial price
//             300,  // 3% volatility
//             12345
//         );

//         coin = new STSBRLCoin(address(oracle));
//     }

//     function _isProfitable(
//     uint256 oraclePrice,
//     uint256 pegPrice,
//     uint256 redeemFeeBps
//     ) internal pure returns (bool) {
//         uint256 effectiveRedeem = (oraclePrice * (10_000 - redeemFeeBps)) / 10_000;
//         return effectiveRedeem > pegPrice;
//     }

//     function testFuzz_MintRedeemCycle(
//     uint96 deposit,
//     uint8 steps
//         ) external {
//             deposit = uint96(bound(deposit, 1e6, 1e24));
//             steps = uint8(bound(steps, 1, 50));

//             vm.deal(address(this), deposit);

//             coin.deposit{value: deposit}();
//             coin.mint();

//             for (uint256 i = 0; i < steps; i++) {
//                 oracle.update();

//                 uint256 p = oracle.priceView();

//                 if (p > 1.02e18) {
//                     coin.redeem();
//                 }

//                 // advance time to simulate market
//                 vm.warp(block.timestamp + 1 hours);
//                 vm.roll(block.number + 1);
//             }

//             // invariants
//             assertGe(oracle.priceView(), 1);
//         }

// }


// // //SANPSHOT + REVERT ON GOOD STATES...
// // uint256 snap = vm.snapshot();

// // oracle.update();

// // if (oracle.priceView() > 1.1e18) {
// //     // explore this path deeply
// // } else {
// //     vm.revertTo(snap);
// // }

// // //BIAS FUZZING toward volatility extremes
// // volatilityBps = uint256(bound(volatilityBps, 50, 1000));
// // oracle.setVolatility(volatilityBps);


// // //Combine fuzzing + invariant tests

// // function invariant_PriceNeverZero() external {
// //     assertGt(oracle.priceView(), 0);
// // }