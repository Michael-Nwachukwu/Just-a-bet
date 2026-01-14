"use client"

import { useState, useMemo } from "react"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Card, CardContent } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { RefreshCw, Loader2 } from "lucide-react"
import BetCard from "@/components/bets/bet-card"
import { useActiveAccount } from "thirdweb/react"
import { useUserBets } from "@/lib/hooks/useBets"
import { transformBetData, didUserWin } from "@/lib/utils/bet-helpers"

export default function MyBetsPage() {
  const [wonFilter, setWonFilter] = useState("all")
  const account = useActiveAccount()
  const { bets, isLoading, refetch } = useUserBets(account?.address)

  // Transform and categorize bets
  const { activeBets, pendingBets, completedBets, awaitingResolutionBets, inDisputeBets } = useMemo(() => {
    if (!bets) return { activeBets: [], pendingBets: [], completedBets: [], awaitingResolutionBets: [], inDisputeBets: [] }

    const transformed = bets.map(transformBetData)

    return {
      activeBets: transformed.filter(b => b.status === "active"),
      pendingBets: transformed.filter(b => b.status === "pending"),
      completedBets: transformed.filter(b => b.status === "completed"),
      awaitingResolutionBets: transformed.filter(b => b.status === "awaiting_resolution"),
      inDisputeBets: transformed.filter(b => b.status === "in_dispute"),
    }
  }, [bets])

  // Filter completed bets by won/lost
  const filteredCompletedBets = useMemo(() => {
    if (!account?.address) return completedBets

    if (wonFilter === "won") {
      return completedBets.filter(bet => didUserWin(bet, account.address))
    } else if (wonFilter === "lost") {
      return completedBets.filter(bet => !didUserWin(bet, account.address) && bet.outcome !== "draw")
    }
    return completedBets
  }, [completedBets, wonFilter, account?.address])

  // Check if wallet is connected
  if (!account) {
    return (
      <main className="pt-16 pb-20">
        <div className="max-w-6xl mx-auto px-6 py-12">
          <Card className="text-center py-12">
            <CardContent>
              <h3 className="text-xl font-bold mb-2">Connect Wallet</h3>
              <p className="text-neutral-400">Please connect your wallet to view your bets</p>
            </CardContent>
          </Card>
        </div>
      </main>
    )
  }

  return (
    <main className="pt-16 pb-20">
      <div className="max-w-6xl mx-auto px-6 py-12">
        {/* Header */}
        <div className="flex items-center justify-between mb-8">
          <h1 className="text-4xl font-bold uppercase">
            <span className="text-orange-500">MY</span> BETS
          </h1>
          <Button
            variant="outline"
            size="sm"
            onClick={() => refetch()}
            disabled={isLoading}
          >
            <RefreshCw className={`w-4 h-4 mr-2 ${isLoading ? "animate-spin" : ""}`} />
            Refresh
          </Button>
        </div>

        {/* Tabs */}
        <Tabs defaultValue="active" className="w-full">
          <TabsList className="w-full justify-start bg-transparent border-b border-neutral-700 h-auto p-0 rounded-none">
            {[
              { value: "active", label: "Active", count: activeBets.length },
              { value: "pending", label: "Pending", count: pendingBets.length },
              { value: "awaiting", label: "Awaiting Resolution", count: awaitingResolutionBets.length },
              { value: "dispute", label: "In Dispute", count: inDisputeBets.length },
              { value: "completed", label: "Completed", count: completedBets.length },
            ].map((tab) => (
              <TabsTrigger
                key={tab.value}
                value={tab.value}
                className="data-[state=active]:border-b-2 data-[state=active]:border-orange-500 rounded-none border-0 bg-transparent"
              >
                {tab.label} ({tab.count})
              </TabsTrigger>
            ))}
          </TabsList>

          {/* Active Bets */}
          <TabsContent value="active" className="mt-8">
            {isLoading ? (
              <LoadingGrid />
            ) : activeBets.length > 0 ? (
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                {activeBets.map((bet) => (
                  <BetCard key={bet.id} {...bet} />
                ))}
              </div>
            ) : (
              <EmptyState label="active" />
            )}
          </TabsContent>

          {/* Pending Bets */}
          <TabsContent value="pending" className="mt-8">
            {isLoading ? (
              <LoadingGrid />
            ) : pendingBets.length > 0 ? (
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                {pendingBets.map((bet) => (
                  <BetCard key={bet.id} {...bet} />
                ))}
              </div>
            ) : (
              <EmptyState label="pending" />
            )}
          </TabsContent>

          {/* Awaiting Resolution Bets */}
          <TabsContent value="awaiting" className="mt-8">
            {isLoading ? (
              <LoadingGrid />
            ) : awaitingResolutionBets.length > 0 ? (
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                {awaitingResolutionBets.map((bet) => (
                  <BetCard key={bet.id} {...bet} />
                ))}
              </div>
            ) : (
              <EmptyState label="awaiting" />
            )}
          </TabsContent>

          {/* In Dispute Bets */}
          <TabsContent value="dispute" className="mt-8">
            {isLoading ? (
              <LoadingGrid />
            ) : inDisputeBets.length > 0 ? (
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                {inDisputeBets.map((bet) => (
                  <BetCard key={bet.id} {...bet} />
                ))}
              </div>
            ) : (
              <EmptyState label="dispute" />
            )}
          </TabsContent>

          {/* Completed Bets */}
          <TabsContent value="completed" className="mt-8">
            <div className="mb-6 flex gap-2">
              {[
                { value: "all", label: "All" },
                { value: "won", label: "Won" },
                { value: "lost", label: "Lost" },
              ].map((filter) => (
                <Badge
                  key={filter.value}
                  className={`cursor-pointer transition-all ${wonFilter === filter.value
                      ? "bg-orange-500 text-black border-0"
                      : "bg-neutral-800 text-neutral-400 border border-neutral-700"
                    }`}
                  onClick={() => setWonFilter(filter.value)}
                >
                  {filter.label}
                </Badge>
              ))}
            </div>

            {isLoading ? (
              <LoadingGrid />
            ) : filteredCompletedBets.length > 0 ? (
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                {filteredCompletedBets.map((bet) => (
                  <BetCard key={bet.id} {...bet} />
                ))}
              </div>
            ) : (
              <EmptyState label="completed" />
            )}
          </TabsContent>
        </Tabs>
      </div>
    </main>
  )
}

