import { useQuery, useQueries } from "@tanstack/react-query"
import { useActiveAccount } from "thirdweb/react"
import { useSendTransaction } from "thirdweb/react"
import { readContract, prepareContractCall, toUnits, getContract } from "thirdweb"
import { getContractAddresses } from "../contracts/addresses"
import { client, mantleSepolia } from "@/lib/thirdweb"
import { ABIS } from "../contracts/abis"
/**
 * Format USDC amount from wei to human readable
 */
function formatUSDC(amount: bigint): number {
  return Number(amount) / 1_000_000
}

/**
 * Get contract for specific pool address
 */
function getPoolContract(poolAddress: string) {
  return getContract({
    client,
    chain: mantleSepolia,
    address: poolAddress as `0x${string}`,
    abi: ABIS.CDOPool,
  })
}

/**
 * Hook to get stats for a specific pool
 */
export function usePoolStats(poolAddress: string) {
  return useQuery({
    queryKey: ["poolStats", poolAddress],
    queryFn: async () => {
      const contract = getPoolContract(poolAddress)

      try {
        const stats = await readContract({
          contract,
          method: "function getPoolStats() view returns (uint256, uint256, uint256, uint256, uint256)",
          params: [],
        })

        const totalDeposits = BigInt(stats[0]?.toString() ?? "0")
        const totalShares = BigInt(stats[1]?.toString() ?? "0")
        const activeMatchedAmount = BigInt(stats[2]?.toString() ?? "0")
        const totalBetsMatched = BigInt(stats[3]?.toString() ?? "0")
        const accumulatedYield = BigInt(stats[4]?.toString() ?? "0")

        return {
          totalDeposits,
          totalShares,
          activeMatchedAmount,
          totalBetsMatched,
          accumulatedYield,
          // Formatted versions
          totalDepositsFormatted: formatUSDC(totalDeposits),
          activeMatchedAmountFormatted: formatUSDC(activeMatchedAmount),
          availableLiquidity: totalDeposits - activeMatchedAmount,
          availableLiquidityFormatted: formatUSDC(totalDeposits - activeMatchedAmount),
          utilizationRate: totalDeposits > BigInt(0)
            ? Number((activeMatchedAmount * BigInt(10000)) / totalDeposits) / 100
            : 0,
          accumulatedYieldFormatted: formatUSDC(accumulatedYield),
        }
      } catch (error) {
        console.error(`Error fetching pool stats for ${poolAddress}:`, error)
        return null
      }
    },
    enabled: !!poolAddress,
    staleTime: 30000,
  })
}

/**
 * Hook to get stats for all 4 pools
 */
export function useAllPoolsStats() {
  const addresses = getContractAddresses(5003)
  const pools = Object.values(addresses.pools)

  const queries = useQueries({
    queries: pools.map((pool) => ({
      queryKey: ["poolStats", pool.address],
      queryFn: async () => {
        const contract = getPoolContract(pool.address)

        try {
          const stats = await readContract({
            contract,
            method: "function getPoolStats() view returns (uint256, uint256, uint256, uint256, uint256)",
            params: [],
          })

          const totalDeposits = BigInt(stats[0]?.toString() ?? "0")
          const activeMatchedAmount = BigInt(stats[2]?.toString() ?? "0")

          return {
            poolInfo: pool,
            totalDeposits,
            activeMatchedAmount,
            totalBetsMatched: BigInt(stats[3]?.toString() ?? "0"),
            accumulatedYield: BigInt(stats[4]?.toString() ?? "0"),
            totalDepositsFormatted: formatUSDC(totalDeposits),
            activeMatchedAmountFormatted: formatUSDC(activeMatchedAmount),
            availableLiquidity: totalDeposits - activeMatchedAmount,
            availableLiquidityFormatted: formatUSDC(totalDeposits - activeMatchedAmount),
            utilizationRate: totalDeposits > BigInt(0)
              ? Number((activeMatchedAmount * BigInt(10000)) / totalDeposits) / 100
              : 0,
          }
        } catch (error) {
          console.error(`Error fetching pool stats for ${pool.name}:`, error)
          return null
        }
      },
      staleTime: 30000,
    })),
  })

  const isLoading = queries.some((q) => q.isLoading)
  const poolsData = queries.map((q) => q.data).filter((d) => d !== null)

  return {
    pools: poolsData,
    isLoading,
  }
}

/**
 * Hook to get user positions in a specific pool
 */
