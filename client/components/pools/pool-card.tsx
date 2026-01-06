import Link from "next/link"
import { Card, CardContent } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"

interface PoolCardProps {
  id: string
  name: string
  category: string
  apy: number
  liquidity: number
  available: number
  activeBets: number
  utilization: number
  description: string
  riskTier: string
}

export default function PoolCard({
  id,
  name,
  category,
  apy,
  liquidity,
  available,
  activeBets,
  utilization,
  description,
  riskTier,
}: PoolCardProps) {
  const riskColors = {
    Low: "bg-green-500/20 text-green-400",
    Medium: "bg-yellow-500/20 text-yellow-400",
    High: "bg-red-500/20 text-red-400",
  }

  return (
    <Card>
      <CardContent className="pt-6">
        {/* Header */}
        <div className="flex justify-between items-start mb-6">
          <div>
            <h3 className="text-xl font-bold mb-2">{name}</h3>
            <Badge className="bg-blue-500/20 text-blue-400 border-0">{category}</Badge>
          </div>
          <div className="text-right">
            <div className="text-3xl font-bold text-orange-500">{apy.toFixed(1)}%</div>
            <div className="text-xs text-neutral-400 uppercase">APY</div>
          </div>
        </div>

        {/* Stats Grid */}
        <div className="grid grid-cols-2 gap-4 mb-6 pb-6 border-b border-neutral-700">
          <div>
            <div className="text-sm text-neutral-400 uppercase text-xs mb-1">Total Liquidity</div>
            <div className="font-bold">${(liquidity / 1000000).toFixed(1)}M</div>
          </div>
          <div>
            <div className="text-sm text-neutral-400 uppercase text-xs mb-1">Available</div>
            <div className="font-bold">${(available / 1000).toFixed(0)}K</div>
          </div>
          <div>
            <div className="text-sm text-neutral-400 uppercase text-xs mb-1">Active Bets</div>
            <div className="font-bold">{activeBets}</div>
          </div>
          <div>
            <div className="text-sm text-neutral-400 uppercase text-xs mb-1">Utilization</div>
            <div className="font-bold">{utilization}%</div>
          </div>
        </div>

        {/* Description */}
        <p className="text-sm text-neutral-400 mb-4">{description}</p>

        {/* Risk Info */}
        <div className="flex items-center justify-between mb-6 pb-6 border-b border-neutral-700">
          <div>
            <div className="text-xs text-neutral-400 uppercase mb-2">Risk Tier</div>
            <Badge className={`${riskColors[riskTier as keyof typeof riskColors]} border-0`}>{riskTier} Risk</Badge>
          </div>
          <div className="text-right text-xs text-neutral-400">
            <div className="mb-1">Min: $10</div>
            <div>Max: $10K</div>
          </div>
        </div>

        {/* Actions */}
        <div className="flex gap-3">
          <Button asChild className="flex-1">
            <Link href={`/pools/${id}`}>Deposit</Link>
          </Button>
          <Button asChild variant="outline" className="flex-1 bg-transparent">
            <Link href={`/pools/${id}`}>View Details</Link>
          </Button>
        </div>
      </CardContent>
    </Card>
  )
}
