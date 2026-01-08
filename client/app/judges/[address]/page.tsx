"use client"

import { use } from "react"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { useJudgeProfile } from "@/lib/hooks/useJudgeRegistry"
import { formatAddress } from "@/lib/utils"
import { Scale, Award, TrendingUp, Shield, Calendar, CheckCircle } from "lucide-react"

export default function JudgeProfilePage({ params }: { params: Promise<{ address: string }> }) {
  const { address } = use(params)
  const judgeAddress = address as `0x${string}`
  
  const { profile, isLoading } = useJudgeProfile(judgeAddress)

  if (isLoading) {
    return (
      <div className="container mx-auto px-4 py-8">
        <div className="animate-pulse space-y-4">
          <div className="h-8 bg-neutral-800 rounded w-1/4"></div>
          <div className="h-4 bg-neutral-800 rounded w-1/2"></div>
        </div>
      </div>
    )
  }

  if (!profile) {
    return (
      <div className="container mx-auto px-4 py-8">
        <Card>
          <CardContent className="pt-6 text-center">
            <p className="text-neutral-400">Judge not found or not registered</p>
          </CardContent>
        </Card>
      </div>
    )
  }

  return (
    <div className="container mx-auto px-4 py-8">
      <div className="mb-8">
        <div className="flex items-center justify-between mb-4">
          <div>
            <h1 className="text-4xl font-bold mb-2">{formatAddress(profile.judgeAddress)}</h1>
            <div className="flex items-center gap-2 text-neutral-400">
              <Calendar className="h-4 w-4" />
              <span>Judge since {new Date(Number(profile.registrationTime) * 1000).toLocaleDateString()}</span>
            </div>
          </div>
          <Badge className={profile.isEligible ? "bg-green-500/20 text-green-400 border-0" : "bg-neutral-500/20 text-neutral-400 border-0"}>
            {profile.isEligible ? "ELIGIBLE" : "INACTIVE"}
          </Badge>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        <Card>
          <CardHeader>
            <CardTitle className="text-sm flex items-center gap-2">
              <Award className="h-4 w-4 text-orange-400" />
              Reputation
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-orange-400">{profile.reputationPercentage.toFixed(1)}%</div>
            <div className="text-xs text-neutral-400 mt-1">Score: {profile.reputationScore.toString()} / 10000</div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-sm flex items-center gap-2">
              <Shield className="h-4 w-4 text-cyan-400" />
              Staked Amount
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-cyan-400">{parseFloat(profile.stakedAmountFormatted).toFixed(2)}</div>
            <div className="text-xs text-neutral-400 mt-1">MNT</div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-sm flex items-center gap-2">
              <Scale className="h-4 w-4 text-purple-400" />
              Cases Judged
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold">{profile.casesJudged.toString()}</div>
            <div className="text-xs text-neutral-400 mt-1">Successful: {profile.successfulCases.toString()}</div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-sm flex items-center gap-2">
              <TrendingUp className="h-4 w-4 text-green-400" />
              Success Rate
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-green-400">{profile.successRate.toFixed(1)}%</div>
            <div className="text-xs text-neutral-400 mt-1">{profile.successfulCases.toString()} / {profile.casesJudged.toString()} cases</div>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}
