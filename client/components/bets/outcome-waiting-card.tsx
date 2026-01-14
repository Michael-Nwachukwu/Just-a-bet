"use client"

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Clock, CheckCircle } from "lucide-react"
import { useFinalizeResolution } from "@/lib/hooks/useBetActions"
import { toast } from "sonner"

interface OutcomeWaitingCardProps {
  betAddress: string
  declaredOutcome: string
  disputeDeadline: number
  onSuccess?: () => void
}

export function OutcomeWaitingCard({
  betAddress,
  declaredOutcome,
  disputeDeadline,
  onSuccess,
}: OutcomeWaitingCardProps) {
  const { finalizeResolution, isPending } = useFinalizeResolution(betAddress)

  const handleFinalize = () => {
    const toastId = toast.loading("Finalizing bet resolution...")

    finalizeResolution({
      onSuccess: () => {
        toast.success("Bet resolved! Winner can now claim their winnings.", { id: toastId })
        onSuccess?.()
      },
      onError: (error) => {
        console.error("Finalize resolution error:", error)
        toast.error("Failed to finalize resolution. Please try again.", { id: toastId })
      }
    })
  }
  const timeRemaining = disputeDeadline - Math.floor(Date.now() / 1000)
  const hoursRemaining = Math.floor(timeRemaining / 3600)
  const minutesRemaining = Math.floor((timeRemaining % 3600) / 60)
  const isExpired = timeRemaining <= 0

  const outcomeLabels: Record<string, string> = {
    "1": "You Won",
    "2": "Opponent Won",
    "3": "Draw",
    CreatorWins: "You Won",
    OpponentWins: "Opponent Won",
    Draw: "Draw",
  }

  return (
    <Card className="border-blue-500/50">
      <CardHeader>
        <div className="flex items-start justify-between">
          <CardTitle className="text-lg">Outcome Declared</CardTitle>
          {!isExpired && (
            <Badge className="bg-orange-500/20 text-orange-400 border-0">
              <Clock className="w-3 h-3 mr-1" />
              {hoursRemaining}h {minutesRemaining}m left
            </Badge>
          )}
        </div>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="bg-green-500/10 border border-green-500/30 rounded-lg p-4">
          <div className="flex items-start gap-3">
            <CheckCircle className="h-5 w-5 text-green-400 mt-0.5 flex-shrink-0" />
            <div className="text-sm text-green-200">
              <p className="font-semibold mb-2">Your outcome has been recorded</p>
              <div className="bg-neutral-900 border border-neutral-700 rounded px-3 py-2 font-medium mb-3">
                {outcomeLabels[declaredOutcome] || declaredOutcome}
              </div>
              <p className="text-green-300/80">
                The other party has{" "}
                {!isExpired ? (
                  <>
                    <span className="font-semibold">{hoursRemaining} hours and {minutesRemaining} minutes</span> to respond
                  </>
                ) : (
                  "not responded within the dispute window"
                )}
                . They can either agree with your declaration or raise a dispute.
              </p>
            </div>
          </div>
        </div>

        {isExpired ? (
          <div className="space-y-3">
            <div className="bg-neutral-900 border border-neutral-700 rounded-lg p-4 text-center">
              <p className="text-sm text-neutral-300 font-medium mb-1">Dispute window has expired</p>
              <p className="text-xs text-neutral-500">
                The other party did not dispute. You can now finalize the bet.
              </p>
            </div>
            <Button
              onClick={handleFinalize}
              disabled={isPending}
              className="w-full bg-green-600 hover:bg-green-700"
            >
              {isPending ? (
                <>
                  <Clock className="mr-2 h-4 w-4 animate-spin" />
                  Finalizing...
                </>
              ) : (
                <>
                  <CheckCircle className="mr-2 h-4 w-4" />
                  Finalize Bet
                </>
              )}
            </Button>
          </div>
        ) : (
          <div className="bg-neutral-900 border border-neutral-700 rounded-lg p-4 text-center">
            <p className="text-sm text-neutral-400">
              Waiting for the other party to respond...
            </p>
          </div>
        )}
      </CardContent>
    </Card>
  )
}
