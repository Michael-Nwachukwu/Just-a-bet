"use client"

import { useState } from "react"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Textarea } from "@/components/ui/textarea"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog"
import { AlertTriangle, CheckCircle, Clock, XCircle } from "lucide-react"
import { useFinalizeResolution, useRaiseDispute } from "@/lib/hooks/useBetActions"
import { toast } from "sonner"

interface DisputeResponseCardProps {
  betAddress: string
  declaredOutcome: string // "CreatorWins" | "OpponentWins" | "Draw"
  declaredBy: string // address of declarer
  disputeDeadline: number // timestamp
  userAddress?: string
  onSuccess?: () => void
}

export function DisputeResponseCard({
  betAddress,
  declaredOutcome,
  declaredBy,
  disputeDeadline,
  userAddress,
  onSuccess,
}: DisputeResponseCardProps) {
  const [disputeReason, setDisputeReason] = useState("")
  const [isDisputeDialogOpen, setIsDisputeDialogOpen] = useState(false)

  const { finalizeResolution, isPending: isFinalizing } = useFinalizeResolution(betAddress)
  const { raiseDispute, isPending: isDisputing } = useRaiseDispute(betAddress)

  const currentTime = Math.floor(Date.now() / 1000)
  const timeRemaining = disputeDeadline - currentTime
  const hoursRemaining = Math.max(0, Math.floor(timeRemaining / 3600))
  const minutesRemaining = Math.max(0, Math.floor((timeRemaining % 3600) / 60))
  const isExpired = timeRemaining <= 0

  console.log("DisputeResponseCard:", {
    disputeDeadline,
    currentTime,
    timeRemaining,
    hoursRemaining,
    minutesRemaining,
    isExpired,
  })

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

  const handleDispute = () => {
    if (!disputeReason.trim()) {
      toast.error("Please provide a reason for the dispute")
      return
    }

    const toastId = toast.loading("Raising dispute...")

    raiseDispute({
      onSuccess: () => {
        toast.success("Dispute raised! A judge will review this case.", { id: toastId })
        setIsDisputeDialogOpen(false)
        onSuccess?.()
      },
      onError: (error) => {
        console.error("Raise dispute error:", error)
        toast.error("Failed to raise dispute. Please try again.", { id: toastId })
      }
    })
  }

  const outcomeLabels: Record<string, string> = {
    CreatorWins: "Creator Won",
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
        <div className="bg-blue-500/10 border border-blue-500/30 rounded-lg p-4">
          <div className="flex items-start gap-3">
            <AlertTriangle className="h-5 w-5 text-blue-400 mt-0.5 flex-shrink-0" />
            <div className="text-sm text-blue-200">
              <p className="font-semibold mb-2">The other party declared the outcome:</p>
              <div className="bg-neutral-900 border border-neutral-700 rounded px-3 py-2 font-medium">
                {outcomeLabels[declaredOutcome] || declaredOutcome}
              </div>
            </div>
          </div>
        </div>

        {isExpired ? (
          <div className="space-y-3">
            <div className="bg-neutral-900 border border-neutral-700 rounded-lg p-4 text-center">
              <p className="text-sm text-neutral-400 mb-2">
                Dispute window has expired. The outcome can now be finalized.
              </p>
            </div>
            <Button
              onClick={handleFinalize}
              disabled={isFinalizing}
              className="w-full bg-green-600 hover:bg-green-700"
            >
              {isFinalizing ? (
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
          <>
            <div className="space-y-3">
              <p className="text-sm text-neutral-300">
                You have {hoursRemaining} hours and {minutesRemaining} minutes to dispute this outcome.
              </p>

              <div className="bg-blue-500/10 border border-blue-500/30 rounded-lg p-4 mb-3">
                <p className="text-xs text-blue-200">
                  <strong>What happens next:</strong>
                  <br />• If you <strong>disagree</strong>, click "Raise Dispute" below
                  <br />• If you <strong>agree</strong>, do nothing and the outcome will be finalized after the deadline
                </p>
              </div>

              {/* Dispute Button */}
              <Dialog open={isDisputeDialogOpen} onOpenChange={setIsDisputeDialogOpen}>
                <DialogTrigger asChild>
                  <Button
                    variant="outline"
                    disabled={isDisputing}
                    className="w-full border-red-500/30 hover:bg-red-500/10 text-red-400"
                  >
                    <XCircle className="mr-2 h-4 w-4" />
                    Raise Dispute
                  </Button>
                </DialogTrigger>
                  <DialogContent className="bg-neutral-950 border-neutral-800">
                    <DialogHeader>
                      <DialogTitle>Raise a Dispute</DialogTitle>
                      <DialogDescription className="text-neutral-400">
                        Provide a clear reason for disputing this outcome. A judge will review the case and make a final decision.
                      </DialogDescription>
                    </DialogHeader>

                    <div className="space-y-4 pt-4">
                      <div>
                        <label className="text-sm font-medium mb-2 block">Dispute Reason</label>
                        <Textarea
                          placeholder="Explain why you disagree with the declared outcome..."
                          value={disputeReason}
                          onChange={(e) => setDisputeReason(e.target.value)}
                          rows={4}
                          className="bg-neutral-900 border-neutral-700"
                        />
                      </div>

                      <div className="bg-orange-500/10 border border-orange-500/30 rounded p-3 text-sm text-orange-200">
                        <AlertTriangle className="h-4 w-4 inline mr-2" />
                        Disputing will send this case to a judge. The judge's decision will be final.
                      </div>

                      <div className="flex gap-3">
                        <Button
                          variant="outline"
                          onClick={() => setIsDisputeDialogOpen(false)}
                          className="flex-1"
                          disabled={isDisputing}
                        >
                          Cancel
                        </Button>
                        <Button
                          onClick={handleDispute}
                          disabled={!disputeReason.trim() || isDisputing}
                          className="flex-1 bg-red-600 hover:bg-red-700"
                        >
                          {isDisputing ? (
                            <>
                              <Clock className="mr-2 h-4 w-4 animate-spin" />
                              Raising Dispute...
                            </>
                          ) : (
                            "Raise Dispute"
                          )}
                        </Button>
                      </div>
                    </div>
                  </DialogContent>
                </Dialog>
            </div>

            <p className="text-xs text-neutral-500 text-center">
              If no dispute is raised, either party can finalize the bet after the deadline
            </p>
          </>
        )}
      </CardContent>
    </Card>
  )
}
