import { createThirdwebClient, defineChain } from "thirdweb"
import { createWallet } from "thirdweb/wallets"

// Get client ID from Thirdweb dashboard
const clientId = process.env.NEXT_PUBLIC_THIRDWEB_CLIENT_ID

if (!clientId) {
  throw new Error("NEXT_PUBLIC_THIRDWEB_CLIENT_ID is not set")
}

// Create Thirdweb client
export const client = createThirdwebClient({
  clientId,
})

// Define Mantle Sepolia chain
export const mantleSepolia = defineChain({
  id: 5003,
  name: "Mantle Sepolia",
  nativeCurrency: {
    name: "MNT",
    symbol: "MNT",
    decimals: 18,
  },
  rpc: "https://rpc.sepolia.mantle.xyz",
  blockExplorers: [
    {
      name: "Mantle Sepolia Explorer",
      url: "https://explorer.sepolia.mantle.xyz",
    },
  ],
  testnet: true,
})

// Supported wallets
export const wallets = [
  createWallet("io.metamask"),
  createWallet("com.coinbase.wallet"),
  createWallet("me.rainbow"),
  createWallet("io.rabby"),
  createWallet("walletConnect"),
]
