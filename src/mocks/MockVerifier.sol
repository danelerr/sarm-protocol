// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IDataLinkVerifier} from "../interfaces/IDataLinkVerifier.sol";

/**
 * @title MockVerifier
 * @notice Mock implementation of Chainlink DataLink verifier for testing.
 * @dev Allows tests to simulate DataLink report verification without depending on real feeds.
 *      Tests can configure the response data and verify that contracts handle it correctly.
 */
contract MockVerifier is IDataLinkVerifier {
    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice The response data to return from verify().
    bytes public mockResponse;

    /// @notice Whether to revert on the next verify call.
    bool public shouldRevert;

    /// @notice Custom revert message.
    string public revertMessage;

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Set the response data to return from verify().
     * @param _response Encoded data to return (typically abi.encode(int256 rating, uint64 timestamp)).
     */
    function setResponse(bytes memory _response) external {
        mockResponse = _response;
    }

    /**
     * @notice Configure the verifier to revert on next call.
     * @param _shouldRevert Whether to revert.
     * @param _message Revert message.
     */
    function setShouldRevert(bool _shouldRevert, string memory _message) external {
        shouldRevert = _shouldRevert;
        revertMessage = _message;
    }

    /**
     * @notice Mock implementation of DataLink verifier.
     * @dev Returns mockResponse if configured, otherwise reverts if shouldRevert is true.
     * @return The configured mock response data.
     */
    function verify(
        bytes calldata /* payload */,
        bytes calldata /* params */
    ) external view override returns (bytes memory) {
        if (shouldRevert) {
            revert(revertMessage);
        }

        return mockResponse;
    }
}
