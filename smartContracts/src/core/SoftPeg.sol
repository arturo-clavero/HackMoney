// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {AccessManager} from "./shared/AccessManager.sol";
import {CollateralManager} from "./shared/CollateralManager.sol";
import {Security} from "./shared/Security.sol";
import {AppManager} from "./shared/AppManager.sol";
import {Oracle} from "./shared/Oracle.sol";
import {SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/interfaces/IERC20.sol";

import {RiskMath} from "../utils/RiskMathLib.sol";
import {Roles} from "../utils/RolesLib.sol";
import {Error} from "../utils/ErrorLib.sol";
import {IPrivateCoin} from "./../interfaces/IPrivateCoin.sol";

struct Position {
    mapping(address token => uint256 shares) colShares;
    address[] colUsed;
    uint256 debtShares;
}
struct ColVault {
    uint256 totalAssets;
    uint256 totalShares;
}

contract SoftPeg is AppManager, Security, Oracle {

    using SafeERC20 for IERC20;
    using RiskMath for uint256;

    uint256 constant MAX_COLLATERAL_TYPES = 5;
    uint256 private constant DEFAULT_COIN_SCALE = 1e18;

    mapping(uint256 id => mapping (address user => Position)) private userPositions;

    mapping(address token => ColVault) private collateralVaults;

    uint256 private totalDebtShares;

    constructor(
        address owner, 
        address timelock, 
        uint256 globalDebtcap, 
        uint256 mintCapPerTx
    )
    AccessManager(owner, timelock)
    CollateralManager(2) 
    Security(globalDebtcap, mintCapPerTx)
    {}

    function depositTo(uint256 id, address to, address token, uint256 rawAmount) public {
        if (!_isAppCollateralAllowed(id, token))
            revert Error.CollateralNotSupportedByApp();
        if (rawAmount == 0)
            revert Error.InvalidAmount();
        IERC20(token).safeTransferFrom(to, address(this), rawAmount);
        uint256 valueAmount = rawAmount / globalCollateralConfig[token].scale;

        Position storage pos = userPositions[id][to];
        uint256 currentShare = pos.colShares[token];
        if (currentShare == 0){
            if (pos.colUsed.length >= MAX_COLLATERAL_TYPES)
                revert Error.MaxCollateralTypesPerPosition();
            pos.colUsed.push(token);
        }

        ColVault storage vault = collateralVaults[token];
        uint256 newShare = valueAmount.calcNewShare(vault.totalAssets, vault.totalShares);
        vault.totalAssets += valueAmount;
        vault.totalShares += newShare;
        pos.colShares[token] = currentShare + newShare;

    }
    function deposit(uint256 id, address token, uint256 rawAmount) external {
        depositTo(id, msg.sender, token, rawAmount);
    }

    function _getMintCredit(Position storage pos) internal view returns (uint256 mintCredit) {
        uint256 len = pos.colUsed.length;
        for (uint256 i = 0; i < len; i++){
            address token = pos.colUsed[i];
            uint256 share = pos.colShares[token];
            if (share == 0) continue;
            ColVault storage vault = collateralVaults[token];
            uint256 valueAmount = share.calcAssets(vault.totalShares, vault.totalAssets);
            mintCredit += RiskMath.safeMulDiv(valueAmount * getPrice(token), globalCollateralConfig[token].LTV,
                RiskMath.WAD * 1e8
            );
        }
        mintCredit -= pos.debtShares.calcAssets(totalDebtShares, totalDebt);
    }
  
    function mint(uint256 id, address to, uint256 rawAmount) external {
        if (rawAmount == 0)
            revert Error.InvalidAmount();
        Position storage minterPos = userPositions[id][msg.sender];

        uint256 maxMintable_value = _getMintCredit(minterPos);
        if (rawAmount == type(uint256).max)
            rawAmount = maxMintable_value * DEFAULT_COIN_SCALE;
    
        uint256 newDebt_value = rawAmount / DEFAULT_COIN_SCALE;

        if (maxMintable_value == 0 || rawAmount > maxMintable_value * DEFAULT_COIN_SCALE)
            revert Error.InsufficientCollateral();
        
        uint256 newShare = newDebt_value.calcNewShare(totalDebt, totalDebtShares);
        minterPos.debtShares += newShare;
        totalDebtShares += newShare;
        totalDebt += newDebt_value;

        _mintAppToken(id, to, rawAmount);
    }

    function _mintAppToken(uint256 appID, address to, uint256 value) internal override {
        IPrivateCoin(getAppCoin(appID)).mint(msg.sender, to, value, roles[msg.sender] & Roles.LIQUIDATOR != 0);
    }
    
    function withdrawCollateral(uint256 id, address token, uint256 valueAmount) external {
        _withdrawCollateral(id, msg.sender, token, valueAmount, msg.sender, false);
    }

    function withdrawCollateralTo(uint256 id, address to, address token, uint256 valueAmount) external {
        _withdrawCollateral(id, msg.sender, token, valueAmount, to, false);
    }

    function _withdrawCollateral(uint256 id, address user, address token, uint256 valueAmount, address receiver, bool isLiquidation) internal {
        Position storage pos = userPositions[id][user];

        if (!isLiquidation && pos.debtShares != 0)
            revert Error.UserHasDebt();

        ColVault storage vault = collateralVaults[token];
        uint256 shareOut = valueAmount.calcShares(vault.totalShares, vault.totalAssets);
        vault.totalAssets -= valueAmount;
        vault.totalShares -= shareOut;
        pos.colShares[token] -= shareOut;
        if (pos.colShares[token] == 0) {
            //not sure how
        }

        uint256 rawAmount = valueAmount * globalCollateralConfig[token].scale;
        IERC20(token).safeTransfer(receiver, rawAmount);
    }

    function repay(uint256 id, uint256 rawAmount) public {
        if (rawAmount == 0)
            revert Error.InvalidAmount();
        uint256 valueAmount = rawAmount / DEFAULT_COIN_SCALE;

        uint256 newDebtShare = valueAmount.calcNewShare(totalDebt, totalDebtShares);
        userPositions[id][msg.sender].debtShares -= newDebtShare;
        totalDebtShares -= newDebtShare;
        totalDebt -= valueAmount;

        _burnAppToken(id, rawAmount);

        //send propprtonal collateral? 
    }

    function redeem(uint256 id, uint256 rawAmount) external {
        repay(id, rawAmount);
    }

    function liquidate(uint256 id, address user, uint256 rawAmountIn) external {
        //1. checks : 
        if (rawAmountIn == 0)
            revert Error.InvalidAmount();
        Position storage pos = userPositions[id][user];
        //2. CALCULATE with oracle: health, basket prices (per col & total)
        uint256 len = pos.colUsed.length;
        uint256[] memory colBasket = new uint256[](len);
        uint256 maxDebt;
        uint256 totalColBasket; 
        for (uint256 i = 0; i < len; i++){
            address colToken = pos.colUsed[i];
            uint256 share = pos.colShares[colToken];
            if (share == 0) continue;
            ColVault storage vault = collateralVaults[colToken];
            uint256 _valueAmount = share.calcAssets(vault.totalShares, vault.totalAssets);
            uint256 valuePrice = _valueAmount * getPrice(colToken);
            maxDebt += RiskMath.safeMulDiv(valuePrice, globalCollateralConfig[colToken].liquidityThreshold,
                RiskMath.WAD * 1e8
            );
            //take advantage of loop + oracle to set basket for transfers...
            valuePrice /= 1e8;
            colBasket[i] = valuePrice;
            totalColBasket += valuePrice;
        }

        //check health
        uint256 actualDebt = pos.debtShares.calcAssets(totalDebtShares, totalDebt);
        if (actualDebt < maxDebt)
            revert Error.PositionIsHealthy();
        
        //cap liquidation amount
        uint256 maxLiquidation = actualDebt - maxDebt;
        uint256 valueAmount = rawAmountIn / DEFAULT_COIN_SCALE;
        if (valueAmount > maxLiquidation){
            valueAmount = maxLiquidation;
        }

        // //IN stablecoin
        uint256 newDebtShare = valueAmount.calcNewShare(totalDebt, totalDebtShares);
        if (newDebtShare == 0)
            revert Error.LiquidationDust();
        userPositions[id][user].debtShares -= newDebtShare;
        totalDebtShares -= newDebtShare;
        totalDebt -= valueAmount;
        _burnAppToken(id, valueAmount * DEFAULT_COIN_SCALE);

        //OUT collateral
        for (uint256 i = 0; i < len; i++) {
            address colToken = pos.colUsed[i];
            uint256 share = pos.colShares[colToken];
            if (share == 0) continue;

            //calc share out
            uint256 colOut_value = RiskMath.safeFirstMulDiv(valueAmount, colBasket[i], totalColBasket);
            ColVault storage vault = collateralVaults[colToken];
            uint256 shareOut = colOut_value.calcShares(vault.totalAssets, vault.totalShares);
            if (shareOut == 0) continue;

            //reduce col->
            // reduce total assets 
            // reduce total shares
            // reduce user shares 
            vault.totalAssets -= colOut_value;
            vault.totalShares -= shareOut;
            pos.colShares[colToken] -= shareOut;

            uint256 rawAmountOut = colOut_value * globalCollateralConfig[colToken].scale;
            IERC20(colToken).safeTransfer(msg.sender, rawAmountOut);
        }
    }

    
    function getUserColShares(uint256 id, address user, address token) external view returns (uint256) {
        return (userPositions[id][user].colShares[token]);
    }

    function getUserDebtShares(uint256 id, address user) external view returns (uint256) {
        return (userPositions[id][user].debtShares);
    }

    function getUsersColUsed(uint256 id, address user) external view returns (address[] memory) {
        return (userPositions[id][user].colUsed);
    }

    function getUsersMintCredit(uint256 id, address user) external view returns (uint256) {
        Position storage pos = userPositions[id][user];
        return _getMintCredit(pos);
    }

    function getCollateralVaults(address token) external view returns (ColVault memory) {
        return (collateralVaults[token]);
    }

    function getTotalDebtShares() external view returns (uint256){
        return totalDebtShares;
    }
    function getTotalDebt() external view returns(uint256){
        return totalDebt;
    }

}

 