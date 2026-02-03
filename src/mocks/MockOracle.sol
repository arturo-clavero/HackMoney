// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IAggregatorV3} from "../interfaces/IAggregatorV3.sol";

/**
 * @title MockAggregator
 * @notice Mock Chainlink price feed for testing
 * @dev Allows setting arbitrary price data to test Oracle safety checks
 */
contract MockAggregator is IAggregatorV3 {
    int256 private _answer;
    uint256 private _updatedAt;
    uint80 private _roundId;
    uint80 private _answeredInRound;
    uint8 private _decimals;
    string private _description;

    constructor(string memory desc, uint8 dec) {
        _description = desc;
        _decimals = dec;
        _roundId = 1;
        _answeredInRound = 1;
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                           TEST HELPERS
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Set the price (with 8 decimals: 1e8 = $1.00)
    function setPrice(int256 price) external {
        _answer = price;
        _updatedAt = block.timestamp;
        _roundId++;
        _answeredInRound = _roundId;
    }

    /// @notice Set price with custom timestamp (for testing staleness)
    function setPriceWithTimestamp(int256 price, uint256 timestamp) external {
        _answer = price;
        _updatedAt = timestamp;
        _roundId++;
        _answeredInRound = _roundId;
    }

    /// @notice Simulate an incomplete round
    function setIncompleteRound(int256 price) external {
        _answer = price;
        _updatedAt = block.timestamp;
        _roundId++;
        _answeredInRound = _roundId - 1; // Previous round - incomplete!
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                      CHAINLINK INTERFACE
    // ═══════════════════════════════════════════════════════════════════════

    function latestRoundData()
        external
        view
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (_roundId, _answer, _updatedAt, _updatedAt, _answeredInRound);
    }

    function decimals() external view override returns (uint8) {
        return _decimals;
    }

    function description() external view override returns (string memory) {
        return _description;
    }
}
