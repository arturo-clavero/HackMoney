// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Error} from "./utils/ErrorLib.sol";

interface IProtocolRoles {
    function hasRole(uint256 role, address account) external view returns (bool);
    function isOwner(address account) external view returns (bool);
}

struct CallConfig {
    uint256 role;
    uint256 delay;
    uint256 gracePeriod;
}
contract Timelock {

    address public timelockOwner;

    mapping(bytes32 txHash => bool isQueued) public queuedTx;
    mapping(bytes4 selector => CallConfig) public selectorConfig;

    event Queued(bytes32 indexed txHash, bytes4 indexed selector, address target, bytes data, uint256 deadline);
    event Cancelled(bytes32 indexed txHash);

    modifier onlyTimelockOwner() {
        if (msg.sender != timelockOwner) 
            revert Error.InvalidAccess();
        _;
    }

    constructor() {
        timelockOwner = msg.sender;
    }

    function setTimelockOwner(address newOwner) external onlyTimelockOwner {
        timelockOwner = newOwner;
    }

    function setSelector(bytes4 _selector, CallConfig calldata config) external onlyTimelockOwner {
        if (config.role == 0 || config.gracePeriod == 0 || config.delay == 0)
            revert Error.InvalidAmount();
        selectorConfig[_selector] = config;
    }

    function queue(address target, bytes calldata data) external returns (bytes32 txHash) {
        if (target == address(0))
            revert Error.InvalidTarget();

        bytes4 selector = bytes4(data[:4]);
        uint256 role = selectorConfig[selector].role;
        uint256 delay = selectorConfig[selector].delay;
        if (role == 0 || delay == 0)
            revert Error.InvalidSelector();

        if (!IProtocolRoles(target).hasRole(role, msg.sender)) 
            revert Error.InvalidAccess();

        uint256 deadline = block.timestamp + delay;
        txHash = keccak256(abi.encode(target, data, deadline));

        queuedTx[txHash] = true;

        emit Queued(txHash, selector, target, data, deadline);
    }

    function cancel(address target, bytes calldata data, uint256 deadline) external {
        if (!IProtocolRoles(target).isOwner(msg.sender)) 
            revert Error.InvalidAccess();

        bytes32 txHash = keccak256(abi.encode(target, data, deadline));

        if (!queuedTx[txHash]) 
            revert Error.TxNotQueued();

        delete queuedTx[txHash];

        emit Cancelled(txHash);
    }

    function execute(address target, bytes calldata data, uint256 deadline) external {
        bytes32 txHash = keccak256(abi.encode(target, data, deadline));

        if (!queuedTx[txHash]) 
            revert Error.TxNotQueued();

        bytes4 selector = bytes4(data[:4]);
        uint256 gracePeriod = selectorConfig[selector].gracePeriod;

        if (block.timestamp < deadline) 
            revert Error.TxStillLocked();
        if (block.timestamp > deadline + gracePeriod) 
            revert Error.TxExpired();

        delete queuedTx[txHash];
        (bool ok, ) = target.call(data);
        if (!ok)
            revert Error.TxFailed();
    }
}