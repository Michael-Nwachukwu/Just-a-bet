UsernameRegistry - 0x2C0457F82B57148e8363b4589bb3294b23AE7625
MockUSDC - 0xA1103E6490ab174036392EbF5c798C9DaBAb24EE
MockYieldStrategy - 0xE9b224bE25B2823250f4545709A11e8ebAC18b34
BetYieldVault - 0x12ccF0F4A22454d53aBdA56a796a08e93E947256
BetRiskValidator - 0x4d0884D03f2fA409370D0F97c6AbC4dA4A8F03d6
JudgeRegistry - 0x9f3eB17a20a4E57Ed126F34061b0E40dF3a4f5C2
DisputeManager - 0x3335BaEEDdD1Cc77B8Ab9acBF862764812337a3F
CDOPoolFactory - 0xc616918154D7a9dB5D78480d1d53820d4423b298
BetFactory - 0x07ecE77248D4E3f295fdFaeC1C86e257098A434a




Creating category-specific pools...
     Creating Sports Pool - NBA...
       Pool ID: 0
       Pool Address: 0x2b2E21596A22f6Ab273E41F4BB28Dcc1D0be6D85
       Token Address: 0xDb02a4D36c750FE94986ac4E9B736EA31ac9B32e
     Creating Crypto Pool - BTC...
       Pool ID: 1
       Pool Address: 0xd0B0aF8488D7000c6658a0E7A50566dAa6B6E631
       Token Address: 0xEb3aE9248B253e4dEbfd2A1A822cCB129D618bF5
     Creating Politics Pool...
       Pool ID: 2
       Pool Address: 0xb8886E5638d17Fe6161976FD4Ca27d2DaAC9029f
       Token Address: 0xA8586243CBf327B4c8Fd061B2a1F2B0CCD495297
     Creating General Pool...
       Pool ID: 3
       Pool Address: 0x8Ea7a72e5deF4323e6DF86c668F88e4aBc5E2f92
       Token Address: 0x330cF1F85e0c97A5FA06BF49Eaf24947beE1a799




       

forge create --rpc-url https://rpc.sepolia.mantle.xyz \
  --private-key $PRIVATE_KEY \
  src/strategies/MockYieldStrategy.sol:MockYieldStrategy \
  --broadcast                                        
  --legacy



forge create --rpc-url https://rpc.sepolia.mantle.xyz \
  --private-key $PRIVATE_KEY \
  src/strategies/MockYieldStrategy.sol:MockYieldStrategy \
  --broadcast \
  --constructor-args 0xA1103E6490ab174036392EbF5c798C9DaBAb24EE \
  --legacy


forge create --rpc-url https://rpc.sepolia.mantle.xyz \
  --private-key $PRIVATE_KEY \
  src/core/BetYieldVault.sol:BetYieldVault \
  --broadcast \
  --constructor-args 0xA1103E6490ab174036392EbF5c798C9DaBAb24EE 0x7FBbE68068A3Aa7E479A1E51e792F4C2073b018f 0xE9b224bE25B2823250f4545709A11e8ebAC18b34 \
  --legacy


forge create --rpc-url https://rpc.sepolia.mantle.xyz \
  --private-key $PRIVATE_KEY \
  src/liquidity/BetRiskValidator.sol:BetRiskValidator \
  --broadcast \
  --legacy



forge create --rpc-url https://rpc.sepolia.mantle.xyz \
  --private-key $PRIVATE_KEY \
  src/judges/JudgeRegistry.sol:JudgeRegistry \
  --broadcast \
  --legacy



forge create --rpc-url https://rpc.sepolia.mantle.xyz \
  --private-key $PRIVATE_KEY \
  src/judges/DisputeManager.sol:DisputeManager \
  --broadcast \
  --constructor-args 0x9f3eB17a20a4E57Ed126F34061b0E40dF3a4f5C2 \
  --legacy




forge create --rpc-url https://rpc.sepolia.mantle.xyz \
  --private-key $PRIVATE_KEY \
  src/liquidity/CDOPoolFactory.sol:CDOPoolFactory \
  --broadcast \
  --constructor-args 0xA1103E6490ab174036392EbF5c798C9DaBAb24EE 0x12ccF0F4A22454d53aBdA56a796a08e93E947256 0x4d0884D03f2fA409370D0F97c6AbC4dA4A8F03d6 \
  --legacy


forge create --rpc-url https://rpc.sepolia.mantle.xyz \
  --private-key $PRIVATE_KEY \
  src/core/BetFactory.sol:BetFactory \
  --broadcast \
  --constructor-args 0xA1103E6490ab174036392EbF5c798C9DaBAb24EE 0x2C0457F82B57148e8363b4589bb3294b23AE7625 \
  --legacy



forge verify-contract --verifier-url https://api-sepolia.mantlescan.xyz/api --etherscan-api-key $MANTLESCAN_API_KEY --compiler-version "0.8.24" 0xE9b224bE25B2823250f4545709A11e8ebAC18b34 src/strategies/MockYieldStrategy.sol:MockYieldStrategy --constructor-args 0xA1103E6490ab174036392EbF5c798C9DaBAb24EE --watch



forge verify-contract --verifier-url https://api-sepolia.mantlescan.xyz/api --etherscan-api-key $MANTLESCAN_API_KEY 0xE9b224bE25B2823250f4545709A11e8ebAC18b34 src/strategies/MockYieldStrategy.sol:MockYieldStrategy --watch