export function useUserPositions(poolAddress: string, userAddress?: string) {
  const account = useActiveAccount()
  const addressToQuery = userAddress || account?.address

  return useQuery({
    queryKey: ["positions", poolAddress, addressToQuery],
    queryFn: async () => {
      if (!addressToQuery) return []

      const contract = getPoolContract(poolAddress)

      try {
        const positionCount = await readContract({
          contract,
          method: "function getUserPositionCount(address) view returns (uint256)",
          params: [addressToQuery],
        })

        const count = Number(positionCount)
        if (count === 0) return []

        // Fetch all positions
        const positions = await Promise.all(
          Array.from({ length: count }, async (_, index) => {
            const position = await readContract({
              contract,
              method: "function getUserPosition(address, uint256) view returns (uint256, uint256, uint8, uint256, uint256, bool)",
              params: [addressToQuery, BigInt(index)],
            })

            return {
              id: index,
              depositAmount: BigInt(position[0]?.toString() ?? "0"),
              shares: BigInt(position[1]?.toString() ?? "0"),
              tier: Number(position[2] ?? 0),
              depositTime: BigInt(position[3]?.toString() ?? "0"),
              lockEndTime: BigInt(position[4]?.toString() ?? "0"),
              withdrawn: Boolean(position[5]),
              depositAmountFormatted: formatUSDC(BigInt(position[0]?.toString() ?? "0")),
              isLocked: BigInt(position[4]?.toString() ?? "0") > BigInt(Math.floor(Date.now() / 1000)),
            }
          })
        )

        return positions.filter((p) => !p.withdrawn)
      } catch (error) {
        console.error(`Error fetching user positions:`, error)
        return []
      }
    },
    enabled: !!addressToQuery && !!poolAddress,
    staleTime: 30000,
  })
}

/**
 * Hook to get user positions across all pools
 */
export function useAllUserPositions(userAddress?: string) {
  const addresses = getContractAddresses(5003)
  const pools = Object.values(addresses.pools)
  const account = useActiveAccount()
  const addressToQuery = userAddress || account?.address

  return useQuery({
    queryKey: ["allUserPositions", addressToQuery],
    queryFn: async () => {
      if (!addressToQuery) return []

      const allPositions = await Promise.all(
        pools.map(async (pool) => {
          const contract = getPoolContract(pool.address)

          try {
            const positionCount = await readContract({
              contract,
              method: "function getUserPositionCount(address) view returns (uint256)",
              params: [addressToQuery],
            })

            const count = Number(positionCount)
            if (count === 0) return []

            const positions = await Promise.all(
              Array.from({ length: count }, async (_, index) => {
                const position = await readContract({
                  contract,
                  method: "function getUserPosition(address, uint256) view returns (uint256, uint256, uint8, uint256, uint256, bool)",
                  params: [addressToQuery, BigInt(index)],
                })

                return {
                  poolAddress: pool.address,
                  poolName: pool.name,
                  poolCategory: pool.category,
                  id: index,
                  depositAmount: BigInt(position[0]?.toString() ?? "0"),
                  shares: BigInt(position[1]?.toString() ?? "0"),
                  tier: Number(position[2] ?? 0),
                  depositTime: BigInt(position[3]?.toString() ?? "0"),
                  lockEndTime: BigInt(position[4]?.toString() ?? "0"),
                  withdrawn: Boolean(position[5]),
                  depositAmountFormatted: formatUSDC(BigInt(position[0]?.toString() ?? "0")),
                  isLocked: BigInt(position[4]?.toString() ?? "0") > BigInt(Math.floor(Date.now() / 1000)),
                }
              })
            )

            return positions.filter((p) => !p.withdrawn)
          } catch (error) {
            console.error(`Error fetching positions for pool ${pool.name}:`, error)
            return []
          }
        })
      )

      return allPositions.flat()
    },
    enabled: !!addressToQuery,
    staleTime: 30000,
  })
}

/**
 * Hook to deposit to a specific pool
 */
export function useDepositToPool(poolAddress: string) {
  const contract = getPoolContract(poolAddress)
  const { mutate: sendTransaction, data: transactionResult, isPending, error } = useSendTransaction()

  const deposit = (amount: string, tier: number) => {
    const amountWei = toUnits(amount, 6)

    const transaction = prepareContractCall({
      contract,
      method: "function deposit(uint256, uint8)",
      params: [amountWei, tier],
    })

    sendTransaction(transaction)
  }

  return {
    deposit,
    isPending,
    isConfirming: isPending,
    isSuccess: !!transactionResult && !error,
    hash: transactionResult?.transactionHash,
    error,
  }
}

/**
 * Hook to withdraw from a specific pool
 */
export function useWithdrawFromPool(poolAddress: string) {
  const contract = getPoolContract(poolAddress)
  const { mutate: sendTransaction, data: transactionResult, isPending, error } = useSendTransaction()

  const withdraw = (positionId: number) => {
    const transaction = prepareContractCall({
      contract,
      method: "function withdraw(uint256)",
      params: [BigInt(positionId)],
    })

    sendTransaction(transaction)
  }

  return {
    withdraw,
    isPending,
    isConfirming: isPending,
    isSuccess: !!transactionResult && !error,
    hash: transactionResult?.transactionHash,
    error,
  }
}

/**
 * Hook to get tier configuration
 */
export function useTierConfig() {
  return {
    tiers: [
      { id: 0, name: "Flexible", lockDays: 0, apyBoost: 0, description: "No lock period" },
      { id: 1, name: "30 Days", lockDays: 30, apyBoost: 20, description: "30-day lock, 20% APY boost" },
      { id: 2, name: "90 Days", lockDays: 90, apyBoost: 50, description: "90-day lock, 50% APY boost" },
      { id: 3, name: "365 Days", lockDays: 365, apyBoost: 100, description: "1-year lock, 100% APY boost" },
    ],
  }
}