function LoadingGrid() {
  return (
    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
      {Array.from({ length: 3 }).map((_, i) => (
        <div key={i} className="bg-neutral-900 border border-orange-500/20 rounded-lg p-6 animate-pulse">
          <div className="h-4 bg-neutral-700 rounded w-3/4 mb-4"></div>
          <div className="h-4 bg-neutral-700 rounded w-1/2 mb-4"></div>
          <div className="h-4 bg-neutral-700 rounded w-2/3"></div>
        </div>
      ))}
    </div>
  )
}

function EmptyState({ label }: { label: string }) {
  const messages = {
    active: { icon: "⚡", text: "No active bets" },
    pending: { icon: "⏳", text: "No pending bets" },
    awaiting: { icon: "⏰", text: "No bets awaiting resolution" },
    dispute: { icon: "⚖", text: "No bets in dispute" },
    completed: { icon: "✓", text: "No completed bets" },
  }
  const msg = messages[label as keyof typeof messages]

  return (
    <Card className="text-center py-12">
      <CardContent>
        <div className="text-4xl mb-3">{msg.icon}</div>
        <h3 className="text-lg font-bold mb-2">{msg.text}</h3>
        <p className="text-neutral-400 text-sm">No bets match this filter</p>
      </CardContent>
    </Card>
  )
}
