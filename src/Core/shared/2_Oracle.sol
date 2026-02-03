// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {CollateralManager} from "./CollateralManager.sol";
import {IAggregatorV3} from "../../interfaces/IAggregatorV3.sol";

/**
 * @title Oracle
 * @notice Price feed management with safety checks
 * @dev Wraps Chainlink aggregators with staleness and validity checks.
 *      Uses the oracleFeeds array from CollateralManager for feed addresses.
 */
abstract contract Oracle is CollateralManager {
    // ═══════════════════════════════════════════════════════════════════════
    //                              CONSTANTS
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Maximum age of price data before considered stale
    uint256 public constant STALENESS_THRESHOLD = 24 hours;

    /// @notice Standard decimals for price output (Chainlink USD feeds use 8)
    uint8 public constant PRICE_DECIMALS = 8;

    // ═══════════════════════════════════════════════════════════════════════
    //                              ERRORS
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Thrown when no oracle feed is configured for a token
    error Oracle__NoFeedConfigured(address token);

    /// @notice Thrown when price data is stale
    error Oracle__StalePrice(address feed, uint256 updatedAt, uint256 threshold);

    /// @notice Thrown when price is zero or negative
    error Oracle__InvalidPrice(address feed, int256 price);

    /// @notice Thrown when round data is incomplete
    error Oracle__IncompleteRound(address feed, uint80 roundId, uint80 answeredInRound);

    // ═══════════════════════════════════════════════════════════════════════
    //                           EXTERNAL FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * @notice Get the USD price of a collateral token
     * @param token The collateral token address
     * @return price The price with 8 decimals (1e8 = $1.00)
     * @dev Reverts if price is stale or invalid
     */
    function getPrice(address token) public view returns (uint256 price) {
        address feed = _getFeed(token);
        price = _fetchPrice(feed);
    }

    /**
     * @notice Get price with explicit safety status (non-reverting)
     * @param token The collateral token address
     * @return price The price (0 if unsafe)
     * @return isSafe Whether all safety checks passed
     */
    function getPriceWithStatus(address token)
        public
        view
        returns (uint256 price, bool isSafe)
    {
        address feed = _getPrimaryFeed(token);
        if (feed == address(0)) {
            return (0, false);
        }

        try IAggregatorV3(feed).latestRoundData() returns (
            uint80 roundId,
            int256 answer,
            uint256,
            uint256 updatedAt,
            uint80 answeredInRound
        ) {
            // Check all safety conditions
            if (answer <= 0) return (0, false);
            if (updatedAt == 0) return (0, false);
            if (block.timestamp - updatedAt > STALENESS_THRESHOLD) return (0, false);
            if (answeredInRound < roundId) return (0, false);

            return (uint256(answer), true);
        } catch {
            return (0, false);
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                           INTERNAL FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * @dev Get the primary oracle feed for a token
     * @param token The collateral token address
     * @return feed The Chainlink aggregator address
     */
    function _getPrimaryFeed(address token) internal view returns (address feed) {
        address[] storage feeds = collateralConfig[token].oracleFeeds;
        if (feeds.length == 0) {
            return address(0);
        }
        return feeds[0];
    }

    /**
     * @dev Get the primary feed, reverting if none configured
     */
    function _getFeed(address token) internal view returns (address feed) {
        feed = _getPrimaryFeed(token);
        if (feed == address(0)) {
            revert Oracle__NoFeedConfigured(token);
        }
    }

    /**
     * @dev Fetch and validate price from a Chainlink feed
     * @param feed The Chainlink aggregator address
     * @return price The validated price
     */
    function _fetchPrice(address feed) internal view returns (uint256 price) {
        (
            uint80 roundId,
            int256 answer,
            ,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = IAggregatorV3(feed).latestRoundData();

        // Safety check 1: Price must be positive
        if (answer <= 0) {
            revert Oracle__InvalidPrice(feed, answer);
        }

        // Safety check 2: Data must be fresh
        if (block.timestamp - updatedAt > STALENESS_THRESHOLD) {
            revert Oracle__StalePrice(feed, updatedAt, STALENESS_THRESHOLD);
        }

        // Safety check 3: Round must be complete
        if (answeredInRound < roundId) {
            revert Oracle__IncompleteRound(feed, roundId, answeredInRound);
        }

        // Safe: answer > 0 verified above
        price = uint256(answer);
    }
}
