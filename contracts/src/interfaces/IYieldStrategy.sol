// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IYieldStrategy
 * @notice Interface for yield generation strategies
 * @dev Allows pluggable yield strategies (mock for testnet, real protocols for mainnet)
 */
interface IYieldStrategy {
    /**
     * @notice Deposit assets into the yield strategy
     * @param amount Amount of assets to deposit
     * @return shares Amount of shares/tokens received
     */
    function deposit(uint256 amount) external returns (uint256 shares);

    /**
     * @notice Withdraw assets from the yield strategy
     * @param shares Amount of shares to redeem
     * @return amount Amount of assets received (principal + yield)
     */
    function withdraw(uint256 shares) external returns (uint256 amount);

    /**
     * @notice Calculate current yield earned for a depositor
     * @param depositor Address of the depositor
     * @return yield Amount of yield earned (not including principal)
     */
    function calculateYield(address depositor) external view returns (uint256 yield);

    /**
     * @notice Get total assets under management in the strategy
     * @return totalAssets Total assets in the strategy
     */
    function totalAssets() external view returns (uint256 totalAssets);

    /**
     * @notice Get depositor's balance (shares)
     * @param depositor Address to query
     * @return balance Depositor's share balance
     */
    function balanceOf(address depositor) external view returns (uint256 balance);
}
