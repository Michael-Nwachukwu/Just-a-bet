import { createAppKit } from '@reown/appkit/react'
import { WagmiAdapter } from '@reown/appkit-adapter-wagmi'
import { hardhat, sepolia } from '@reown/appkit/networks'
import { QueryClient } from '@tanstack/react-query'

// Get projectId from https://cloud.reown.com
export const projectId = process.env.NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID

if (!projectId) {
  throw new Error('NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID is not set')
}

// Create a metadata object
const metadata = {
  name: 'Just-a-Bet',
  description: 'P2P Betting Platform with Yield Generation',
  url: 'https://just-a-bet.app', // Update with your actual URL
  icons: ['https://avatars.githubusercontent.com/u/37784886']
}

// Create the networks array based on environment
const networks = process.env.NODE_ENV === 'development'
  ? [hardhat, sepolia]
  : [sepolia]

// Create Wagmi Adapter
export const wagmiAdapter = new WagmiAdapter({
  networks,
  projectId,
  ssr: true
})

// Create modal
export const modal = createAppKit({
  adapters: [wagmiAdapter],
  networks,
  projectId,
  metadata,
  features: {
    analytics: true,
    email: false,
    socials: false
  }
})

export const config = wagmiAdapter.wagmiConfig

// Create query client
export const queryClient = new QueryClient()
