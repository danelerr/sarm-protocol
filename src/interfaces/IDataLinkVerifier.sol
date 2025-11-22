// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title IDataLinkVerifier
 * @notice Interface for Chainlink DataLink verifier proxy.
 * @dev Used to verify signed reports from Chainlink's DataLink (DON) before updating on-chain state.
 *      The verifier checks the signature against the Decentralized Oracle Network (DON) public keys.
 *
 * DataLink Flow:
 * 1. Off-chain script fetches report from DataLink pull endpoint (HTTP)
 * 2. Report contains signed data from Chainlink DON
 * 3. Contract calls verify() to validate signature and decode data
 * 4. If valid, data is used to update on-chain state
 *
 * Reference: https://docs.chain.link/data-feeds/datalink
 */
interface IDataLinkVerifier {
    /**
     * @notice Verifies a DataLink report signature and returns the decoded payload.
     * @dev The verifier checks that the report was signed by the Chainlink DON and hasn't been tampered with.
     * @param payload The signed report from DataLink (binary blob).
     * @param params Additional verification parameters (typically includes expected feedId).
     * @return Decoded and verified data from the report.
     */
    function verify(
        bytes calldata payload,
        bytes calldata params
    ) external view returns (bytes memory);
}
