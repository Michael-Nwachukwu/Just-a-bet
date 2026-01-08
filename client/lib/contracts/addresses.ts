import { Address } from "viem"

export type PoolInfo = {
  address: Address
  cdoToken: Address
  name: string
  category: string
  poolId: number
}

export type ContractAddresses = {
  betFactory: Address
  usdc: Address
  usernameRegistry: Address
  betRiskValidator: Address
  judgeRegistry: Address
  betYieldVault: Address
  disputeManager: Address
  cdoPoolFactory: Address
  mockYieldStrategy: Address
  pools: {
    sports: PoolInfo
    crypto: PoolInfo
    politics: PoolInfo
    general: PoolInfo
  }
}

// Hardhat local network addresses
const hardhatAddresses: ContractAddresses = {
  betFactory: "0x0000000000000000000000000000000000000000",
  usdc: "0x0000000000000000000000000000000000000000",
  usernameRegistry: "0x0000000000000000000000000000000000000000",
  betRiskValidator: "0x0000000000000000000000000000000000000000",
  judgeRegistry: "0x0000000000000000000000000000000000000000",
  betYieldVault: "0x0000000000000000000000000000000000000000",
  disputeManager: "0x0000000000000000000000000000000000000000",
  cdoPoolFactory: "0x0000000000000000000000000000000000000000",
  mockYieldStrategy: "0x0000000000000000000000000000000000000000",
  pools: {
    sports: {
      address: "0x0000000000000000000000000000000000000000",
      cdoToken: "0x0000000000000000000000000000000000000000",
      name: "Sports Pool",
      category: "Sports",
      poolId: 0,
    },
    crypto: {
      address: "0x0000000000000000000000000000000000000000",
      cdoToken: "0x0000000000000000000000000000000000000000",
      name: "Crypto Pool",
      category: "Crypto",
      poolId: 1,
    },
    politics: {
      address: "0x0000000000000000000000000000000000000000",
      cdoToken: "0x0000000000000000000000000000000000000000",
      name: "Politics Pool",
      category: "Politics",
      poolId: 2,
    },
    general: {
      address: "0x0000000000000000000000000000000000000000",
      cdoToken: "0x0000000000000000000000000000000000000000",
      name: "General Pool",
      category: "General",
      poolId: 3,
    },
  },
}

// Mantle Sepolia testnet addresses (from deployed-addresses.m)
const sepoliaAddresses: ContractAddresses = {
  betFactory: "0x76b27dFb0408Baa19b3F41469b123c5bBfd56047",
  usdc: "0xA1103E6490ab174036392EbF5c798C9DaBAb24EE", // MockUSDC
  usernameRegistry: "0x2C0457F82B57148e8363b4589bb3294b23AE7625",
  betRiskValidator: "0x4d0884D03f2fA409370D0F97c6AbC4dA4A8F03d6",
  judgeRegistry: "0x9f3eB17a20a4E57Ed126F34061b0E40dF3a4f5C2",
  betYieldVault: "0x12ccF0F4A22454d53aBdA56a796a08e93E947256",
  disputeManager: "0x3335BaEEDdD1Cc77B8Ab9acBF862764812337a3F",
  cdoPoolFactory: "0xBc61e19874B98D2429fABc645635439dBaA0Adde",
  mockYieldStrategy: "0xE9b224bE25B2823250f4545709A11e8ebAC18b34",
  pools: {
    sports: {
      address: "0x1E8d4BF45aB7EF0B7e4a7d46da2290fEa761F973",
      cdoToken: "0xd34F2B8a2cd3f2B4b401c2EB612676277774A42B",
      name: "Sports Pool - NBA",
      category: "Sports",
      poolId: 0,
    },
    crypto: {
      address: "0x6651aE6442b6CF752f30860cf8725b24b086295f",
      cdoToken: "0x85Aa34014C68eE61Fe838e30f685A13339fAEeFd",
      name: "Crypto Pool - BTC",
      category: "Crypto",
      poolId: 1,
    },
    politics: {
      address: "0x6a6b4bF68F3C87532cF216407d23FeC5a620398E",
      cdoToken: "0x20403443a5b093523439ca6feF4ccF123B9360B9",
      name: "Politics Pool",
      category: "Politics",
      poolId: 2,
    },
    general: {
      address: "0xE5a49B55996624a4521a6325a7Df080074f32D22",
      cdoToken: "0xd3e78BF26C938B21e361b8073C147be71b53a436",
      name: "General Pool",
      category: "General",
      poolId: 3,
    },
  },
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
