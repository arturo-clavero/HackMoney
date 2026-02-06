// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.13;

// import {AccessManager} from "./shared/AccessManager.sol";
// import {CollateralManager} from "./shared/CollateralManager.sol";
// import {Security} from "./shared/Security.sol";
// import {AppManager} from "./shared/AppManager.sol";
// import {Oracle} from "./shared/Oracle.sol";
// import {SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
// import {IERC20} from "@openzeppelin/interfaces/IERC20.sol";

// import {Error} from "../utils/ErrorLib.sol";

// contract SoftPeg is AppManager, Security, Oracle {

//     using SafeERC20 for IERC20;

//     uint256 constant MAX_COLLATERAL_TYPES = 5;
//     uint256 private constant DEFAULT_COIN_SCALE = 1e18;

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

//     function _calcNewShare(
//         uint256 assetChange,     
//         uint256 totalAssets, 
//         uint256 totalShares
//         ) internal returns (uint256 newShare) {
//         uint256 valuePerShare = totalAssets / totalShares;
//         newShare = assetChange / valuePerShare;
//     }

//     function _calcAssets(
//         uint256 _shares,
//         uint256 totalShares,
//         uint256 totalAssets
//     ) internal returns (uint256 _assets) {
//         _assets = (totalAssets * _shares ) / totalShares;
//     }

//     function _calcShares(
//         uint256 _assets,
//         uint256 totalAssets,
//         uint256 totalShares
//     ) internal returns (uint256 _shares) {
//         _shares = (totalShares * _assets ) / totalAssets;
//     }

//     function deposit(uint256 id, address token, uint256 rawAmount) external {
//         //check & transfer token
//         if (!_isAppCollateralAllowed(id, token))
//             revert Error.CollateralNotSupportedByApp();
//         if (rawAmount == 0)
//             revert Error.InvalidAmount();
//         IERC20(token).safeTransferFrom(msg.sender, address(this), rawAmount);
//         uint256 valueAmount = rawAmount / globalCollateralConfig[token].scale;

//         //check if new collateral share
//         Position storage pos = userPositions[id][msg.sender];
//         uint256 currentShare = pos.colShares[token];
//         if (currentShare == 0){
//             if (pos.colUsed.length >= MAX_COLLATERAL_TYPES)
//                 revert Error.MaxCollateralTypesPerPosition();
//             pos.colUsed.push(token);
//         }

//         //calc share & update:
//         //increase user shares
//         //increase vault total shares
//         //increase vault total assets
//         ColVault storage vault = collateralVaults[token];
//         uint256 newShare = _calcNewShare(valueAmount, vault.totalAssets, vault.totalShares);
//         vault.totalAssets += valueAmount;
//         vault.totalShares += newShare;
//         pos.colShares[token] = currentShare + newShare;
//     }

//     function mint(uint256 id, address to, uint256 rawAmount) public {
//         //How to calculate max debt extractable?
//         Position storage pos = userPositions[id][msg.sender];
//         uint256 len = pos.colUsed.length;
//         uint256 maxTotalDebt;
//         for (uint256 i = 0; i < len; i++){
//             address token = colUsed[i];
//             uint256 tokenShares = pos.colShares[token];
//             uint256 totalShares = collateralVaults[token].totalShares;
//             uint256 totalAssets = collateralVaults[token].totalAssets;
//             uint256 tokenAssets = _calcAssets(tokenShares, totalShares, totalAssets);
           
//             uint256 tokenLTV = globalCollateralConfig[token].LTV;
//             uint256 maxTokenDebt = tokenAssets * tokenLTV;
//             maxTotalDebt += maxTokenDebt;
//         }
//         uint256 userDebt = _calcAssets(pos.debtShares, totalDebtShares, totalDebt);
//         uint256 maxValueDebt = maxTotalDebt - userDebt;
//         uint256 valueAmount;
//         if (rawAmount == type(uint256).max)
//             rawAmount = maxValue * DEFAULT_COIN_SCALE;
//         valueDebt = rawAmount / DEFAULT_COIN_SCALE;
//         if (maxValueDebt > valueDebt)
//             revert InsufficientCollateral();
        
//         //calc share & update:
//         //increase user debt shares
//         //increase total debt shares
//         //increase total debt
//         uint256 newShare = _calcNewShare(valueDebt, totalDebt, totalDebtShares);
//         totalDebtShares += newShare;
//         pos.debtShares += newShare;
//         totalDebt += valueDebt;

//         //mint
//         uint256 rawDebt = valueDebt / DEFAULT_COIN_SCALE
//         _mintAppToken(id, to, rawDebt);
//     }

//     function withdrawCollateral(uint256 id, address token, uint256 valueAmount) external {
//         Position storage pos = userPositions[id][msg.sender];

//         if (pos.debtShares != 0)
//             revert UserHasDebt();

//         //calc share & update:
//         //decrease user shares
//         //decrease vault total shares
//         //decrease vault total assets

//         ColVault storage vault = collateralVaults[token];
//         uint256 shareOut = _calcShare(valueAmount, vault.totalShares, vault.totalAssets);
//         vault.totalAssets -= valueAmount;
//         vault.totalShares += shareOut;
//         pos.colShares[token] -= shareOut;

//         //send collatearl 
//         uint256 rawAmount = valueAmount * globalCollateralConfig[token].scale;
//         IERC20(token).safeTransfer(msg.sender, rawAmount);
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

   

//     // function getTotalPool() external view returns (uint256){
//     //     return totalPool;
//     // }

//     // function getGlobalPool(address token) external view returns (uint256){
//     //     return globalPool[token];
//     // }

//     // function getTotalSupply() external view returns (uint256){
//     //     return totalSupply;
//     // }

//     // function getVaultBalance(uint256 id, address user) external view returns (uint256) {
//     //     return (vault[id][user]);
//     // }

// }