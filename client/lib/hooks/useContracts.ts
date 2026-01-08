import { getContract } from "thirdweb"
import { client, mantleSepolia } from "@/lib/thirdweb"
import { getContractAddresses } from "../contracts/addresses"
import { ABIS } from "../contracts/abis"

/**
 * Hook to get all contract addresses for Mantle Sepolia
 */
export function useContractAddresses() {
  return getContractAddresses(5003) // Always use Mantle Sepolia
}

/**
 * Hook to get BetFactory contract
 */
export function useBetFactoryContract() {
  const addresses = useContractAddresses()
  return getContract({
    client,
    chain: mantleSepolia,
    address: addresses.betFactory,
    abi: ABIS.BetFactory as any, 
  })
}

/**
 * Hook to get USDC contract
 */
export function useUSDCContract() {
  const addresses = useContractAddresses()
  return getContract({
    client,
    chain: mantleSepolia,
    address: addresses.usdc,
    abi: ABIS.ERC20 as any,
  })
}

/**
 * Hook to get CDOPool contract
 */
export function useCDOPoolContract() {
  const addresses = useContractAddresses()
  return getContract({
    client,
    chain: mantleSepolia,
    address: addresses.cdoPool,
    abi: ABIS.CDOPool as any,
  })
}

/**
 * Hook to get UsernameRegistry contract
 */
export function useUsernameRegistryContract() {
  const addresses = useContractAddresses()
  return getContract({
    client,
    chain: mantleSepolia,
    address: addresses.usernameRegistry,
    abi: ABIS.UsernameRegistry as any,
  })
}

/**
 * Hook to get BetRiskValidator contract
 */
export function useBetRiskValidatorContract() {
  const addresses = useContractAddresses()
  return getContract({
    client,
    chain: mantleSepolia,
    address: addresses.betRiskValidator,
    abi: ABIS.BetRiskValidator as any,
  })
}

/**
 * Hook to get Bet contract for a specific bet address
 */
export function useBetContract(betAddress: string) {
  return getContract({
    client,
    chain: mantleSepolia,
    address: betAddress,
    abi: ABIS.Bet as any,
  })
}

/**
 * Hook to get JudgeRegistry contract
 */
export function useJudgeRegistryContract() {
  const addresses = useContractAddresses()
  return getContract({
    client,
    chain: mantleSepolia,
    address: addresses.judgeRegistry,
    abi: ABIS.JudgeRegistry as any,
  })
}
