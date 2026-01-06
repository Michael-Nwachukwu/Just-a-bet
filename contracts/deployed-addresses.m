UsernameRegistry - 0x2C0457F82B57148e8363b4589bb3294b23AE7625
MockUSDC - 0xA1103E6490ab174036392EbF5c798C9DaBAb24EE
MockYieldStrategy - 0xE9b224bE25B2823250f4545709A11e8ebAC18b34
BetYieldVault - 0x12ccF0F4A22454d53aBdA56a796a08e93E947256
BetRiskValidator - 0x4d0884D03f2fA409370D0F97c6AbC4dA4A8F03d6

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





forge verify-contract --verifier-url https://api-sepolia.mantlescan.xyz/api --etherscan-api-key $MANTLESCAN_API_KEY --compiler-version "0.8.24" 0xE9b224bE25B2823250f4545709A11e8ebAC18b34 src/strategies/MockYieldStrategy.sol:MockYieldStrategy --constructor-args 0xA1103E6490ab174036392EbF5c798C9DaBAb24EE --watch



forge verify-contract --verifier-url https://api-sepolia.mantlescan.xyz/api --etherscan-api-key $MANTLESCAN_API_KEY 0xE9b224bE25B2823250f4545709A11e8ebAC18b34 src/strategies/MockYieldStrategy.sol:MockYieldStrategy --watch
