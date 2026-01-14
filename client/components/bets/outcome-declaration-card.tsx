"use client"

import { useState } from "react"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { AlertTriangle, Clock, Trophy } from "lucide-react"
import { useDeclareOutcome } from "@/lib/hooks/useBetActions"
import { toast } from "sonner"

interface OutcomeDeclarationCardProps {
  betAddress: string
  isCreator: boolean
  isOpponent: boolean
  expiresAt: number
  onSuccess?: () => void
}

export function OutcomeDeclarationCard({
  betAddress,
  isCreator,
  isOpponent,
  expiresAt,
  onSuccess,
}: OutcomeDeclarationCardProps) {
  const [selectedOutcome, setSelectedOutcome] = useState<number | null>(null)
  const { declareOutcome, isPending } = useDeclareOutcome(betAddress)

  const handleDeclare = () => {
    if (selectedOutcome === null) {
      toast.error("Please select an outcome")
      return
    }

    const toastId = toast.loading("Declaring outcome...")

    declareOutcome(selectedOutcome, {
      onSuccess: () => {
        toast.success("Outcome declared! Waiting for opponent response...", { id: toastId })
        onSuccess?.()
      },
      onError: (error) => {
        console.error("Declare outcome error:", error)
        toast.error("Failed to declare outcome. Please try again.", { id: toastId })
      }
    })
  }

  const timeSinceExpiry = Math.floor((Date.now() / 1000) - expiresAt)
  const daysExpired = Math.floor(timeSinceExpiry / 86400)
  const hoursExpired = Math.floor((timeSinceExpiry % 86400) / 3600)

  // Outcome options based on role
  // 1 = CreatorWins, 2 = OpponentWins, 3 = Draw
  const outcomes = isCreator
    ? [
        { value: 1, label: "I Won", icon: Trophy, color: "bg-green-500/20 text-green-400 border-green-500/30" },
        { value: 3, label: "Draw", icon: Clock, color: "bg-yellow-500/20 text-yellow-400 border-yellow-500/30" },
      ]
    : [
        { value: 2, label: "I Won", icon: Trophy, color: "bg-green-500/20 text-green-400 border-green-500/30" },
        { value: 3, label: "Draw", icon: Clock, color: "bg-yellow-500/20 text-yellow-400 border-yellow-500/30" },
      ]

  return (
    <Card className="border-orange-500/50">
      <CardHeader>
        <div className="flex items-start justify-between">
          <CardTitle className="text-lg">Declare Outcome</CardTitle>
          <Badge className="bg-red-500/20 text-red-400 border-0">
            Expired {daysExpired > 0 ? `${daysExpired}d` : `${hoursExpired}h`} ago
          </Badge>
        </div>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="bg-orange-500/10 border border-orange-500/30 rounded-lg p-4">
          <div className="flex items-start gap-3">
            <AlertTriangle className="h-5 w-5 text-orange-400 mt-0.5 flex-shrink-0" />
            <div className="text-sm text-orange-200">
              <p className="font-semibold mb-1">Bet has expired</p>
              <p className="text-orange-300/80">
                As a participant, you can declare the outcome. The other party will have 24 hours to agree or dispute.
              </p>
            </div>
          </div>
        </div>

        <div className="space-y-3">
          <div className="text-sm font-medium text-neutral-300">Select the outcome:</div>
          <div className="grid grid-cols-2 gap-3">
            {outcomes.map((outcome) => {
              const Icon = outcome.icon
              const isSelected = selectedOutcome === outcome.value
              return (
                <button
                  key={outcome.value}
                  onClick={() => setSelectedOutcome(outcome.value)}
                  className={`
                    relative flex flex-col items-center justify-center p-4 rounded-lg border-2 transition-all
                    ${isSelected
                      ? outcome.color + " shadow-lg"
                      : "border-neutral-700 hover:border-neutral-600 bg-neutral-900"
                    }
                  `}
                  disabled={isPending}
                >
                  <Icon className="h-6 w-6 mb-2" />
                  <span className="font-medium">{outcome.label}</span>
                  {isSelected && (
                    <div className="absolute top-2 right-2">
                      <div className="w-2 h-2 bg-current rounded-full" />
                    </div>
                  )}
                </button>
              )
            })}
          </div>
        </div>

        <Button
          className="w-full"
          onClick={handleDeclare}
          disabled={selectedOutcome === null || isPending}
        >
          {isPending ? (
            <>
              <Clock className="mr-2 h-4 w-4 animate-spin" />
              Declaring...
            </>
          ) : (
            "Declare Outcome"
          )}
        </Button>

        <p className="text-xs text-neutral-500 text-center">
          After declaration, the opponent has 24 hours to agree or raise a dispute
        </p>
      </CardContent>
    </Card>
  )
}
