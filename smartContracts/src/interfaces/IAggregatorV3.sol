// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @title IAggregatorV3
 * @notice Chainlink's standard price feed interface
 * @dev See https://docs.chain.link/data-feeds/api-reference
 */
interface IAggregatorV3 {
    /**
     * @notice Returns the latest price data
     * @return roundId The round ID (increments each update)
     * @return answer The price (scaled by decimals())
     * @return startedAt Timestamp when round started
     * @return updatedAt Timestamp when price was updated
     * @return answeredInRound The round in which answer was computed
     */
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );

    /**
     * @notice Returns the number of decimals in the price
     * @dev Chainlink USD feeds typically use 8 decimals
     */
    function decimals() external view returns (uint8);

    /**
     * @notice Returns a description of the feed (e.g., "ETH / USD")
     */
    function description() external view returns (string memory);
}
