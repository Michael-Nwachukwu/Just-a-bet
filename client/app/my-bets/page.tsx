"use client"

import { useState } from "react"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Card, CardContent } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import BetCard from "@/components/bets/bet-card"

const mockMyBets = {
  active: [
    {
      id: "1",
      description: "Lakers will beat Celtics in tonight's game",
      status: "active" as const,
      category: "sports",
      creator: "you",
      opponent: "jane_smith",
      stake: 100,
      duration: "1 day",
      endDate: "Jan 15, 2024",
    },
    {
      id: "3",
      description: "Who will win the 2024 NBA Finals?",
      status: "active" as const,
      category: "sports",
      creator: "sports_fan",
      opponent: "you",
      stake: 250,
      duration: "7 days",
      endDate: "Jan 22, 2024",
    },
  ],
  pending: [
    {
      id: "2",
      description: "Bitcoin will reach $50k by end of month",
      status: "pending" as const,
      category: "crypto",
      creator: "you",
      opponent: undefined,
      stake: 500,
      duration: "30 days",
      endDate: "Feb 1, 2024",
    },
  ],
  completed: [
    {
      id: "4",
      description: "Ethereum will outperform Bitcoin this quarter",
      status: "completed" as const,
      category: "crypto",
      creator: "you",
      opponent: "btc_maximalist",
      stake: 1000,
      duration: "90 days",
      endDate: "Dec 15, 2023",
    },
  ],
}

export default function MyBetsPage() {
  const [wonFilter, setWonFilter] = useState("all")

  return (
    <main className="pt-16 pb-20">
      <div className="max-w-6xl mx-auto px-6 py-12">
        {/* Header */}
        <h1 className="text-4xl font-bold mb-8 uppercase">
          <span className="text-orange-500">MY</span> BETS
        </h1>

        {/* Tabs */}
        <Tabs defaultValue="active" className="w-full">
          <TabsList className="w-full justify-start bg-transparent border-b border-neutral-700 h-auto p-0 rounded-none">
            {[
              { value: "active", label: "Active", count: mockMyBets.active.length },
              { value: "pending", label: "Pending", count: mockMyBets.pending.length },
              { value: "completed", label: "Completed", count: mockMyBets.completed.length },
              { value: "judge", label: "As Judge", count: 0 },
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
            {mockMyBets.active.length > 0 ? (
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                {mockMyBets.active.map((bet) => (
                  <BetCard key={bet.id} {...bet} />
                ))}
              </div>
            ) : (
              <EmptyState label="active" />
            )}
          </TabsContent>

          {/* Pending Bets */}
          <TabsContent value="pending" className="mt-8">
            {mockMyBets.pending.length > 0 ? (
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                {mockMyBets.pending.map((bet) => (
                  <BetCard key={bet.id} {...bet} />
                ))}
              </div>
            ) : (
              <EmptyState label="pending" />
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
                  className={`cursor-pointer transition-all ${
                    wonFilter === filter.value
                      ? "bg-orange-500 text-black border-0"
                      : "bg-neutral-800 text-neutral-400 border border-neutral-700"
                  }`}
                  onClick={() => setWonFilter(filter.value)}
                >
                  {filter.label}
                </Badge>
              ))}
            </div>

            {mockMyBets.completed.length > 0 ? (
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                {mockMyBets.completed.map((bet) => (
                  <BetCard key={bet.id} {...bet} />
                ))}
              </div>
            ) : (
              <EmptyState label="completed" />
            )}
          </TabsContent>

          {/* As Judge */}
          <TabsContent value="judge" className="mt-8">
            <EmptyState label="judge" />
          </TabsContent>
        </Tabs>
      </div>
    </main>
  )
}

function EmptyState({ label }: { label: string }) {
  const messages = {
    active: { icon: "⚡", text: "No active bets" },
    pending: { icon: "⏳", text: "No pending bets" },
    completed: { icon: "✓", text: "No completed bets" },
    judge: { icon: "⚖", text: "No judge positions" },
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
