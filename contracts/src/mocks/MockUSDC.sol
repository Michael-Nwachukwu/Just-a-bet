// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MockUSDC
 * @notice Mock USDC token for Mantle Testnet
 * @dev Allows anyone to mint tokens for testing
 */
contract MockUSDC is ERC20, Ownable {
    uint8 private _decimals = 6; // USDC uses 6 decimals

    constructor() ERC20("Mock USD Coin", "USDC") Ownable(msg.sender) {
        // Mint initial supply to deployer for distribution
        _mint(msg.sender, 1_000_000 * 10**6); // 1 million USDC
    }

    /**
     * @notice Get token decimals
     * @return decimals Token decimals (6 for USDC)
     */
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    /**
     * @notice Mint tokens (anyone can mint on testnet)
     * @param to Recipient address
     * @param amount Amount to mint (in USDC units, 6 decimals)
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    /**
     * @notice Faucet function - get 1000 USDC for testing
     */
    function faucet() external {
        _mint(msg.sender, 1000 * 10**6); // 1000 USDC
    }
}
