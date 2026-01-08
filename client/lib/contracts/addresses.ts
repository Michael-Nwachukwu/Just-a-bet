import { Address } from "viem"

export type ContractAddresses = {
  betFactory: Address
  usdc: Address
  cdoPool: Address
  usernameRegistry: Address
  betRiskValidator: Address
  judgeRegistry: Address
}

// Hardhat local network addresses
const hardhatAddresses: ContractAddresses = {
  betFactory: "0x0000000000000000000000000000000000000000", // Update after deployment
  usdc: "0x0000000000000000000000000000000000000000", // Update after deployment
  cdoPool: "0x0000000000000000000000000000000000000000", // Update after deployment
  usernameRegistry: "0x0000000000000000000000000000000000000000", // Update after deployment
  betRiskValidator: "0x0000000000000000000000000000000000000000", // Update after deployment
  judgeRegistry: "0x0000000000000000000000000000000000000000", // Update after deployment
}

// Mantle Sepolia testnet addresses (from deployed-addresses.m)
const sepoliaAddresses: ContractAddresses = {
  betFactory: "0x76b27dFb0408Baa19b3F41469b123c5bBfd56047",
  usdc: "0xA1103E6490ab174036392EbF5c798C9DaBAb24EE", // MockUSDC
  cdoPool: "0x0000000000000000000000000000000000000000", // Multi-pool - use factory
  usernameRegistry: "0x2C0457F82B57148e8363b4589bb3294b23AE7625",
  betRiskValidator: "0x4d0884D03f2fA409370D0F97c6AbC4dA4A8F03d6",
  judgeRegistry: "0x9f3eB17a20a4E57Ed126F34061b0E40dF3a4f5C2",
}

export function getContractAddresses(chainId: number): ContractAddresses {
  switch (chainId) {
    case 31337: // Hardhat
      return hardhatAddresses
    case 5003: // Mantle Sepolia
      return sepoliaAddresses
    case 11155111: // Ethereum Sepolia (for backward compatibility)
      return sepoliaAddresses
    default:
      throw new Error(`Unsupported chain ID: ${chainId}`)
  }
}

export const CONTRACT_ADDRESSES = {
  hardhat: hardhatAddresses,
  sepolia: sepoliaAddresses,
}
