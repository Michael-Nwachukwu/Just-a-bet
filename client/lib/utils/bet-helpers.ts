/**
 * Format token amount from wei to human readable (for USDC with 6 decimals)
 */
function formatUSDC(amount: bigint): number {
  return Number(amount) / 1_000_000
}

export type BetStatus = "pending" | "active" | "awaiting_resolution" | "in_dispute" | "completed" | "cancelled"
export type BetOutcome = "pending" | "creator_wins" | "opponent_wins" | "draw"

export interface UIBet {
  id: string
  address: string
  description: string
  outcomeDescription: string
  status: BetStatus
  outcome: BetOutcome
  category: string
  creator: string
  opponent: string
  stake: number // in USDC (formatted)
  stakeAmount: bigint // raw value
  duration: string
  endDate: string
  tags: string[]
  createdAt: number
  expiresAt: number
  creatorFunded: boolean
  opponentFunded: boolean
  isHouseBet: boolean
}

/**
 * Map contract bet state to UI status
 */
export function mapBetState(state: number): BetStatus {
  switch (state) {
    case 0:
      return "pending" // Created
    case 1:
      return "active" // Active
    case 2:
      return "awaiting_resolution" // AwaitingResolution
    case 3:
      return "in_dispute" // InDispute
    case 4:
      return "completed" // Resolved
    case 5:
      return "cancelled" // Cancelled
    default:
      return "pending"
  }
}

/**
 * Map contract outcome to UI outcome
 */
export function mapBetOutcome(outcome: number): BetOutcome {
  switch (outcome) {
    case 0:
      return "pending"
    case 1:
      return "creator_wins"
    case 2:
      return "opponent_wins"
    case 3:
      return "draw"
    default:
      return "pending"
  }
}

/**
 * Derive category from tags
 */
export function deriveCategoryFromTags(tags: string[]): string {
  if (!tags || tags.length === 0) return "General"

  const categoryMap: Record<string, string> = {
    sports: "Sports",
    nba: "Sports",
    nfl: "Sports",
    soccer: "Sports",
    football: "Sports",
    basketball: "Sports",
    crypto: "Crypto",
    btc: "Crypto",
    bitcoin: "Crypto",
    eth: "Crypto",
    ethereum: "Crypto",
    politics: "Politics",
    election: "Politics",
    government: "Politics",
  }

  const tag = tags[0]?.toLowerCase()
  return categoryMap[tag] || "General"
}

/**
 * Format duration in seconds to human readable string
 */
export function formatDuration(seconds: number): string {
  const days = Math.floor(seconds / 86400)
  const hours = Math.floor((seconds % 86400) / 3600)
  const minutes = Math.floor((seconds % 3600) / 60)

  if (days > 0) {
    return `${days}d ${hours}h`
  } else if (hours > 0) {
    return `${hours}h ${minutes}m`
  } else {
    return `${minutes}m`
  }
}

/**
 * Transform contract bet data to UI format
 */
export function transformBetData(contractData: {
  address: string
  creator: string
  opponent: string
  stakeAmount: bigint
  description: string
  outcomeDescription: string
  createdAt: bigint
  expiresAt: bigint
  state: number
  outcome: number
  creatorFunded: boolean
  opponentFunded: boolean
  tags: string[]
}): UIBet {
  const duration = Number(contractData.expiresAt - contractData.createdAt)
  const isHouseBet = contractData.opponent === "0x0000000000000000000000000000000000000000"

  return {
    id: contractData.address,
    address: contractData.address,
    description: contractData.description,
    outcomeDescription: contractData.outcomeDescription,
    status: mapBetState(contractData.state),
    outcome: mapBetOutcome(contractData.outcome),
    category: deriveCategoryFromTags(contractData.tags),
    creator: contractData.creator,
    opponent: contractData.opponent,
    stake: formatUSDC(contractData.stakeAmount),
    stakeAmount: contractData.stakeAmount,
    duration: formatDuration(duration),
    endDate: new Date(Number(contractData.expiresAt) * 1000).toISOString(),
    tags: contractData.tags,
    createdAt: Number(contractData.createdAt),
    expiresAt: Number(contractData.expiresAt),
    creatorFunded: contractData.creatorFunded,
    opponentFunded: contractData.opponentFunded,
    isHouseBet,
  }
}

/**
 * Check if user won the bet
 */
export function didUserWin(bet: UIBet, userAddress: string): boolean {
  if (bet.outcome === "draw") return false
  if (bet.outcome === "creator_wins" && bet.creator.toLowerCase() === userAddress.toLowerCase()) return true
  if (bet.outcome === "opponent_wins" && bet.opponent.toLowerCase() === userAddress.toLowerCase()) return true
  return false
}

/**
 * Get most common category from bets
 */
export function getMostCommonCategory(bets: UIBet[]): string {
  if (!bets || bets.length === 0) return "None"

  const categoryCounts: Record<string, number> = {}
  bets.forEach((bet) => {
    categoryCounts[bet.category] = (categoryCounts[bet.category] || 0) + 1
  })

  let maxCount = 0
  let mostCommon = "None"
  Object.entries(categoryCounts).forEach(([category, count]) => {
    if (count > maxCount) {
      maxCount = count
      mostCommon = category
    }
  })

  return mostCommon
}

/**
 * Calculate time remaining until expiry
 */
export function getTimeRemaining(expiresAt: number): {
  expired: boolean
  days: number
  hours: number
  minutes: number
  seconds: number
  formatted: string
} {
  const now = Math.floor(Date.now() / 1000)
  const diff = expiresAt - now

  if (diff <= 0) {
    return {
      expired: true,
      days: 0,
      hours: 0,
      minutes: 0,
      seconds: 0,
      formatted: "Expired",
    }
  }

  const days = Math.floor(diff / 86400)
  const hours = Math.floor((diff % 86400) / 3600)
  const minutes = Math.floor((diff % 3600) / 60)
  const seconds = diff % 60

  let formatted = ""
  if (days > 0) {
    formatted = `${days}d ${hours}h`
  } else if (hours > 0) {
    formatted = `${hours}h ${minutes}m`
  } else if (minutes > 0) {
    formatted = `${minutes}m`
  } else {
    formatted = `${seconds}s`
  }

  return {
    expired: false,
    days,
    hours,
    minutes,
    seconds,
    formatted,
  }
}

/**
 * Parse contract error to user-friendly message
 */
export function parseContractError(error: Error): string {
  const message = error.message || ""

  if (message.includes("InsufficientAllowance")) {
    return "Please approve USDC spending first"
  }
  if (message.includes("InsufficientBalance")) {
    return "Insufficient USDC balance"
  }
  if (message.includes("BetNotFound")) {
    return "Bet not found"
  }
  if (message.includes("NotCreator")) {
    return "Only the creator can perform this action"
  }
  if (message.includes("NotOpponent")) {
    return "Only the opponent can perform this action"
  }
  if (message.includes("BetExpired")) {
    return "This bet has expired"
  }
  if (message.includes("BetNotActive")) {
    return "This bet is not active"
  }
  if (message.includes("AlreadyFunded")) {
    return "You have already funded your stake"
  }
  if (message.includes("InvalidState")) {
    return "Invalid bet state for this action"
  }
  if (message.includes("user rejected")) {
    return "Transaction was rejected"
  }

  return "Transaction failed. Please try again."
}
