"use client"

import { useState } from "react"
import { ArrowLeft } from "lucide-react"
import Link from "next/link"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"

export default function PoolDetailsPage({ params }: { params: { id: string } }) {
  const [lockPeriod, setLockPeriod] = useState("flexible")
  const [depositAmount, setDepositAmount] = useState("")

  // Mock data
  const pool = {
    id: params.id,
    name: "Sports Pool - NBA",
    category: "sports",
    apy: 12.5,
    liquidity: 1200000,
    available: 800000,
    activeBets: 45,
    utilization: 33,
    totalVolume: 5000000,
    winRate: 52,
    description: "NBA basketball games and player performance bets",
  }

  const lockOptions = [
    { value: "flexible", label: "Flexible", boost: 0, desc: "Withdraw anytime" },
    { value: "30d", label: "30 Days", boost: 2, desc: "+2% APY boost" },
    { value: "90d", label: "90 Days", boost: 5, desc: "+5% APY boost" },
    { value: "365d", label: "365 Days", boost: 10, desc: "+10% APY boost" },
  ]

  const selectedLock = lockOptions.find((o) => o.value === lockPeriod)
  const totalAPY = pool.apy + (selectedLock?.boost || 0)

  return (
    <main className="pt-16 pb-20">
      <div className="max-w-6xl mx-auto px-6 py-12">
        {/* Back Button */}
        <Link href="/pools">
          <Button variant="ghost" className="mb-6">
            <ArrowLeft className="w-4 h-4 mr-2" />
            Back to Pools
          </Button>
        </Link>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Main Content */}
          <div className="lg:col-span-2 space-y-6">
            {/* Pool Overview */}
            <Card>
              <CardHeader>
                <div className="flex justify-between items-start">
                  <div>
                    <CardTitle className="text-2xl mb-3">{pool.name}</CardTitle>
                    <Badge className="bg-blue-500/20 text-blue-400 border-0">{pool.category}</Badge>
                  </div>
                  <div className="text-right">
                    <div className="text-4xl font-bold text-orange-500">{pool.apy.toFixed(1)}%</div>
                    <div className="text-xs text-neutral-400 uppercase">Base APY</div>
                  </div>
                </div>
              </CardHeader>
              <CardContent className="space-y-6">
                <p className="text-neutral-400">{pool.description}</p>

                {/* Stats Grid */}
                <div className="grid grid-cols-3 gap-4">
                  <div>
                    <div className="text-xs text-neutral-400 uppercase mb-1">Total Liquidity</div>
                    <div className="text-lg font-bold">${(pool.liquidity / 1000000).toFixed(1)}M</div>
                  </div>
                  <div>
                    <div className="text-xs text-neutral-400 uppercase mb-1">Available</div>
                    <div className="text-lg font-bold">${(pool.available / 1000000).toFixed(1)}M</div>
                  </div>
                  <div>
                    <div className="text-xs text-neutral-400 uppercase mb-1">Active Bets</div>
                    <div className="text-lg font-bold">{pool.activeBets}</div>
                  </div>
                  <div>
                    <div className="text-xs text-neutral-400 uppercase mb-1">Total Volume</div>
                    <div className="text-lg font-bold">${(pool.totalVolume / 1000000).toFixed(1)}M</div>
                  </div>
                  <div>
                    <div className="text-xs text-neutral-400 uppercase mb-1">Utilization</div>
                    <div className="text-lg font-bold">{pool.utilization}%</div>
                  </div>
                  <div>
                    <div className="text-xs text-neutral-400 uppercase mb-1">Win Rate</div>
                    <div className="text-lg font-bold">{pool.winRate}%</div>
                  </div>
                </div>

                {/* Risk Parameters */}
                <div className="bg-neutral-900 border border-neutral-700 rounded p-4">
                  <h4 className="font-bold uppercase text-sm mb-4">Risk Parameters</h4>
                  <div className="space-y-3 text-sm">
                    <div className="flex justify-between">
                      <span className="text-neutral-400">Tier:</span>
                      <Badge className="bg-yellow-500/20 text-yellow-400 border-0">Medium Risk</Badge>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-neutral-400">Min Deposit:</span>
                      <span>$10 USDC</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-neutral-400">Max Deposit:</span>
                      <span>$10,000 USDC</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-neutral-400">Lock Periods:</span>
                      <span>Flexible, 30d, 90d, 365d</span>
                    </div>
                  </div>
                </div>
              </CardContent>
            </Card>

            {/* Pool Activity */}
            <Card>
              <CardHeader>
                <CardTitle>Recent Activity</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="space-y-4 text-sm">
                  {[
                    { event: "User deposited", amount: "+$5,000", user: "user_123", time: "2 hours ago" },
                    { event: "Bet matched", amount: "-$250", user: "match_456", time: "4 hours ago" },
                    { event: "Bet settled", amount: "+$300", user: "settle_789", time: "6 hours ago" },
                    { event: "User withdrew", amount: "-$1,000", user: "user_234", time: "1 day ago" },
                  ].map((activity, idx) => (
                    <div
                      key={idx}
                      className="flex justify-between items-center pb-4 border-b border-neutral-700 last:border-0"
                    >
                      <div>
                        <div className="font-medium">{activity.event}</div>
                        <div className="text-xs text-neutral-500">{activity.user}</div>
                      </div>
                      <div className="text-right">
                        <div className="font-medium">{activity.amount}</div>
                        <div className="text-xs text-neutral-500">{activity.time}</div>
                      </div>
                    </div>
                  ))}
                </div>
              </CardContent>
            </Card>
          </div>

          {/* Sidebar */}
          <div className="space-y-6">
            {/* Deposit Card */}
            <Card>
              <CardHeader>
                <CardTitle className="text-lg">Deposit to Pool</CardTitle>
              </CardHeader>
              <CardContent className="space-y-6">
                {/* Lock Period Selector */}
                <div>
                  <label className="block text-xs font-bold uppercase mb-3">Lock Period</label>
                  <div className="space-y-2">
                    {lockOptions.map((option) => (
                      <div
                        key={option.value}
                        onClick={() => setLockPeriod(option.value)}
                        className={`p-3 rounded border cursor-pointer transition-all ${
                          lockPeriod === option.value
                            ? "border-orange-500 bg-orange-500/10"
                            : "border-neutral-700 hover:border-neutral-600"
                        }`}
                      >
                        <div className="font-bold text-sm mb-1">{option.label}</div>
                        <div className="text-xs text-neutral-400">{option.desc}</div>
                      </div>
                    ))}
                  </div>
                </div>

                {/* Amount Input */}
                <div className="border-t border-neutral-700 pt-4">
                  <label className="block text-xs font-bold uppercase mb-2">Deposit Amount (USDC)</label>
                  <Input
                    type="number"
                    placeholder="0.00"
                    value={depositAmount}
                    onChange={(e) => setDepositAmount(e.target.value)}
                    className="bg-neutral-800 border-neutral-700 mb-2"
                  />
                  <Button variant="ghost" size="sm" className="text-xs text-neutral-400">
                    Your balance: 5,000 USDC
                  </Button>
                </div>

                {/* Summary */}
                <div className="border-t border-neutral-700 pt-4 space-y-3 text-sm">
                  <div className="flex justify-between">
                    <span className="text-neutral-400">Your deposit:</span>
                    <span>{depositAmount || "0"} USDC</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-neutral-400">Base APY:</span>
                    <span>{pool.apy.toFixed(1)}%</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-neutral-400">Tier boost:</span>
                    <span>+{selectedLock?.boost || 0}%</span>
                  </div>
                  <div className="flex justify-between font-bold text-lg pt-3 border-t border-neutral-700">
                    <span>Total APY:</span>
                    <span className="text-orange-500">{totalAPY.toFixed(1)}%</span>
                  </div>
                  {depositAmount && (
                    <div className="text-xs text-neutral-400 pt-2">
                      Estimated earnings: ~${(Number(depositAmount) * (totalAPY / 100)).toFixed(2)}/year
                    </div>
                  )}
                </div>

                <Button className="w-full mt-4">Deposit USDC</Button>
              </CardContent>
            </Card>

            {/* Your Positions */}
            <Card>
              <CardHeader>
                <CardTitle className="text-lg">Your Positions</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="text-sm">
                  <div className="text-neutral-400 text-center py-6">No positions yet. Deposit to get started!</div>
                </div>
              </CardContent>
            </Card>
          </div>
        </div>
      </div>
    </main>
  )
}
