"use client"

import { Card, CardContent } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import Link from "next/link"
import { useJudgeProfile } from "@/lib/hooks/useJudgeRegistry"
import { formatAddress } from "@/lib/utils"
import { Award, Scale, TrendingUp, Shield } from "lucide-react"

interface JudgeCardProps {
  judgeAddress: `0x${string}`
  showActions?: boolean
}

export function JudgeCard({ judgeAddress, showActions = true }: JudgeCardProps) {
  const { profile, isLoading } = useJudgeProfile(judgeAddress)

  if (isLoading) {
    return (
      <Card className="animate-pulse">
        <CardContent className="pt-6">
          <div className="h-24 bg-neutral-800 rounded"></div>
        </CardContent>
      </Card>
    )
  }

  if (!profile) {
    return null
  }

  const getReputationColor = (reputation: number) => {
    if (reputation >= 80) return "bg-green-500/20 text-green-400 border-green-500/30"
    if (reputation >= 60) return "bg-cyan-500/20 text-cyan-400 border-cyan-500/30"
    if (reputation >= 40) return "bg-orange-500/20 text-orange-400 border-orange-500/30"
    return "bg-red-500/20 text-red-400 border-red-500/30"
  }

  const getStatusColor = (isActive: boolean, isEligible: boolean) => {
    if (isActive && isEligible) return "bg-green-500/20 text-green-400 border-0"
    if (isActive) return "bg-orange-500/20 text-orange-400 border-0"
    return "bg-neutral-500/20 text-neutral-400 border-0"
  }

  const getStatusText = (isActive: boolean, isEligible: boolean) => {
    if (isActive && isEligible) return "ELIGIBLE"
    if (isActive) return "ACTIVE"
    return "INACTIVE"
  }

  return (
    <Card className="hover:border-orange-500/40 transition-all">
      <CardContent className="pt-6">
        {/* Header */}
        <div className="flex justify-between items-start mb-4">
          <div>
            <h3 className="font-bold text-lg mb-1">
              {formatAddress(profile.judgeAddress)}
            </h3>
            <p className="text-sm text-neutral-400">
              Judge since {new Date(Number(profile.registrationTime) * 1000).toLocaleDateString()}
            </p>
          </div>
          <Badge className={getStatusColor(profile.isActive, profile.isEligible)}>
            {getStatusText(profile.isActive, profile.isEligible)}
          </Badge>
        </div>

        {/* Stats Grid */}
        <div className="grid grid-cols-2 gap-4 mb-6">
          <div>
            <div className="flex items-center gap-2 text-xs text-neutral-400 mb-1">
              <Award className="h-3 w-3" />
              REPUTATION
            </div>
            <div className="flex items-center gap-2">
              <Badge className={getReputationColor(profile.reputationPercentage)}>
                {profile.reputationPercentage.toFixed(1)}%
              </Badge>
            </div>
          </div>

          <div>
            <div className="flex items-center gap-2 text-xs text-neutral-400 mb-1">
              <Shield className="h-3 w-3" />
              STAKED
            </div>
            <div className="font-bold text-cyan-400">
              {parseFloat(profile.stakedAmountFormatted).toFixed(2)} MNT
            </div>
          </div>

          <div>
            <div className="flex items-center gap-2 text-xs text-neutral-400 mb-1">
              <Scale className="h-3 w-3" />
              CASES JUDGED
            </div>
            <div className="font-bold">
              {profile.casesJudged.toString()}
            </div>
          </div>

          <div>
            <div className="flex items-center gap-2 text-xs text-neutral-400 mb-1">
              <TrendingUp className="h-3 w-3" />
              SUCCESS RATE
            </div>
            <div className="font-bold text-green-400">
              {profile.successRate.toFixed(1)}%
            </div>
          </div>
        </div>

        {/* Actions */}
        {showActions && (
          <Link href={`/judges/${judgeAddress}`} className="block">
            <Button variant="outline" className="w-full bg-transparent hover:bg-orange-500/10 hover:border-orange-500/40">
              View Profile
            </Button>
          </Link>
        )}
      </CardContent>
    </Card>
  )
}
