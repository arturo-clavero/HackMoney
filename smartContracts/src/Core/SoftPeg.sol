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
import {Math} from "@openzeppelin/utils/math/Math.sol";
import {Error} from "../utils/ErrorLib.sol";

struct Position {
    mapping(address token => uint256 shares) colShares;
    address[] colUsed;
    uint256 debtShares;
    uint256 mintCredit;
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

//3. User Accounting
    mapping(uint256 id => mapping (address user => Position)) private userPositions;

//1. Global Collateral 
    mapping(address token => ColVault) private collateralVaults;

//2. Global debt
    uint256 private totalDebtShares;

//4. Liquidators Pool
        // uint256 pool_assets;
        // uint256 pool_shares;
        // mapping(address token => uint256 assets) private pool_collateral;

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

    

    function deposit(uint256 id, address token, uint256 rawAmount) external {
        //check & transfer token
        if (!_isAppCollateralAllowed(id, token))
            revert Error.CollateralNotSupportedByApp();
        if (rawAmount == 0)
            revert Error.InvalidAmount();
        IERC20(token).safeTransferFrom(msg.sender, address(this), rawAmount);
        uint256 valueAmount = rawAmount / globalCollateralConfig[token].scale;

        //check if new collateral share
        Position storage pos = userPositions[id][msg.sender];
        uint256 currentShare = pos.colShares[token];
        if (currentShare == 0){
            if (pos.colUsed.length >= MAX_COLLATERAL_TYPES)
                revert Error.MaxCollateralTypesPerPosition();
            pos.colUsed.push(token);
        }

        //calc share & update:
        //increase user shares
        //increase vault total shares
        //increase vault total assets
        ColVault storage vault = collateralVaults[token];
        uint256 newShare = valueAmount.calcNewShare(vault.totalAssets, vault.totalShares);
        vault.totalAssets += valueAmount;
        vault.totalShares += newShare;
        pos.colShares[token] = currentShare + newShare;

        //calc credit
        uint256 credit_value = Math.mulDiv(valueAmount * getPrice(token), globalCollateralConfig[token].LTV,
            WAD * 1e8
        );
        pos.mintCredit += credit_value;
    }

    function getCredit(address token) external returns (uint256 rawCredit){
        rawCredit = getPrice(token) * globalCollateralConfig[token].LTV / WAD;

    }

    function mint(uint256 id, address to, uint256 rawAmount) public {
        //How to calculate max debt extractable?
        //READ POSITION FROM MINTER
        Position storage minterPos = userPositions[id][msg.sender];
        Position storage toPos = userPositions[id][to];

        uint256 maxMintable_value = minterPos.mintCredit;
        if (rawAmount == type(uint256).max)
            rawAmount = maxMintable_value * DEFAULT_COIN_SCALE;
    
        uint256 newDebt_value = rawAmount / DEFAULT_COIN_SCALE;

        if (maxMintable_value == 0 || newDebt_value > maxMintable_value)
            revert Error.InsufficientCollateral();
        
        //calc share & update:
        //increase user debt shares OF TO_POSITION!
        //increase total debt shares
        //increase total debt
        //decrease the mint credits
        uint256 newShare = newDebt_value.calcNewShare(totalDebt, totalDebtShares);
        toPos.debtShares += newShare;
        totalDebtShares += newShare;
        totalDebt += newDebt_value;
        minterPos.mintCredit -= newDebt_value;

        //mint
        _mintAppToken(id, to, rawAmount);
    }

    function withdrawCollateral(uint256 id, address token, uint256 valueAmount) external {
        Position storage pos = userPositions[id][msg.sender];

        if (pos.debtShares != 0)
            revert Error.UserHasDebt();

        //calc share & update:
        //decrease user shares
        //decrease vault total shares
        //decrease vault total assets

        ColVault storage vault = collateralVaults[token];
        uint256 shareOut = valueAmount.calcShares(vault.totalShares, vault.totalAssets);
        vault.totalAssets -= valueAmount;
        vault.totalShares -= shareOut;
        pos.colShares[token] -= shareOut;
        if ( pos.colShares[token] == 0) {
            //remove index from token efficiently... ?
        }

        //send collatearl 
        uint256 rawAmount = valueAmount * globalCollateralConfig[token].scale;
        IERC20(token).safeTransfer(msg.sender, rawAmount);
    }


    // function redeam(address token, uint256 rawAmount) external {
    //     uint256 id = _getStablecoinID(token);
    //     if (rawAmount == 0)
    //         revert Error.InvalidAmount();
    //     uint256 valueAmount = rawAmount / DEFAULT_COIN_SCALE;
    //     totalSupply -= valueAmount;
    //     _burnAppToken(id, rawAmount);
    //     _sendCollateralBasket(valueAmount);
    // }

   

    // function getTotalPool() external view returns (uint256){
    //     return totalPool;
    // }

    // function getGlobalPool(address token) external view returns (uint256){
    //     return globalPool[token];
    // }

    // function getTotalSupply() external view returns (uint256){
    //     return totalSupply;
    // }

    // function getVaultBalance(uint256 id, address user) external view returns (uint256) {
    //     return (vault[id][user]);
    // }
    function getUserColShares(uint256 id, address user, address token) external returns (uint256) {
        return (userPositions[id][user].colShares[token]);
    }

    function getUserDebtShares(uint256 id, address user) external returns (uint256) {
        return (userPositions[id][user].debtShares);
    }

    function getUsersColUsed(uint256 id, address user) external returns (address[] memory) {
        return (userPositions[id][user].colUsed);
    }

    function getUsersMintCredit(uint256 id, address user) external returns (uint256) {
        return (userPositions[id][user].mintCredit);
    }

    function getCollateralVaults(address token) external returns (ColVault memory) {
        return (collateralVaults[token]);
    }


}