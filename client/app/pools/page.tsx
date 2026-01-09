"use client"

import Link from "next/link"
import { Button } from "@/components/ui/button"
import { Card, CardContent } from "@/components/ui/card"
import { RefreshCw } from "lucide-react"
import PoolCard from "@/components/pools/pool-card"
import { useActiveAccount } from "thirdweb/react"
import { useAllPoolsStats, useAllUserPositions } from "@/lib/hooks/usePools"
import { useMemo } from "react"

export default function PoolsPage() {
  const account = useActiveAccount()
  const { pools, isLoading } = useAllPoolsStats()
  const { data: userPositions, refetch: refetchPositions } = useAllUserPositions(account?.address)

  // Calculate user stats
  const userStats = useMemo(() => {
    if (!userPositions) return { totalDeposited: 0, totalValue: 0, totalEarned: 0, activePositions: 0 }

    const totalDeposited = userPositions.reduce((sum, p) => sum + p.depositAmountFormatted, 0)

    // For now, value = deposits (need to fetch current share value from contracts for accurate calculation)
    const totalValue = totalDeposited
    const totalEarned = totalValue - totalDeposited
    const activePositions = userPositions.length

    return { totalDeposited, totalValue, totalEarned, activePositions }
  }, [userPositions])

  // Calculate total TVL
  const totalTVL = useMemo(() => {
    if (!pools) return 0
    return pools.reduce((sum, p) => sum + (p?.totalDepositsFormatted || 0), 0)
  }, [pools])

  const handleRefresh = () => {
    refetchPositions()
    // Pool stats will refresh automatically via React Query
  }
  return (
    <main className="pt-16 pb-20">
      <div className="max-w-7xl mx-auto px-6 py-12">
        {/* Header */}
        <div className="flex justify-between items-start mb-12">
          <div>
            <h1 className="text-4xl font-bold mb-2 uppercase">
              <span className="text-orange-500">LIQUIDITY</span> POOLS
            </h1>
            <p className="text-neutral-400">Provide liquidity and earn yield from house bets</p>
          </div>
          <Button variant="outline" onClick={handleRefresh} disabled={isLoading}>
            <RefreshCw className={`w-4 h-4 mr-2 ${isLoading ? "animate-spin" : ""}`} />
            Refresh
          </Button>
        </div>

        {/* Stats Overview */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-12">
          <Card>
            <CardContent className="pt-6">
              <div className="text-3xl font-bold text-orange-500 mb-2">
                {isLoading ? "..." : `$${totalTVL.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`}
              </div>
              <div className="text-xs text-neutral-400 uppercase">Total Value Locked</div>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="pt-6">
              <div className="text-3xl font-bold text-orange-500 mb-2">
                ${userStats.totalDeposited.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
              </div>
              <div className="text-xs text-neutral-400 uppercase">Your Deposits</div>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="pt-6">
              <div className="text-3xl font-bold text-orange-500 mb-2">
                ${userStats.totalValue.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
              </div>
              <div className="text-xs text-neutral-400 uppercase">Current Value</div>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="pt-6">
              <div className="text-3xl font-bold text-orange-500 mb-2">
                {userStats.activePositions}
              </div>
              <div className="text-xs text-neutral-400 uppercase">Active Positions</div>
            </CardContent>
          </Card>
        </div>

        {/* Pools Grid */}
        {isLoading ? (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {Array.from({ length: 4 }).map((_, i) => (
              <div key={i} className="bg-neutral-900 border border-orange-500/20 rounded-lg p-6 animate-pulse">
                <div className="h-6 bg-neutral-700 rounded w-1/2 mb-4"></div>
                <div className="h-4 bg-neutral-700 rounded w-3/4 mb-4"></div>
                <div className="h-4 bg-neutral-700 rounded w-2/3"></div>
              </div>
            ))}
          </div>
        ) : pools && pools.length > 0 ? (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {pools.map((pool) => {
              // Extra safety check for poolInfo
              if (!pool || !pool.poolInfo || !pool.poolInfo.address) return null

              return (
                <PoolCard
                  key={pool.poolInfo.address}
                  id={pool.poolInfo.address}
                  name={pool.poolInfo.name}
                  category={pool.poolInfo.category.toLowerCase()}
                  liquidity={pool.totalDepositsFormatted}
                  available={pool.availableLiquidityFormatted}
                  activeBets={Number(pool.totalBetsMatched)}
                  utilization={pool.utilizationRate}
                />
              )
            })}
          </div>
        ) : (
          <Card className="text-center py-12">
            <CardContent>
              <h3 className="text-lg font-bold mb-2">No pools found</h3>
              <p className="text-neutral-400 text-sm">Unable to load pool data</p>
            </CardContent>
          </Card>
        )}
      </div>
    </main>
  )
}
