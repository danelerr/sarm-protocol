// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockERC20
 * @notice Simple mintable ERC20 token for testing stablecoin pairs in SARM Protocol.
 * @dev Used to simulate USDC, USDT, DAI, etc. in local development and tests.
 */
contract MockERC20 is ERC20 {
    uint8 private immutable _decimals;

    constructor(string memory name, string memory symbol, uint8 decimals_) ERC20(name, symbol) {
        _decimals = decimals_;
    }

    /**
     * @notice Mint tokens to an address (unrestricted for testing).
     * @param to Recipient address.
     * @param amount Amount of tokens to mint.
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    /**
     * @notice Override decimals to allow custom precision.
     */
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
}
