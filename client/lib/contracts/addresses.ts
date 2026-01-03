import { Address } from "viem"

export type ContractAddresses = {
  betFactory: Address
  usdc: Address
  cdoPool: Address
  usernameRegistry: Address
  betRiskValidator: Address
}

// Hardhat local network addresses
const hardhatAddresses: ContractAddresses = {
  betFactory: "0x0000000000000000000000000000000000000000", // Update after deployment
  usdc: "0x0000000000000000000000000000000000000000", // Update after deployment
  cdoPool: "0x0000000000000000000000000000000000000000", // Update after deployment
  usernameRegistry: "0x0000000000000000000000000000000000000000", // Update after deployment
  betRiskValidator: "0x0000000000000000000000000000000000000000", // Update after deployment
}

// Sepolia testnet addresses
const sepoliaAddresses: ContractAddresses = {
  betFactory: "0x0000000000000000000000000000000000000000", // Update after deployment
  usdc: "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238", // Sepolia USDC
  cdoPool: "0x0000000000000000000000000000000000000000", // Update after deployment
  usernameRegistry: "0x0000000000000000000000000000000000000000", // Update after deployment
  betRiskValidator: "0x0000000000000000000000000000000000000000", // Update after deployment
}

export function getContractAddresses(chainId: number): ContractAddresses {
  switch (chainId) {
    case 31337: // Hardhat
      return hardhatAddresses
    case 11155111: // Sepolia
      return sepoliaAddresses
    default:
      throw new Error(`Unsupported chain ID: ${chainId}`)
  }
}

export const CONTRACT_ADDRESSES = {
  hardhat: hardhatAddresses,
  sepolia: sepoliaAddresses,
}
