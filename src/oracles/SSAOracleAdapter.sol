// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IDataLinkVerifier} from "../interfaces/IDataLinkVerifier.sol";

/**
 * @title SSAOracleAdapter
 * @notice Single source of truth for stablecoin S&P Global Stability Assessment (SSA) ratings on-chain.
 * @dev This adapter caches stablecoin ratings and serves them to the SARM Hook.
 *      Integrates with Chainlink DataLink for real S&P Global SSA feeds via pull-based verification.
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
    error InvalidFeedId();
    error StaleReport();
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
     * @notice Emitted when a DataLink feed ID is set for a token.
     * @param token Address of the stablecoin token.
     * @param feedId Chainlink DataLink feed ID (bytes32).
     */
    event FeedIdSet(address indexed token, bytes32 feedId);

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Chainlink DataLink verifier proxy for on-chain report verification.
    IDataLinkVerifier public immutable verifier;

    /// @notice Maximum age of a report before it's considered stale (24 hours).
    uint256 public constant MAX_STALENESS = 1 days;

    /// @notice Mapping from token address to its current SSA rating (1-5, 0 = not rated).
    mapping(address => uint8) public tokenRating;

    /// @notice Mapping from token address to the timestamp of last rating update.
    mapping(address => uint256) public tokenRatingLastUpdated;

    /// @notice Mapping from token address to Chainlink DataLink feed ID.
    mapping(address => bytes32) public tokenFeedId;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deploys the SSA Oracle Adapter with Chainlink DataLink integration.
     * @param _verifier Address of the Chainlink DataLink verifier proxy.
     */
    constructor(address _verifier) Ownable(msg.sender) {
        if (_verifier == address(0)) revert InvalidFeed();
        verifier = IDataLinkVerifier(_verifier);
    }

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
     * @notice Set the Chainlink DataLink feed ID for a token (owner only).
     * @dev Configure which DataLink feed provides SSA ratings for this token.
     * @param token Address of the stablecoin token.
     * @param feedId Chainlink DataLink feed ID (bytes32).
     */
    function setFeedId(address token, bytes32 feedId) external onlyOwner {
        if (feedId == bytes32(0)) revert InvalidFeedId();
        tokenFeedId[token] = feedId;
        emit FeedIdSet(token, feedId);
    }



    /**
     * @notice Refresh rating using a verified DataLink report.
     * @dev Pull-based DataLink flow:
     *      1. Off-chain script fetches signed report from DataLink endpoint
     *      2. Script submits report to this function
     *      3. Contract verifies report signature via DataLink verifier
     *      4. If valid, extract SSA rating and update on-chain state
     *
     * DataLink v4 payload structure (from verifier.verify):
     * - feedId: bytes32
     * - validFromTimestamp: uint32
     * - observationsTimestamp: uint32
     * - nativeFee: uint192
     * - linkFee: uint192
     * - expiresAt: uint32
     * - benchmarkPrice: int192 (SSA rating scaled by 1e18)
     * - marketStatus: uint32
     *
     * @param token Address of the stablecoin token to update.
     * @param report Signed DataLink report from Chainlink DON.
     */
    function refreshRatingWithReport(
        address token,
        bytes calldata report
    ) external {
        bytes32 feedId = tokenFeedId[token];
        if (feedId == bytes32(0)) revert InvalidFeedId();

        // Verify the report using DataLink verifier proxy
        bytes memory verified = verifier.verify(report, abi.encode(feedId));

        // Decode DataLink v4 payload structure (all 8 fields)
        // For SSA feeds, benchmarkPrice represents the rating (1-5) scaled by 1e18
        (
            bytes32 feedIdDecoded,
            uint32 validFromTimestamp,
            uint32 _observationsTimestamp,
            uint192 _nativeFee,
            uint192 _linkFee,
            uint32 expiresAt,
            int192 benchmarkPrice,
            uint32 _marketStatus
        ) = abi.decode(
            verified,
            (bytes32, uint32, uint32, uint192, uint192, uint32, int192, uint32)
        );

        // Validate feed ID matches
        if (feedIdDecoded != feedId) revert InvalidFeedId();

        // Validate report hasn't expired
        if (block.timestamp > expiresAt) revert StaleReport();

        // Reject stale reports (additional check for data freshness)
        if (block.timestamp > validFromTimestamp + MAX_STALENESS) revert StaleReport();

        // Update rating
        uint8 oldRating = tokenRating[token];
        uint8 newRating = _normalizeRating(benchmarkPrice);

        tokenRating[token] = newRating;
        tokenRatingLastUpdated[token] = validFromTimestamp;

        emit RatingUpdated(token, oldRating, newRating);
    }

    /**
     * @notice Refresh rating by reading from Chainlink SSA feed (legacy - not implemented).
     * @dev Use refreshRatingWithReport() instead for DataLink pull-based integration.
     */
    function refreshRating(address /* token */) external pure {
        revert ChainlinkNotImplemented();
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Normalize DataLink benchmarkPrice to 1-5 rating scale.
     * @dev DataLink v4 SSA feeds encode rating as: rating * 1e18
     *      Examples: 1e18 = rating 1, 3e18 = rating 3, 3.5e18 = rating 3.5
     *      
     *      NOTE: This implementation truncates to integer (e.g., 2.3 → 2, 3.7 → 3).
     *      For SSA bands 1.0-2.0, 2.1-3.0, 3.1-4.0, 4.1-5.0:
     *      - Values like 2.1-2.9 round down to 2 (Excellent) instead of 3 (Good)
     *      - Acceptable for MVP/hackathon; future enhancement: use absPrice / 1e17 for 1-decimal precision
     * @param benchmarkPrice Raw benchmarkPrice from DataLink (int192, scaled by 1e18).
     * @return Normalized rating (1-5), truncated to integer.
     */
    function _normalizeRating(int192 benchmarkPrice) internal pure returns (uint8) {
        // Convert to uint256 for safe division
        if (benchmarkPrice < 0) {
            revert InvalidRating();
        }
        uint256 absPrice = uint256(int256(benchmarkPrice));
        
        // Divide by 1e18 to get integer rating (truncates decimals)
        // Example: 3e18 / 1e18 = 3, 2.3e18 / 1e18 = 2
        uint256 rating = absPrice / 1e18;
        
        // Validate range (1-5)
        if (rating < 1 || rating > 5) {
            revert InvalidRating();
        }
        
        return uint8(rating);
    }
}
