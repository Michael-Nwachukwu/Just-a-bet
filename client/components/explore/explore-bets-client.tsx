"use client"

import { useState } from "react"
import { Search } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import BetCard from "@/components/bets/bet-card"

// Mock data
const mockBets = [
  {
    id: "1",
    description: "Lakers will beat Celtics in tonight's game",
    status: "active" as const,
    category: "sports",
    creator: "john_doe",
    opponent: "jane_smith",
    stake: 100,
    duration: "1 day",
    endDate: "Jan 15, 2024",
  },
  {
    id: "2",
    description: "Bitcoin will reach $50k by end of month",
    status: "pending" as const,
    category: "crypto",
    creator: "crypto_king",
    opponent: undefined,
    stake: 500,
    duration: "30 days",
    endDate: "Feb 1, 2024",
  },
  {
    id: "3",
    description: "Who will win the 2024 NBA Finals?",
    status: "active" as const,
    category: "sports",
    creator: "sports_fan",
    opponent: "game_master",
    stake: 250,
    duration: "7 days",
    endDate: "Jan 22, 2024",
  },
  {
    id: "4",
    description: "Ethereum will outperform Bitcoin this quarter",
    status: "completed" as const,
    category: "crypto",
    creator: "eth_believer",
    opponent: "btc_maximalist",
    stake: 1000,
    duration: "90 days",
    endDate: "Dec 15, 2023",
  },
]

export default function ExploreBetsClient() {
  const [searchTerm, setSearchTerm] = useState("")
  const [statusFilter, setStatusFilter] = useState("all")
  const [categoryFilter, setCategoryFilter] = useState("all")
  const [sortBy, setSortBy] = useState("newest")

  const filteredBets = mockBets.filter((bet) => {
    const matchesSearch = bet.description.toLowerCase().includes(searchTerm.toLowerCase())
    const matchesStatus = statusFilter === "all" || bet.status === statusFilter
    const matchesCategory = categoryFilter === "all" || bet.category === categoryFilter
    return matchesSearch && matchesStatus && matchesCategory
  })

  return (
    <main className="pt-16 pb-20">
      <div className="max-w-7xl mx-auto px-6 py-12">
        {/* Page Header */}
        <div className="mb-8">
          <h1 className="text-4xl font-bold mb-2 uppercase">
            <span className="text-orange-500">EXPLORE</span> BETS
          </h1>
          <p className="text-neutral-400">Browse all active and pending bets on the platform</p>
        </div>

        {/* Filters Bar */}
        <div className="bg-neutral-900 border border-orange-500/20 rounded-lg p-4 mb-8 space-y-4">
          {/* Search */}
          <div className="relative">
            <Search className="absolute left-3 top-3 w-4 h-4 text-neutral-500" />
            <Input
              type="text"
              placeholder="Search bets..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="pl-10 bg-neutral-800 border-neutral-700"
            />
          </div>

          {/* Filter Controls */}
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            {/* Status Filter */}
            <Select value={statusFilter} onValueChange={setStatusFilter}>
              <SelectTrigger className="bg-neutral-800 border-neutral-700">
                <SelectValue placeholder="All Status" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All Status</SelectItem>
                <SelectItem value="pending">Pending</SelectItem>
                <SelectItem value="active">Active</SelectItem>
                <SelectItem value="completed">Completed</SelectItem>
              </SelectContent>
            </Select>

            {/* Category Filter */}
            <Select value={categoryFilter} onValueChange={setCategoryFilter}>
              <SelectTrigger className="bg-neutral-800 border-neutral-700">
                <SelectValue placeholder="All Categories" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All Categories</SelectItem>
                <SelectItem value="sports">Sports</SelectItem>
                <SelectItem value="crypto">Crypto</SelectItem>
                <SelectItem value="politics">Politics</SelectItem>
                <SelectItem value="entertainment">Entertainment</SelectItem>
              </SelectContent>
            </Select>

            {/* Sort By */}
            <Select value={sortBy} onValueChange={setSortBy}>
              <SelectTrigger className="bg-neutral-800 border-neutral-700">
                <SelectValue placeholder="Sort By" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="newest">Newest</SelectItem>
                <SelectItem value="highest-stake">Highest Stake</SelectItem>
                <SelectItem value="ending-soon">Ending Soon</SelectItem>
              </SelectContent>
            </Select>
          </div>
        </div>

        {/* Bets Grid */}
        {filteredBets.length > 0 ? (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {filteredBets.map((bet) => (
              <BetCard key={bet.id} {...bet} />
            ))}
          </div>
        ) : (
          <div className="text-center py-12">
            <Search className="w-12 h-12 text-neutral-600 mx-auto mb-4" />
            <h3 className="text-xl font-bold mb-2">No bets found</h3>
            <p className="text-neutral-400 mb-6">Try adjusting your filters</p>
            <Button
              variant="outline"
              onClick={() => {
                setSearchTerm("")
                setStatusFilter("all")
                setCategoryFilter("all")
              }}
            >
              Clear Filters
            </Button>
          </div>
        )}
      </div>
    </main>
  )
}
