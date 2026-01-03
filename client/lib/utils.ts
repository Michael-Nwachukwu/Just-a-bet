import { clsx, type ClassValue } from "clsx"
import { twMerge } from "tailwind-merge"
import { formatUnits, parseUnits } from "viem"

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

/**
 * Format USDC amount from wei to human readable (6 decimals)
 */
export function formatUSDC(amount: bigint | undefined): string {
  if (!amount) return "0"
  return formatUnits(amount, 6)
}

/**
 * Parse USDC amount from human readable to wei (6 decimals)
 */
export function parseUSDC(amount: string): bigint {
  return parseUnits(amount, 6)
}

/**
 * Convert duration from hours/days/weeks to seconds
 */
export function durationToSeconds(
  duration: number,
  unit: "hours" | "days" | "weeks"
): number {
  const multipliers = {
    hours: 3600,
    days: 86400,
    weeks: 604800,
  }
  return duration * multipliers[unit]
}

/**
 * Format seconds to human readable duration
 */
export function formatDuration(seconds: number): string {
  const weeks = Math.floor(seconds / 604800)
  if (weeks > 0) return `${weeks} week${weeks > 1 ? "s" : ""}`

  const days = Math.floor(seconds / 86400)
  if (days > 0) return `${days} day${days > 1 ? "s" : ""}`

  const hours = Math.floor(seconds / 3600)
  if (hours > 0) return `${hours} hour${hours > 1 ? "s" : ""}`

  const minutes = Math.floor(seconds / 60)
  return `${minutes} minute${minutes > 1 ? "s" : ""}`
}

/**
 * Format address to short form
 */
export function formatAddress(address: string): string {
  return `${address.slice(0, 6)}...${address.slice(-4)}`
}
