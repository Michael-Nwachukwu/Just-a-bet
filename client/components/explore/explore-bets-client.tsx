"use client"

import { useState, useMemo } from "react"
import { Search, RefreshCw, Loader2 } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import BetCard from "@/components/bets/bet-card"
import { useAllBetAddresses, useBatchBetDetails } from "@/lib/hooks/useBets"
import { transformBetData } from "@/lib/utils/bet-helpers"

export default function ExploreBetsClient() {
  const [searchTerm, setSearchTerm] = useState("")
  const [statusFilter, setStatusFilter] = useState("all")
  const [categoryFilter, setCategoryFilter] = useState("all")
  const [sortBy, setSortBy] = useState("newest")
  const [page, setPage] = useState(0)
  const pageSize = 20

  // Fetch all bet addresses
  const { data: allAddresses, isLoading: isLoadingAddresses, refetch: refetchAddresses } = useAllBetAddresses()

  // Paginate addresses
  const paginatedAddresses = useMemo(() => {
    if (!allAddresses) return []
    return allAddresses.slice(page * pageSize, (page + 1) * pageSize)
  }, [allAddresses, page])

  // Fetch bet details for current page
  const { data: bets, isLoading: isLoadingBets, refetch: refetchBets } = useBatchBetDetails(paginatedAddresses)

  const isLoading = isLoadingAddresses || isLoadingBets

  // Transform and filter bets
  const filteredBets = useMemo(() => {
    if (!bets) return []

    const transformed = bets.map(transformBetData)

    return transformed.filter((bet) => {
      const matchesSearch = bet.description.toLowerCase().includes(searchTerm.toLowerCase())
      const matchesStatus = statusFilter === "all" || bet.status === statusFilter
      const matchesCategory = categoryFilter === "all" || bet.category.toLowerCase() === categoryFilter.toLowerCase()
      return matchesSearch && matchesStatus && matchesCategory
    })
  }, [bets, searchTerm, statusFilter, categoryFilter])

  // Sort bets
  const sortedBets = useMemo(() => {
    const sorted = [...filteredBets]

    switch (sortBy) {
      case "newest":
        sorted.sort((a, b) => b.createdAt - a.createdAt)
        break
      case "highest-stake":
        sorted.sort((a, b) => b.stake - a.stake)
        break
      case "ending-soon":
        sorted.sort((a, b) => a.expiresAt - b.expiresAt)
        break
    }

    return sorted
  }, [filteredBets, sortBy])

  const handleRefresh = () => {
    refetchAddresses()
    refetchBets()
  }

  const totalPages = allAddresses ? Math.ceil(allAddresses.length / pageSize) : 0
  const hasNextPage = page < totalPages - 1
  const hasPrevPage = page > 0

  return (
    <main className="pt-16 pb-20">
      <div className="max-w-7xl mx-auto px-6 py-12">
        {/* Page Header */}
        <div className="mb-8 flex items-center justify-between">
          <div>
            <h1 className="text-4xl font-bold mb-2 uppercase">
              <span className="text-orange-500">EXPLORE</span> BETS
            </h1>
            <p className="text-neutral-400">
              Browse all active and pending bets on the platform {allAddresses && `(${allAddresses.length} total)`}
            </p>
          </div>
          <Button
            variant="outline"
            size="sm"
            onClick={handleRefresh}
            disabled={isLoading}
          >
            <RefreshCw className={`w-4 h-4 mr-2 ${isLoading ? "animate-spin" : ""}`} />
            Refresh
          </Button>
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
              <SelectTrigger className="bg-neutral-800 border-neutral-700 w-full">
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
              <SelectTrigger className="bg-neutral-800 border-neutral-700 w-full">
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
              <SelectTrigger className="bg-neutral-800 border-neutral-700 w-full">
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
        {isLoading ? (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {Array.from({ length: 6 }).map((_, i) => (
              <div key={i} className="bg-neutral-900 border border-orange-500/20 rounded-lg p-6 animate-pulse">
                <div className="h-4 bg-neutral-700 rounded w-3/4 mb-4"></div>
                <div className="h-4 bg-neutral-700 rounded w-1/2 mb-4"></div>
                <div className="h-4 bg-neutral-700 rounded w-2/3"></div>
              </div>
            ))}
          </div>
        ) : sortedBets.length > 0 ? (
          <>
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              {sortedBets.map((bet) => (
                <BetCard key={bet.id} {...bet} />
              ))}
            </div>

            {/* Pagination */}
            {totalPages > 1 && (
              <div className="flex items-center justify-center gap-4 mt-8">
                <Button
                  variant="outline"
                  onClick={() => setPage((p) => Math.max(0, p - 1))}
                  disabled={!hasPrevPage || isLoading}
                >
                  Previous
                </Button>
                <span className="text-sm text-neutral-400">
                  Page {page + 1} of {totalPages}
                </span>
                <Button
                  variant="outline"
                  onClick={() => setPage((p) => p + 1)}
                  disabled={!hasNextPage || isLoading}
                >
                  Next
                </Button>
              </div>
            )}
          </>
        ) : (
          <div className="text-center py-12">
            <Search className="w-12 h-12 text-neutral-600 mx-auto mb-4" />
            <h3 className="text-xl font-bold mb-2">
              {allAddresses?.length === 0 ? "No bets yet" : "No bets found"}
            </h3>
            <p className="text-neutral-400 mb-6">
              {allAddresses?.length === 0
                ? "Be the first to create a bet!"
                : "Try adjusting your filters"}
            </p>
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
