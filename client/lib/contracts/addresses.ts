import { defineChain } from "thirdweb";

export const MANTLE_SEPOLIA_CHAIN = defineChain({
  id: 5003,
  name: "Mantle Sepolia",
  nativeCurrency: {
    name: "Mantle",
    symbol: "MNT",
    decimals: 18,
  },
  rpc: "https://rpc.sepolia.mantle.xyz",
  testnet: true,
});

export const ADDRESSES = {
  5003: {
    // Core Contracts
    usdc: "0xA1103E6490ab174036392EbF5c798C9DaBAb24EE", // Matches deployed-addresses.m (renamed from mockUSDC to usdc to match hooks)
    betFactory: "0x07ecE77248D4E3f295fdFaeC1C86e257098A434a",
    cdoPoolFactory: "0xc616918154D7a9dB5D78480d1d53820d4423b298",

    // Registries & Validators
    usernameRegistry: "0x2C0457F82B57148e8363b4589bb3294b23AE7625",
    judgeRegistry: "0x9f3eB17a20a4E57Ed126F34061b0E40dF3a4f5C2",
    betRiskValidator: "0x4d0884D03f2fA409370D0F97c6AbC4dA4A8F03d6",
    disputeManager: "0x3335BaEEDdD1Cc77B8Ab9acBF862764812337a3F",
    betYieldVault: "0x12ccF0F4A22454d53aBdA56a796a08e93E947256",

    // Pools & CDO Tokens (Matches deployed-addresses.m)
    pools: {
      sports: {
        address: "0x2b2E21596A22f6Ab273E41F4BB28Dcc1D0be6D85",
        cdoToken: "0xDb02a4d36c750FE94986ac4E9B736EA31ac9B32e",
        name: "Sports Pool - NBA",
        category: "Sports",
        poolId: 0,
      },
      crypto: {
        address: "0xd0B0aF8488D7000c6658a0E7A50566dAa6B6E631",
        cdoToken: "0xEb3aE9248B253e4dEbfd2A1A822cCB129D618bF5",
        name: "Crypto Pool - BTC",
        category: "Crypto",
        poolId: 1,
      },
      politics: {
        address: "0xb8886E5638d17Fe6161976FD4Ca27d2DaAC9029f",
        cdoToken: "0xA8586243CBf327B4c8Fd061B2a1F2B0CCD495297",
        name: "Politics Pool",
        category: "Politics",
        poolId: 2,
      },
      general: {
        address: "0x2b2E21596A22f6Ab273E41F4BB28Dcc1D0be6D85",
        cdoToken: "0xDb02a4d36c750FE94986ac4E9B736EA31ac9B32e", // Matches Pool 0 (Sports) as routing dictates
        name: "General Pool",
        category: "General",
        poolId: 3,
      },
    },
  },
} as const;

export const ACTIVE_CHAIN = MANTLE_SEPOLIA_CHAIN;
export const ACTIVE_CHAIN_ID = 5003;

export const getContractAddresses = (chainId: number = ACTIVE_CHAIN_ID) => {
  return ADDRESSES[chainId as keyof typeof ADDRESSES];
};
