"use client"

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Trophy, Clock, DollarSign } from "lucide-react"
import { useClaimWinnings } from "@/lib/hooks/useBetActions"
import { toast } from "sonner"

interface ClaimWinningsCardProps {
  betAddress: string
  stakeAmount: number
  outcome: string
  onSuccess?: () => void
}

export function ClaimWinningsCard({
  betAddress,
  stakeAmount,
  outcome,
  onSuccess,
}: ClaimWinningsCardProps) {
  const { claimWinnings, isPending } = useClaimWinnings(betAddress)

  const totalWinnings = stakeAmount * 2

  const handleClaim = () => {
    const toastId = toast.loading("Claiming winnings...")

    claimWinnings({
      onSuccess: () => {
        toast.success(`${totalWinnings} USDC claimed successfully!`, { id: toastId })
        onSuccess?.()
      },
      onError: (error) => {
        console.error("Claim winnings error:", error)
        toast.error("Failed to claim winnings. Please try again.", { id: toastId })
      }
    })
  }

  return (
    <Card className="border-green-500/50">
      <CardHeader>
        <div className="flex items-center gap-2">
          <Trophy className="h-5 w-5 text-green-400" />
          <CardTitle className="text-lg text-green-400">You Won!</CardTitle>
        </div>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="bg-green-500/10 border border-green-500/30 rounded-lg p-6 text-center">
          <div className="mb-2">
            <DollarSign className="h-8 w-8 text-green-400 mx-auto mb-3" />
            <div className="text-4xl font-bold text-green-400 mb-1">
              {totalWinnings} USDC
            </div>
            <div className="text-sm text-green-300/80">
              Your Winnings
            </div>
          </div>
        </div>

        <div className="bg-neutral-900 border border-neutral-700 rounded-lg p-4 space-y-2 text-sm">
          <div className="flex justify-between">
            <span className="text-neutral-400">Your Stake</span>
            <span className="font-medium">{stakeAmount} USDC</span>
          </div>
          <div className="flex justify-between">
            <span className="text-neutral-400">Opponent's Stake</span>
            <span className="font-medium">{stakeAmount} USDC</span>
          </div>
          <div className="border-t border-neutral-700 pt-2 flex justify-between font-bold">
            <span>Total Payout</span>
            <span className="text-green-400">{totalWinnings} USDC</span>
          </div>
        </div>

        <Button
          className="w-full bg-green-600 hover:bg-green-700"
          onClick={handleClaim}
          disabled={isPending}
        >
          {isPending ? (
            <>
              <Clock className="mr-2 h-4 w-4 animate-spin" />
              Claiming Winnings...
            </>
          ) : (
            <>
              <Trophy className="mr-2 h-4 w-4" />
              Claim {totalWinnings} USDC
            </>
          )}
        </Button>

        <p className="text-xs text-neutral-500 text-center">
          Winnings will be sent to your wallet
        </p>
      </CardContent>
    </Card>
  )
}
