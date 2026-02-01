// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

 /**
 * @dev Roles are stored as bitflags in a uint256 for gas efficiency:
 *      - OWNER = 1 << 0
 *      - COLLATERAL_MANAGER = 1 << 1
 *      - ORACLE_MANAGER = 1 << 2
 *      - GOVERNOR = 1 << 3
 * 
 *      Only the OWNER can grant or revoke roles.
 */

abstract contract AccessManager {
    uint256 constant private OWNER = 1 << 0;
    uint256 constant public COLLATERAL_MANAGER = 1 << 1;
    uint256 constant public ORACLE_MANAGER = 1 << 2;
    uint256 constant public GOVERNOR = 1 << 3;
    
    address immutable private owner;
    address private timelock;

    mapping(address user => uint256 roleBits) internal roles;

    constructor(address _owner, address _timelock) {
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

    function hasRole(address user, uint256 role) external view returns (bool) {
        return roles[user] & role != 0;
    }

    function grantRole(address user, uint256 role) external onlyOwner() {
        roles[user] |= role;
    }

    function revokeRole(address user, uint256 role) external onlyOwner {
        roles[user] &= ~role;
    }
}