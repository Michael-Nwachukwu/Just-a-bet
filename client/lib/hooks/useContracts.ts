import { useChainId } from "wagmi"
import { getContractAddresses } from "../contracts/addresses"
import { ABIS } from "../contracts/abis"

/**
 * Hook to get all contract addresses for the current chain
 */
export function useContractAddresses() {
  const chainId = useChainId()
  return getContractAddresses(chainId)
}

/**
 * Hook to get BetFactory contract config
 */
export function useBetFactoryContract() {
  const addresses = useContractAddresses()
  return {
    address: addresses.betFactory,
    abi: ABIS.BetFactory,
  }
}

/**
 * Hook to get USDC contract config
 */
export function useUSDCContract() {
  const addresses = useContractAddresses()
  return {
    address: addresses.usdc,
    abi: ABIS.ERC20,
  }
}

/**
 * Hook to get CDOPool contract config
 */
export function useCDOPoolContract() {
  const addresses = useContractAddresses()
  return {
    address: addresses.cdoPool,
    abi: ABIS.CDOPool,
  }
}

/**
 * Hook to get UsernameRegistry contract config
 */
export function useUsernameRegistryContract() {
  const addresses = useContractAddresses()
  return {
    address: addresses.usernameRegistry,
    abi: ABIS.UsernameRegistry,
  }
}

/**
 * Hook to get BetRiskValidator contract config
 */
export function useBetRiskValidatorContract() {
  const addresses = useContractAddresses()
  return {
    address: addresses.betRiskValidator,
    abi: ABIS.BetRiskValidator,
  }
}

/**
 * Hook to get Bet contract config for a specific bet address
 */
export function useBetContract(betAddress: `0x${string}`) {
  return {
    address: betAddress,
    abi: ABIS.Bet,
  }
}
