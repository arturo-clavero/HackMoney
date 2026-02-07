// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {AccessManager} from "./shared/AccessManager.sol";
import {CollateralManager} from "./shared/CollateralManager.sol";
import {Security} from "./shared/Security.sol";
import {AppManager} from "./shared/AppManager.sol";

import {RiskEngine} from "./../utils/RiskEngineLib.sol";

import {SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/interfaces/IERC20.sol";

import {Error} from "../utils/ErrorLib.sol";


/**
 * @title HardPeg
 * @notice Stablecoin system backed by a basket of supported collateral tokens.
 * @dev
 * Each HardPeg instance:
 *  - Tracks collateral in "value units" for internal accounting.
 *  - Mints a 1:1 ratio of app coins against collateral.
 *  - Supports redemption and collateral withdrawal in pro-rata fashion.
 *  - No liquidations or price oracles are used in this implementation.
 */
contract HardPeg is AppManager, Security {

    using SafeERC20 for IERC20;
    using RiskEngine for address;

    /// @notice Internal scaling factor for value-to-raw conversions
    uint256 private constant DEFAULT_COIN_SCALE = 1e18;

    /// @notice Total value of all collateral across all apps (in "value units")
    uint256 private totalPool;

    /// @notice Total supply of all app stablecoins (in "value units")
    uint256 private totalSupply;                                     

    /// @notice Collateral type => total value amount
    mapping(address colType => uint256 valueAmount) private globalPool; 
    
    /// @notice App ID => user address => value amount deposited
    mapping (uint256 id =>
        mapping(address user => uint256 valueAmount)) private vault; 
        
    /**
     * @notice Constructor
     * @param owner Protocol owner address
     * @param timelock Protocol timelock address
     */
    constructor(
        address owner, 
        address timelock, 
        uint256 globalDebtcap, 
        uint256 mintCapPerTx
    )
    AccessManager(owner, timelock)
    CollateralManager(0) 
    Security(globalDebtcap, mintCapPerTx)
    {}
    //for medium peg = stable + yield
    //collateral manager(1) --> model will accept colalteral of type yield
    //for medium peeg its recommended you look at erc4246 vaults to calcualte the yield for you

    /**
     * @notice Deposit collateral into the app
     * @dev Only supported collateral is accepted. `rawAmount` is in token units.
     * @param id App ID
     * @param token Collateral token address
     * @param rawAmount Amount of collateral tokens to deposit
     */
    function deposit(uint256 id, address token, uint256 rawAmount) external {
        if (!_isAppCollateralAllowed(id, token))
            revert Error.CollateralNotSupportedByApp();
        if (rawAmount == 0)
            revert Error.InvalidAmount();
        IERC20(token).safeTransferFrom(msg.sender, address(this), rawAmount);
        uint256 valueAmount = rawAmount / globalCollateralConfig[token].scale;
        vault[id][msg.sender] += valueAmount;
        globalPool[token] += valueAmount;
        totalPool += valueAmount;
    }

    /**
     * @notice Mint app stablecoins
     * @dev Mints at 1:1 ratio of `valueAmount` against available collateral.
     * @param id App ID
     * @param to Recipient address
     * @param rawAmount Amount of stablecoins to mint (in raw units). Use `type(uint256).max` to mint max available.
     */
    function mint(uint256 id, address to, uint256 rawAmount) public {
        uint256 maxValue = vault[id][msg.sender];
        uint256 valueAmount;
        if (rawAmount == type(uint256).max)
            rawAmount = maxValue * DEFAULT_COIN_SCALE;

        valueAmount = rawAmount / DEFAULT_COIN_SCALE;

        vault[id][msg.sender] = maxValue - valueAmount;
        totalSupply += valueAmount;
        _mintAppToken(id, to, rawAmount);
    }

    /**
     * @notice Redeem app stablecoins for underlying collateral
     * @param token App stablecoin token address
     * @param rawAmount Amount of stablecoins to redeem (in raw units)
     */
    function redeam(address token, uint256 rawAmount) external {
        uint256 id = _getStablecoinID(token);
        if (rawAmount == 0)
            revert Error.InvalidAmount();
        uint256 valueAmount = rawAmount / DEFAULT_COIN_SCALE;
        totalSupply -= valueAmount;
        _burnAppToken(id, rawAmount);
        _sendCollateralBasket(valueAmount);
    }

    /**
     * @notice Withdraw collateral directly from the vault
     * @param id App ID
     * @param valueAmount Amount of value units to withdraw. Use `type(uint256).max` to withdraw all available.
     */
    function withdrawCollateral(uint256 id, uint256 valueAmount) external {
        uint256 maxValue = vault[id][msg.sender];
        if (valueAmount == type(uint256).max)
            valueAmount = maxValue;
        vault[id][msg.sender] = maxValue - valueAmount;
        _sendCollateralBasket(valueAmount);
    }

    /// @notice Returns total value of all collateral across apps
    function getTotalPool() external view returns (uint256){
        return totalPool;
    }

    /// @notice Returns total value of a specific collateral token
    function getGlobalPool(address token) external view returns (uint256){
        return globalPool[token];
    }

    /// @notice Returns total supply of stablecoins across apps
    function getTotalSupply() external view returns (uint256){
        return totalSupply;
    }

    /// @notice Returns the vault balance of a user in value units
    function getVaultBalance(uint256 id, address user) external view returns (uint256) {
        return (vault[id][user]);
    }

    /**
     * @notice Internal helper to send pro-rata collateral basket
     * @dev Distributes `valueAmount` proportionally across all supported collateral tokens.
     *      Leaves minimal dust in the pool due to integer division rounding.
     * @param valueAmount Amount in value units to send
     */
    function _sendCollateralBasket(uint256 valueAmount) internal {
        uint256 _totalPool = totalPool;
        uint256 _totalSent;
        uint256 len = globalCollateralSupported.length;

        for (uint256 i = 0; i < len; i++){
            address token = globalCollateralSupported[i];
            uint256 proRataValue = (valueAmount *  globalPool[token]) / _totalPool;
            globalPool[token] -= proRataValue;
            _totalSent += proRataValue;
            uint256 proRataRaw = proRataValue * globalCollateralConfig[token].scale;
            IERC20(token).safeTransfer(msg.sender, proRataRaw);
        }
        totalPool -= _totalSent;
    }

}