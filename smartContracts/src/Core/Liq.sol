//  /// @notice Public liquidation by amount
// function liquidate(uint256 id, address user, uint256 rawAmountIn) external {
//     if (rawAmountIn == 0) revert Error.InvalidAmount();

//     // compute max liquidation allowed
//     (
//         uint256 maxLiquidationValue,
//         uint256 actualDebt,
//         uint256[] memory colBasket,
//         uint256 totalColValue
//     ) = _computeLiquidationValuesWithBasket(id, user);

//     uint256 valueAmount = rawAmountIn / DEFAULT_COIN_SCALE;
//     if (valueAmount > maxLiquidationValue) {
//         valueAmount = maxLiquidationValue;
//     }

//     uint256 sharesToBurn = valueAmount.calcNewShare(totalDebt, totalDebtShares);
//     if (sharesToBurn == 0) revert Error.LiquidationDust();

//     _liquidateSharesWithBasket(id, user, sharesToBurn, msg.sender, colBasket, totalColValue);
// }


// function _liquidateShares(
//     uint256 id,
//     address user,
//     uint256 debtSharesToBurn,
//     address receiver
// ) internal {
//     Position storage pos = userPositions[id][user];

//     if (debtSharesToBurn == 0 || debtSharesToBurn > pos.debtShares)
//         revert Error.InvalidAmount();

//     uint256 valueAmount = debtSharesToBurn.calcAssets(totalDebt, totalDebtShares);

//     // burn stable from caller
//     _burnAppToken(id, valueAmount * DEFAULT_COIN_SCALE);

//     // update accounting
//     pos.debtShares -= debtSharesToBurn;
//     totalDebtShares -= debtSharesToBurn;
//     totalDebt -= valueAmount;

//     // distribute collateral proportionally
//     _distributeCollateralProRata(id, user, valueAmount, receiver);
// }


// /// @notice Public liquidation by exact debt shares
// function liquidateShares(uint256 id, address user, uint256 debtSharesToBurn) external {
//     _revertIfHealthy(id, user);

//     // compute basket for collateral distribution
//     (
//         uint256[] memory colBasket,
//         uint256 totalColValue
//     ) = _computeCollateralBasket(id, user);

//     _liquidateSharesWithBasket(id, user, debtSharesToBurn, msg.sender, colBasket, totalColValue);
// }



// /// @dev Internal core that does all state updates and collateral transfers
// function _liquidateSharesWithBasket(
//     uint256 id,
//     address user,
//     uint256 debtSharesToBurn,
//     address receiver,
//     uint256[] memory colBasket,
//     uint256 totalColValue
// ) internal {
//     Position storage pos = userPositions[id][user];
//     if (debtSharesToBurn == 0 || debtSharesToBurn > pos.debtShares)
//         revert Error.InvalidAmount();

//     uint256 valueAmount = debtSharesToBurn.calcAssets(totalDebt, totalDebtShares);

//     // burn stablecoin
//     _burnAppToken(id, valueAmount * DEFAULT_COIN_SCALE);

//     // update accounting
//     pos.debtShares -= debtSharesToBurn;
//     totalDebtShares -= debtSharesToBurn;
//     totalDebt -= valueAmount;

//     // distribute collateral pro-rata
//     _distributeCollateralProRataWithBasket(id, user, valueAmount, receiver, colBasket, totalColValue);
// }

// /// @dev Compute max liquidation and basket for amount-based liquidation
// function _computeLiquidationValuesWithBasket(uint256 id, address user)
//     internal
//     view
//     returns (
//         uint256 maxLiquidation,
//         uint256 actualDebt,
//         uint256[] memory colBasket,
//         uint256 totalColValue
//     )
// {
//     Position storage pos = userPositions[id][user];
//     uint256 len = pos.colUsed.length;
//     colBasket = new uint256[](len);
//     totalColValue = 0;
//     uint256 maxDebt = 0;

//     for (uint256 i; i < len; i++) {
//         address colToken = pos.colUsed[i];
//         uint256 share = pos.colShares[colToken];
//         if (share == 0) continue;

//         ColVault storage vault = collateralVaults[colToken];
//         uint256 valueAmount = share.calcAssets(vault.totalShares, vault.totalAssets);
//         uint256 valuePrice = valueAmount * getPrice(colToken);

//         maxDebt += RiskMath.safeMulDiv(valuePrice, globalCollateralConfig[colToken].liquidityThreshold, WAD * 1e8);

//         valuePrice /= 1e8;
//         colBasket[i] = valuePrice;
//         totalColValue += valuePrice;
//     }

//     actualDebt = pos.debtShares.calcAssets(totalDebtShares, totalDebt);

//     if (actualDebt < maxDebt) revert Error.PositionIsHealthy();

//     maxLiquidation = actualDebt - maxDebt;
// }

// /// @dev Compute only basket for exact share liquidation
// function _computeCollateralBasket(uint256 id, address user)
//     internal
//     view
//     returns (uint256[] memory colBasket, uint256 totalColValue)
// {
//     Position storage pos = userPositions[id][user];
//     uint256 len = pos.colUsed.length;
//     colBasket = new uint256[](len);
//     totalColValue = 0;

//     for (uint256 i; i < len; i++) {
//         address colToken = pos.colUsed[i];
//         uint256 share = pos.colShares[colToken];
//         if (share == 0) continue;

//         ColVault storage vault = collateralVaults[colToken];
//         uint256 valueAmount = share.calcAssets(vault.totalShares, vault.totalAssets);
//         uint256 valuePrice = valueAmount * getPrice(colToken);
//         valuePrice /= 1e8;

//         colBasket[i] = valuePrice;
//         totalColValue += valuePrice;
//     }
// }

// /// @dev Distribute collateral using precomputed basket
// function _distributeCollateralProRataWithBasket(
//     uint256 id,
//     address user,
//     uint256 valueAmount,
//     address receiver,
//     uint256[] memory colBasket,
//     uint256 totalColValue
// ) internal {
//     Position storage pos = userPositions[id][user];
//     uint256 len = pos.colUsed.length;

//     for (uint256 i; i < len; i++) {
//         uint256 share = pos.colShares[pos.colUsed[i]];
//         if (share == 0 || colBasket[i] == 0) continue;

//         uint256 outValue = RiskMath.safeFirstMulDiv(valueAmount, colBasket[i], totalColValue);
//         _withdrawCollateral(id, user, pos.colUsed[i], outValue, receiver, true);
//     }
// }
