// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import "../src/core/UsernameRegistry.sol";

/**
 * @title DeployUsernameRegistry
 * @notice Deployment script for UsernameRegistry contract
 * @dev Run with: forge script script/DeployUsernameRegistry.s.sol --rpc-url mantle_testnet --broadcast --verify
 */
contract DeployUsernameRegistry is Script {
    function run() external {
        // Get deployer private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Deploy UsernameRegistry
        UsernameRegistry registry = new UsernameRegistry();

        // Stop broadcasting
        vm.stopBroadcast();

        // Log deployment info
        console.log("==============================================");
        console.log("UsernameRegistry deployed to:", address(registry));
        console.log("Deployer address:", vm.addr(deployerPrivateKey));
        console.log("Network: Mantle Testnet");
        console.log("==============================================");
        console.log("");
        console.log("Next steps:");
        console.log("1. Save the contract address");
        console.log("2. Verify on Mantlescan (if --verify flag was used)");
        console.log("3. Test contract on testnet");
        console.log("");
        console.log("Verify manually with:");
        console.log("forge verify-contract", address(registry), "UsernameRegistry --chain mantle_testnet --watch");
    }
}
