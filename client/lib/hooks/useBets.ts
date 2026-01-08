import { useQuery } from "@tanstack/react-query"
import { useActiveAccount } from "thirdweb/react"
import { readContract, getContract } from "thirdweb"
import { useBetFactoryContract } from "./useContracts"
import { client, mantleSepolia } from "@/lib/thirdweb"
import { ABIS } from "../contracts/abis"

// Utility to split array into chunks
function chunk<T>(array: T[], size: number): T[][] {
  const chunks: T[][] = []
  for (let i = 0; i < array.length; i += size) {
    chunks.push(array.slice(i, i + size))
  }
  return chunks
}

/**
 * Fetch all bet addresses from BetFactory
 */
export function useAllBetAddresses() {
  const betFactory = useBetFactoryContract()

  return useQuery({
    queryKey: ["betAddresses"],
    queryFn: async () => {
      const addresses = await readContract({
        contract: betFactory,
        method: "function getAllBets() view returns (address[])",
        params: [],
      })
      return addresses as string[]
    },
    staleTime: 30000, // 30 seconds
  })
}

/**
 * Fetch details for a single bet
 */
export function useBetDetails(betAddress: string) {
  return useQuery({
    queryKey: ["bet", betAddress],
    queryFn: async () => {
      const contract = getContract({
        client,
        chain: mantleSepolia,
        address: betAddress as `0x${string}`,
        abi: ABIS.Bet,
      })

      // Thirdweb will use the ABI we provided to the contract
      const details = await readContract({
        contract,
        method: "getBetDetails",
        params: [],
      })

      // Transform to UI format - details is a struct object
      return {
        address: betAddress,
        creator: details.creator as string,
        opponent: details.opponent as string,
        stakeAmount: BigInt(details.stakeAmount?.toString() ?? "0"),
        description: details.description as string,
        outcomeDescription: details.outcomeDescription as string,
        createdAt: BigInt(details.createdAt?.toString() ?? "0"),
        expiresAt: BigInt(details.expiresAt?.toString() ?? "0"),
        state: Number(details.state ?? 0), // 0=Created, 1=Active, 2=AwaitingResolution, 3=InDispute, 4=Resolved, 5=Cancelled
        outcome: Number(details.outcome ?? 0), // 0=Pending, 1=CreatorWins, 2=OpponentWins, 3=Draw
        creatorFunded: false, // Will fetch separately
        opponentFunded: false, // Will fetch separately
        tags: (details.tags as string[]) || [],
      }
    },
    enabled: !!betAddress && betAddress !== "0x0000000000000000000000000000000000000000",
    staleTime: 30000,
  })
}

/**
 * Fetch multiple bets in batches
 */
export function useBatchBetDetails(addresses: string[]) {
  return useQuery({
    queryKey: ["bets", addresses],
    queryFn: async () => {
      if (!addresses || addresses.length === 0) return []

      // Filter out zero addresses
      const validAddresses = addresses.filter(
        (addr) => addr && addr !== "0x0000000000000000000000000000000000000000"
      )

      // Fetch in batches of 10 to avoid rate limits
      const batches = chunk(validAddresses, 10)
      const results = []

      for (const batch of batches) {
        const batchResults = await Promise.all(
          batch.map(async (addr) => {
            try {
              const contract = getContract({
                client,
                chain: mantleSepolia,
                address: addr as `0x${string}`,
                abi: ABIS.Bet,
              })

              // Thirdweb will use the ABI we provided to the contract
              const details = await readContract({
                contract,
                method: "getBetDetails",
                params: [],
              })

              return {
                address: addr,
                creator: details.creator as string,
                opponent: details.opponent as string,
                stakeAmount: BigInt(details.stakeAmount?.toString() ?? "0"),
                description: details.description as string,
                outcomeDescription: details.outcomeDescription as string,
                createdAt: BigInt(details.createdAt?.toString() ?? "0"),
                expiresAt: BigInt(details.expiresAt?.toString() ?? "0"),
                state: Number(details.state ?? 0),
                outcome: Number(details.outcome ?? 0),
                creatorFunded: false, // Will fetch separately
                opponentFunded: false, // Will fetch separately
                tags: (details.tags as string[]) || [],
              }
            } catch (error) {
              console.error(`Error fetching bet ${addr}:`, error)
              return null
            }
          })
        )
        results.push(...batchResults.filter((r) => r !== null))
      }

      return results
    },
    enabled: addresses && addresses.length > 0,
    staleTime: 30000,
  })
}

/**
 * Get bets for a specific user (created or joined)
 */
export function useUserBets(userAddress?: string) {
  const account = useActiveAccount()
  const addressToQuery = userAddress || account?.address
  const betFactory = useBetFactoryContract()

  const { data: addresses, isLoading: isLoadingAddresses } = useQuery({
    queryKey: ["userBets", addressToQuery],
    queryFn: async () => {
      if (!addressToQuery) return []

      const bets = await readContract({
        contract: betFactory,
        method: "function getBetsForUser(address) view returns (address[])",
        params: [addressToQuery],
      })

      return bets as string[]
    },
    enabled: !!addressToQuery,
    staleTime: 30000,
  })

  const {
    data: bets,
    isLoading: isLoadingBets,
    refetch,
  } = useBatchBetDetails(addresses || [])

  return {
    bets,
    isLoading: isLoadingAddresses || isLoadingBets,
    refetch,
  }
}

/**
 * Get bets created by a specific user
 */
export function useCreatedBets(userAddress?: string) {
  const { bets, isLoading, refetch } = useUserBets(userAddress)

  const account = useActiveAccount()
  const addressToFilter = userAddress || account?.address

  const createdBets = bets?.filter((bet) => bet.creator.toLowerCase() === addressToFilter?.toLowerCase()) || []

  return {
    bets: createdBets,
    isLoading,
    refetch,
  }
}

/**
 * Get bets joined by a specific user (as opponent)
 */
export function useJoinedBets(userAddress?: string) {
  const { bets, isLoading, refetch } = useUserBets(userAddress)

  const account = useActiveAccount()
  const addressToFilter = userAddress || account?.address

  const joinedBets = bets?.filter(
    (bet) => bet.opponent.toLowerCase() === addressToFilter?.toLowerCase() &&
             bet.opponent !== "0x0000000000000000000000000000000000000000"
  ) || []

  return {
    bets: joinedBets,
    isLoading,
    refetch,
  }
}

/**
 * Get count of bets by state
 */
export function useBetCountByState() {
  const betFactory = useBetFactoryContract()

  return useQuery({
    queryKey: ["betCountByState"],
    queryFn: async () => {
      try {
        const counts = await readContract({
          contract: betFactory,
          method: "function getBetCountsByState() view returns (uint256, uint256, uint256, uint256, uint256, uint256)",
          params: [],
        })

        return {
          created: Number(counts[0] ?? 0),
          active: Number(counts[1] ?? 0),
          awaitingResolution: Number(counts[2] ?? 0),
          inDispute: Number(counts[3] ?? 0),
          resolved: Number(counts[4] ?? 0),
          cancelled: Number(counts[5] ?? 0),
        }
      } catch (error) {
        console.error("Error fetching bet counts:", error)
        return {
          created: 0,
          active: 0,
          awaitingResolution: 0,
          inDispute: 0,
          resolved: 0,
          cancelled: 0,
        }
      }
    },
    staleTime: 60000, // 1 minute
  })
}
