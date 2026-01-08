// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/core/BetFactory.sol";

contract InitializeBetFactory is Script {
    function run() external {
        // Load environment variables
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Deployed contract addresses (from deployed-addresses.m)
        address betFactoryAddress = 0x76b27dFb0408Baa19b3F41469b123c5bBfd56047;
        address betYieldVaultAddress = 0x12ccF0F4A22454d53aBdA56a796a08e93E947256;
        address cdoPoolFactoryAddress = 0xBc61e19874B98D2429fABc645635439dBaA0Adde;
        address riskValidatorAddress = 0x4d0884D03f2fA409370D0F97c6AbC4dA4A8F03d6;
        
        vm.startBroadcast(deployerPrivateKey);
        
        BetFactory betFactory = BetFactory(betFactoryAddress);
        
        // console.log("Initializing BetFactory at:", betFactoryAddress);
        
        // // Set YieldVault (CRITICAL - required for bet creation)
        // console.log("Setting YieldVault to:", betYieldVaultAddress);
        // betFactory.setYieldVault(betYieldVaultAddress);
        
        // // Set CDOPoolFactory (for multi-pool house bets)
        // console.log("Setting CDOPoolFactory to:", cdoPoolFactoryAddress);
        // betFactory.setCDOPoolFactory(cdoPoolFactoryAddress);
        
        // Set default pool ID (0 = Sports pool)
        console.log("Setting default pool to 3 (General)");
        betFactory.setDefaultPool(3);
        
        // // Set RiskValidator (for house bet AI validation)
        // console.log("Setting RiskValidator to:", riskValidatorAddress);
        // betFactory.setRiskValidator(riskValidatorAddress);
        
        vm.stopBroadcast();
        
        console.log("\n=== BetFactory Initialized Successfully ===");
        // console.log("YieldVault:", betFactory.yieldVault());
        // console.log("CDOPoolFactory:", address(betFactory.poolFactory()));
        // console.log("RiskValidator:", address(betFactory.riskValidator()));
        // console.log("\nBetFactory is now ready to create bets!");
    }
}
