// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title CDOToken
 * @notice ERC-20 token representing shares in the CDO liquidity pool
 * @dev Minted when users deposit USDC, burned when they withdraw
 *      Only the CDOPool contract can mint/burn tokens
 */
contract CDOToken is ERC20, Ownable {

    // ============ State Variables ============

    address public pool; // CDOPool contract address

    // ============ Events ============

    event PoolSet(address indexed pool, uint256 timestamp);

    // ============ Errors ============

    error Unauthorized();
    error PoolAlreadySet();

    // ============ Constructor ============

    /**
     * @param name Token name (e.g., "Just-a-Bet CDO")
     * @param symbol Token symbol (e.g., "JAB-CDO")
     */
    constructor(string memory name, string memory symbol) ERC20(name, symbol) Ownable(msg.sender) {
        // Pool will be set after deployment
    }

    // ============ External Functions ============

    /**
     * @notice Set the CDOPool contract address (can only be called once)
     * @param _pool Address of CDOPool contract
     */
    function setPool(address _pool) external onlyOwner {
        if (pool != address(0)) revert PoolAlreadySet();
        require(_pool != address(0), "Invalid pool address");

        pool = _pool;
        emit PoolSet(_pool, block.timestamp);
    }

    /**
     * @notice Mint CDO tokens (only callable by CDOPool)
     * @param to Recipient address
     * @param amount Amount to mint
     */
    function mint(address to, uint256 amount) external {
        if (msg.sender != pool) revert Unauthorized();
        _mint(to, amount);
    }

    /**
     * @notice Burn CDO tokens (only callable by CDOPool)
     * @param from Address to burn from
     * @param amount Amount to burn
     */
    function burn(address from, uint256 amount) external {
        if (msg.sender != pool) revert Unauthorized();
        _burn(from, amount);
    }
}
