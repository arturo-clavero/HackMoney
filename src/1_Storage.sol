// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
 * @notice Storage of all shared parameters that are not dynamic
 * @dev Inherited by all sub-modules [2]
 */

struct Collateral {
    address     tokenAddress;//0 -> ETH
    address[]   oracleFeeds;
    uint256     LTV;
    uint256     liquidityThreshold;
    uint256     debtCap;
    uint256       mode;
}

abstract contract Storage {

   //constants:
    uint256 constant internal WAD = 1e18;
    address constant internal ETH_TOKEN = address(0);

    //roles: 
    mapping(address user => uint256 roleBits) internal roles;
    uint256 constant private OWNER = 1 << 0;
    uint256 constant public COLLATERAL_MANAGER = 1 << 1;
    uint256 constant public ORACLE_MANAGER = 1 << 2;
    uint256 constant public GOVERNOR = 1 << 3;

    //address:
    address immutable internal owner;
    address private timelock;

    //collateral
    mapping(address token => Collateral) internal collateralData;
    address[] private collateralTokens;//?
    uint256 constant public STABLE = 1 << 0;
    uint256 constant public VOLATILE = 1 << 1;
    uint256 constant public YIELD = 1 << 2;
    uint256 constant private PAUSED = 1 << 3;
    uint256 private immutable i_allowedCollateralModes;

    constructor(address _owner, address _timelock, uint256 pegType) {
        if (pegType == 0) {
            i_allowedCollateralModes |= STABLE;
        }
        else if (pegType == 1){
            i_allowedCollateralModes |= STABLE;
            i_allowedCollateralModes |= YIELD;
        }
        else {
            i_allowedCollateralModes |= STABLE;
            i_allowedCollateralModes |= VOLATILE;
        }
        owner = _owner;
        timelock = _timelock;
        roles[_owner] |= OWNER;
    }

    modifier onlyRole(uint256 role){
        require(roles[msg.sender] & role != 0);
        _;
    }

    modifier onlyOwner(){
        require(msg.sender == owner);
        _;
    }

    modifier onlyTimeLock() {
        require(msg.sender == timelock);
        _;
    }

    function grantRole(address user, uint256 role) external onlyOwner() {
        roles[user] |= role;
    }

    function revokeRole(address user, uint256 role) external onlyOwner {
        roles[user] &= ~role;
    }



    function updateCollateral(Collateral calldata updatedCol) external onlyTimeLock(){
        require(i_allowedCollateralModes & updatedCol.mode != 0);
        collateralData[updatedCol.tokenAddress] = updatedCol;
    }

    function removeCollateral(address tokenAddress) external onlyTimeLock(){
        delete collateralData[tokenAddress];
    }

    function pauseCollateral(address tokenAddress) external onlyTimeLock(){
        collateralData[tokenAddress].mode |= PAUSED;

    }
    function unpauseCollateral(address tokenAddress) external onlyTimeLock(){
        collateralData[tokenAddress].mode &= ~PAUSED;
    }

}