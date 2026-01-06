import Link from "next/link"
import { Button } from "@/components/ui/button"
import { Card, CardContent } from "@/components/ui/card"
import PoolCard from "@/components/pools/pool-card"

const mockPools = [
  {
    id: "1",
    name: "Sports Pool - NBA",
    category: "sports",
    apy: 12.5,
    liquidity: 1200000,
    available: 800000,
    activeBets: 45,
    utilization: 33,
    description: "NBA basketball games and player performance bets",
    riskTier: "Medium",
  },
  {
    id: "2",
    name: "Crypto Pool - BTC/ETH",
    category: "crypto",
    apy: 18.2,
    liquidity: 2500000,
    available: 1500000,
    activeBets: 128,
    utilization: 40,
    description: "Bitcoin and Ethereum price movements and market bets",
    riskTier: "High",
  },
  {
    id: "3",
    name: "Entertainment Pool",
    category: "entertainment",
    apy: 9.8,
    liquidity: 750000,
    available: 600000,
    activeBets: 23,
    utilization: 20,
    description: "Movie releases, celebrity news, and entertainment events",
    riskTier: "Low",
  },
  {
    id: "4",
    name: "Weather Pool",
    category: "weather",
    apy: 6.5,
    liquidity: 300000,
    available: 250000,
    activeBets: 12,
    utilization: 17,
    description: "Weather predictions and natural phenomena bets",
    riskTier: "Low",
  },
]

export default function PoolsPage() {
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
          <Button asChild>
            <Link href="/pools/1">Deposit to Pool</Link>
          </Button>
        </div>

        {/* Stats Overview */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-12">
          {[
            { label: "Total Value Locked", value: "$5.2M" },
            { label: "Your Deposits", value: "$1,234" },
            { label: "Total Earned", value: "$52.30" },
            { label: "Active Positions", value: "3" },
          ].map((stat) => (
            <Card key={stat.label}>
              <CardContent className="pt-6">
                <div className="text-3xl font-bold text-orange-500 mb-2">{stat.value}</div>
                <div className="text-xs text-neutral-400 uppercase">{stat.label}</div>
              </CardContent>
            </Card>
          ))}
        </div>

        {/* Pools Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {mockPools.map((pool) => (
            <PoolCard key={pool.id} {...pool} />
          ))}
        </div>
      </div>
    </main>
  )
}
