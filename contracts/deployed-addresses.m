UsernameRegistry - 0x2C0457F82B57148e8363b4589bb3294b23AE7625
MockUSDC - 0xA1103E6490ab174036392EbF5c798C9DaBAb24EE
MockYieldStrategy - 0xE9b224bE25B2823250f4545709A11e8ebAC18b34
BetYieldVault - 0x12ccF0F4A22454d53aBdA56a796a08e93E947256
BetRiskValidator - 0x4d0884D03f2fA409370D0F97c6AbC4dA4A8F03d6
JudgeRegistry - 0x9f3eB17a20a4E57Ed126F34061b0E40dF3a4f5C2
DisputeManager - 0x3335BaEEDdD1Cc77B8Ab9acBF862764812337a3F
CDOPoolFactory - 0xBc61e19874B98D2429fABc645635439dBaA0Adde
BetFactory - 0x76b27dFb0408Baa19b3F41469b123c5bBfd56047




Creating category-specific pools...
     Creating Sports Pool - NBA...
       Pool ID: 0
       Pool Address: 0x1E8d4BF45aB7EF0B7e4a7d46da2290fEa761F973
       Token Address: 0xd34F2B8a2cd3f2B4b401c2EB612676277774A42B
     Creating Crypto Pool - BTC...
       Pool ID: 1
       Pool Address: 0x6651aE6442b6CF752f30860cf8725b24b086295f
       Token Address: 0x85Aa34014C68eE61Fe838e30f685A13339fAEeFd
     Creating Politics Pool...
       Pool ID: 2
       Pool Address: 0x6a6b4bF68F3C87532cF216407d23FeC5a620398E
       Token Address: 0x20403443a5b093523439ca6feF4ccF123B9360B9
     Creating General Pool...
       Pool ID: 3
       Pool Address: 0xE5a49B55996624a4521a6325a7Df080074f32D22
       Token Address: 0xd3e78BF26C938B21e361b8073C147be71b53a436




       

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
