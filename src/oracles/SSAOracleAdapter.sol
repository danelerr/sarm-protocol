// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title SSAOracleAdapter
 * @notice Single source of truth for stablecoin S&P Global Stability Assessment (SSA) ratings on-chain.
 * @dev This adapter caches stablecoin ratings and serves them to the SARM Hook.
 *      Phase 1: Manual rating setter for development/testing.
 *      Phase 2+: Integration with Chainlink DataLink for real S&P Global SSA feeds.
 *
 * Rating Scale:
 *   1 = Minimal risk (well-collateralized, audited stablecoins)
 *   2 = Low risk
 *   3 = Medium risk
 *   4 = Elevated risk (circuit breaker threshold)
 *   5 = High risk (full freeze)
 *
 * Part of SARM Protocol for ETHGlobal Buenos Aires 2025.
 */
contract SSAOracleAdapter is Ownable {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidRating();
    error TokenNotRated();
    error InvalidFeed();
    error ChainlinkNotImplemented();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Emitted when a token's rating is updated.
     * @param token Address of the stablecoin token.
     * @param oldRating Previous rating (0 if first time rating).
     * @param newRating New rating value (1-5).
     */
    event RatingUpdated(address indexed token, uint8 oldRating, uint8 newRating);

    /**
     * @notice Emitted when a Chainlink feed address is set for a token.
     * @param token Address of the stablecoin token.
     * @param feed Address of the Chainlink SSA feed (Phase 2+).
     */
    event FeedSet(address indexed token, address feed);

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Mapping from token address to its current SSA rating (1-5, 0 = not rated).
    mapping(address => uint8) public tokenRating;

    /// @notice Mapping from token address to the timestamp of last rating update.
    mapping(address => uint256) public tokenRatingLastUpdated;

    /// @notice Mapping from token address to Chainlink SSA feed address (Phase 2+).
    mapping(address => address) public tokenToFeed;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() Ownable(msg.sender) {}

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get the current rating for a token.
     * @param token Address of the stablecoin token.
     * @return rating Current SSA rating (1-5).
     * @return lastUpdated Timestamp of last update.
     */
    function getRating(address token) external view returns (uint8 rating, uint256 lastUpdated) {
        rating = tokenRating[token];
        lastUpdated = tokenRatingLastUpdated[token];
        
        if (rating == 0) {
            revert TokenNotRated();
        }
    }

    /**
     * @notice Manually set the rating for a token (owner only).
     * @dev Used for development, testing, and live demo simulations.
     *      In production, this would be restricted or removed in favor of Chainlink feeds.
     * @param token Address of the stablecoin token.
     * @param rating New rating value (1-5).
     */
    function setRatingManual(address token, uint8 rating) external onlyOwner {
        if (rating < 1 || rating > 5) {
            revert InvalidRating();
        }

        uint8 oldRating = tokenRating[token];
        tokenRating[token] = rating;
        tokenRatingLastUpdated[token] = block.timestamp;

        emit RatingUpdated(token, oldRating, rating);
    }

    /**
     * @notice Set the Chainlink SSA feed address for a token (owner only).
     * @dev Phase 2+: Wire up actual Chainlink DataLink feeds.
     * @param token Address of the stablecoin token.
     * @param feed Address of the Chainlink SSA feed contract.
     */
    function setFeed(address token, address feed) external onlyOwner {
        if (feed == address(0)) revert InvalidFeed();
        tokenToFeed[token] = feed;
        emit FeedSet(token, feed);
    }

    /**
     * @notice Refresh rating by reading from Chainlink SSA feed (Phase 2+).
     * @dev TODO: Implement Chainlink feed interface and rating normalization.
     */
    function refreshRating(address /* token */) external pure {
        // Phase 2+: Read from Chainlink SSA feed
        // address feed = tokenToFeed[token];
        // require(feed != address(0), "Feed not set");
        // 
        // (uint80 roundId, int256 answer, , uint256 updatedAt, ) = AggregatorV3Interface(feed).latestRoundData();
        // 
        // // Normalize SSA rating to 1-5 scale
        // uint8 newRating = _normalizeRating(answer);
        // 
        // uint8 oldRating = tokenRating[token];
        // tokenRating[token] = newRating;
        // tokenRatingLastUpdated[token] = updatedAt;
        // 
        // emit RatingUpdated(token, oldRating, newRating);

        revert ChainlinkNotImplemented();
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Normalize Chainlink SSA feed value to 1-5 rating scale.
     * @param feedValue Raw value from Chainlink SSA feed.
     * @return Normalized rating (1-5).
     */
    function _normalizeRating(int256 feedValue) internal pure returns (uint8) {
        // Phase 2+: Implement actual normalization logic based on SSA feed format
        // Example: SSA might return 1-5 directly, or need conversion
        if (feedValue <= 0 || feedValue > 5) {
            revert InvalidRating();
        }
        return uint8(uint256(feedValue));
    }
}
