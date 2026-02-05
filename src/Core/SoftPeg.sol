// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {AccessManager} from "./shared/AccessManager.sol";
import {CollateralManager} from "./shared/CollateralManager.sol";
import {Security} from "./shared/Security.sol";
import {AppManager} from "./shared/AppManager.sol";
import {Oracle} from "./shared/Oracle.sol";
import {SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/interfaces/IERC20.sol";

import {Error} from "../utils/ErrorLib.sol";

// contract HardPeg is AppManager, Security, Oracle {

//     using SafeERC20 for IERC20;

//     uint256 constant MAX_COLLATERAL_TYPES = 5;

// //3. User Accounting
//     struct Position {
//         mapping(address token => uint256 shares) colShares;
//         address[] colUsed;
//         uint256 debtShares;
//     }
//     mapping(uint256 id => mapping (address user => Position)) userPositions;

// //1. Global Collateral 
//     struct ColVault {
//         uint256 totalAssets;
//         uint256 totalShares;
//     }
//     mapping(address token => ColVault) collateralVaults;

// //2. Global debt
//     uint256 totalDebt;
//     uint256 totalDebtShares;


// //4. Liquidators Pool
//         uint256 pool_assets;
//         uint256 pool_shares;
//         mapping(address token => uint256 assets) pool_collateral;

//     constructor(
//         address owner, 
//         address timelock, 
//         uint256 globalDebtcap, 
//         uint256 mintCapPerTx
//     )
//     AccessManager(owner, timelock)
//     CollateralManager(0) 
//     Security(globalDebtcap, mintCapPerTx)
//     {}

//     function _newShare(
//         uint256 totalAssets, 
//         uint256 totalShares,
//         uint256 assetChange
//         ) internal {
//         uint256 valuePerShare = totalAssets / totalShares;
//         uint256 newShare = assetChange / valuePerShare;
//         return newShare;
//     }

//     function deposit(uint256 id, address token, uint256 rawAmount) external {
//         if (!_isAppCollateralAllowed(id, token))
//             revert Error.CollateralNotSupportedByApp();
//         if (rawAmount == 0)
//             revert Error.InvalidAmount();
//         IERC20(token).safeTransferFrom(msg.sender, address(this), rawAmount);
//         uint256 valueAmount = rawAmount / globalCollateralConfig[token].scale;

//         Position storage pos = userPositions[id][user];
//         uint256 currentShare = pos.colShares[token];
//         if (currentShare == 0){
//             if (colUsed.length >= MAX_COLLATERAL_TYPES)
//                 revert Error.MaxCollateralTypesPerPosition();
//             colUsed.push(token);
//         }
//         ColVault storage vault = collateralVaults[token];
//         uint256 newShare = _newShare(vault.totalAssets, vault.totalShares, valueAmount);
//         vault.totalAssets += valueAmount;
//         vault.totalShares += newShare;
//         pos.colShares[token] = currentShare + newShare;
//     }

//     function mint(uint256 id, address to, uint256 rawAmount) public {
//         uint256 maxValue = vault[id][msg.sender];
//         uint256 valueAmount;
//         if (rawAmount == type(uint256).max)
//             rawAmount = maxValue * DEFAULT_COIN_SCALE;

//         valueAmount = rawAmount / DEFAULT_COIN_SCALE;

//         vault[id][msg.sender] = maxValue - valueAmount;
//         totalSupply += valueAmount;
//         _mintAppToken(id, to, rawAmount);
//     }


//     // function redeam(address token, uint256 rawAmount) external {
//     //     uint256 id = _getStablecoinID(token);
//     //     if (rawAmount == 0)
//     //         revert Error.InvalidAmount();
//     //     uint256 valueAmount = rawAmount / DEFAULT_COIN_SCALE;
//     //     totalSupply -= valueAmount;
//     //     _burnAppToken(id, rawAmount);
//     //     _sendCollateralBasket(valueAmount);
//     // }

//     function withdrawCollateral(uint256 id, uint256 valueAmount) external {
//         uint256 maxValue = vault[id][msg.sender];
//         if (valueAmount == type(uint256).max)
//             valueAmount = maxValue;
//         vault[id][msg.sender] = maxValue - valueAmount;
//         _sendCollateralBasket(valueAmount);
//     }

//     function getTotalPool() external view returns (uint256){
//         return totalPool;
//     }

//     function getGlobalPool(address token) external view returns (uint256){
//         return globalPool[token];
//     }

//     function getTotalSupply() external view returns (uint256){
//         return totalSupply;
//     }

//     function getVaultBalance(uint256 id, address user) external view returns (uint256) {
//         return (vault[id][user]);
//     }

// }