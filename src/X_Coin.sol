// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/token/ERC20/ERC20.sol"; 

/**
 * @notice ERC20 token controlled by a central engine contract.
 *          One token deployed per new App Instance.
 * @dev Minting and burning are restricted to the engine, and approvals
 *      are disabled to limit how the token can be used.
 */
contract Coin is ERC20 {

    address private _engine;

    constructor (
        address engine,
        string memory name,
        string memory symbol
    ) ERC20(name, symbol) {
        _engine = engine;
    }

    modifier onlyEngine(){
        require(msg.sender == _engine);
        _;
    }

    function mint(address account, uint256 value) onlyEngine() external {
        _mint(account, value);
    }

    function burn(address account, uint256 value) onlyEngine() external {
        _burn(account, value);
    }

    function approve(address, uint256) public override returns (bool) {
        revert("Approvals disabled");
    }

    function transfer(address, uint256) public override returns (bool) {
        revert("Transfers disabled");
    }

    function transferFrom(address from, address to, uint256 value) public override onlyEngine() returns (bool) {
        _transfer(from, to, value);
        return true;
    }

}