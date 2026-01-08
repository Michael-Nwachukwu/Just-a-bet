import { useQuery } from "@tanstack/react-query"
import { useUserBets } from "./useBets"
import { transformBetData, didUserWin, getMostCommonCategory, type UIBet } from "../utils/bet-helpers"

/**
 * Hook to calculate user stats from bet history
 */
export function useUserStats(userAddress?: string) {
  const { bets, isLoading: isBetsLoading } = useUserBets(userAddress)

  return useQuery({
    queryKey: ["userStats", userAddress, bets?.length],
    queryFn: () => {
      if (!bets || !userAddress) return null

      // Transform bets to UI format
      const uiBets = bets.map(transformBetData)

      // Filter by status
      const activeBets = uiBets.filter((b) => b.status === "active")
      const completedBets = uiBets.filter((b) => b.status === "completed")
      const pendingBets = uiBets.filter((b) => b.status === "pending")
      const inDisputeBets = uiBets.filter((b) => b.status === "in_dispute")

      // Calculate win stats
      const wonBets = completedBets.filter((b) => didUserWin(b, userAddress))
      const lostBets = completedBets.filter((b) => {
        if (b.outcome === "draw") return false
        return !didUserWin(b, userAddress)
      })
      const drawBets = completedBets.filter((b) => b.outcome === "draw")

      // Calculate volumes
      const totalVolume = uiBets.reduce((sum, b) => sum + b.stake, 0)
      const totalWinnings = wonBets.reduce((sum, b) => sum + b.stake * 2, 0) // Winner gets both stakes
      const totalLost = lostBets.reduce((sum, b) => sum + b.stake, 0)
      const netProfit = totalWinnings - totalLost

      // Calculate win rate
      const winRate = completedBets.length > 0 ? (wonBets.length / completedBets.length) * 100 : 0

      // Get favorite category
      const favoriteCategory = getMostCommonCategory(uiBets)

      // Calculate average bet size
      const averageBetSize = uiBets.length > 0 ? totalVolume / uiBets.length : 0

      // Get biggest win/loss
      const biggestWin = wonBets.length > 0 ? Math.max(...wonBets.map((b) => b.stake * 2)) : 0
      const biggestLoss = lostBets.length > 0 ? Math.max(...lostBets.map((b) => b.stake)) : 0

      return {
        // Counts
        totalBetsCreated: uiBets.length,
        activeBets: activeBets.length,
        completedBets: completedBets.length,
        pendingBets: pendingBets.length,
        inDisputeBets: inDisputeBets.length,
        wonBets: wonBets.length,
        lostBets: lostBets.length,
        drawBets: drawBets.length,

        // Percentages
        winRate,

        // Volumes
        totalVolume,
        totalWinnings,
        totalLost,
        netProfit,
        averageBetSize,
        biggestWin,
        biggestLoss,

        // Categories
        favoriteCategory,

        // House vs P2P stats
        houseBets: uiBets.filter((b) => b.isHouseBet).length,
        p2pBets: uiBets.filter((b) => !b.isHouseBet).length,
      }
    },
    enabled: !isBetsLoading && !!bets && !!userAddress,
    staleTime: 30000,
  })
}

/**
 * Hook to get leaderboard stats (simplified version)
 */
export function useLeaderboardStats() {
  // For now, just return placeholder
  // In production, this would fetch from a backend that indexes all users
  return useQuery({
    queryKey: ["leaderboard"],
    queryFn: async () => {
      return {
        topWinners: [],
        topVolume: [],
        topWinRate: [],
      }
    },
    staleTime: 300000, // 5 minutes
  })
}
