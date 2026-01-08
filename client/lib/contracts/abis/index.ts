import BetFactoryABI from "./BetFactory.json"
import BetABI from "./Bet.json"
import CDOPoolABI from "./CDOPool.json"
import UsernameRegistryABI from "./UsernameRegistry.json"
import BetRiskValidatorABI from "./BetRiskValidator.json"
import JudgeRegistryABI from "./JudgeRegistry.json"
import ERC20ABI from "./ERC20.json"

export {
  BetFactoryABI,
  BetABI,
  CDOPoolABI,
  UsernameRegistryABI,
  BetRiskValidatorABI,
  JudgeRegistryABI,
  ERC20ABI,
}

// Type-safe ABI exports
export const ABIS = {
  BetFactory: BetFactoryABI,
  Bet: BetABI,
  CDOPool: CDOPoolABI,
  UsernameRegistry: UsernameRegistryABI,
  BetRiskValidator: BetRiskValidatorABI,
  JudgeRegistry: JudgeRegistryABI,
  ERC20: ERC20ABI,
} as const
