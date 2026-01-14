"use client"

import { useState, useEffect } from "react"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Badge } from "@/components/ui/badge"
import { useActiveAccount } from "thirdweb/react"
import {
  useJudgeProfile,
  useIncreaseStake,
  useRequestWithdrawal,
  useCompleteWithdrawal,
  useWithdrawalStatus,
} from "@/lib/hooks/useJudgeRegistry"
import { ArrowUp, ArrowDown, Clock, AlertTriangle } from "lucide-react"
import { toast } from "sonner"

export function JudgeStakingPanel() {
  const account = useActiveAccount()
  const address = account?.address
  const { profile, refetch: refetchProfile } = useJudgeProfile(address)
  const { withdrawalStatus, refetch: refetchWithdrawal } = useWithdrawalStatus(address)

  const [stakeAmount, setStakeAmount] = useState("")

  const {
    increaseStake,
    isPending: isIncreasing,
  } = useIncreaseStake(stakeAmount)

  const {
    requestWithdrawal,
    isPending: isRequestingWithdrawal,
  } = useRequestWithdrawal()

  const {
    completeWithdrawal,
    isPending: isCompletingWithdrawal,
  } = useCompleteWithdrawal()

  const handleIncreaseStake = () => {
    if (!stakeAmount || parseFloat(stakeAmount) <= 0) {
      toast.error("Please enter a valid stake amount")
      return
    }

    const toastId = toast.loading("Increasing stake...")

    increaseStake({
      onSuccess: () => {
        toast.success(`Successfully increased stake by ${stakeAmount} MNT!`, { id: toastId })
        setStakeAmount("")
        setTimeout(() => refetchProfile(), 2000)
      },
      onError: (error: any) => {
        console.error("Increase stake failed:", error)
        toast.error("Failed to increase stake. Please try again.", { id: toastId })
      }
    })
  }

  const handleRequestWithdrawal = () => {
    const toastId = toast.loading("Requesting withdrawal...")

    requestWithdrawal({
      onSuccess: () => {
        toast.success("Withdrawal requested! Lock period has started.", { id: toastId })
        setTimeout(() => {
          refetchWithdrawal()
          refetchProfile()
        }, 2000)
      },
      onError: (error: any) => {
        console.error("Request withdrawal failed:", error)
        toast.error("Failed to request withdrawal. Please try again.", { id: toastId })
      }
    })
  }

  const handleCompleteWithdrawal = () => {
    const toastId = toast.loading("Completing withdrawal...")

    completeWithdrawal({
      onSuccess: () => {
        toast.success("Withdrawal completed successfully!", { id: toastId })
        setTimeout(() => {
          refetchWithdrawal()
          refetchProfile()
        }, 2000)
      },
      onError: (error: any) => {
        console.error("Complete withdrawal failed:", error)
        toast.error("Failed to complete withdrawal. Please try again.", { id: toastId })
      }
    })
  }

  const formatTimeRemaining = (seconds: bigint) => {
    const totalSeconds = Number(seconds)
    const days = Math.floor(totalSeconds / 86400)
    const hours = Math.floor((totalSeconds % 86400) / 3600)
    const minutes = Math.floor((totalSeconds % 3600) / 60)

    if (days > 0) return `${days}d ${hours}h`
    if (hours > 0) return `${hours}h ${minutes}m`
    return `${minutes}m`
  }

  if (!profile) {
    return (
      <Card>
        <CardContent className="pt-6">
          <p className="text-neutral-400 text-center">Not registered as a judge</p>
        </CardContent>
      </Card>
    )
  }

  return (
    <div className="space-y-6">
      {/* Current Stake Display */}
      <Card className="border-orange-500/20">
        <CardHeader>
          <CardTitle className="text-lg">Your Stake</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="flex items-baseline gap-2 mb-4">
            <span className="text-4xl font-bold text-orange-500">
              {parseFloat(profile.stakedAmountFormatted).toFixed(2)}
            </span>
            <span className="text-neutral-400">MNT</span>
          </div>
          <div className="grid grid-cols-2 gap-4 text-sm">
            <div>
              <div className="text-neutral-400">Reputation</div>
              <div className="font-bold">{profile.reputationPercentage.toFixed(1)}%</div>
            </div>
            <div>
              <div className="text-neutral-400">Cases Judged</div>
              <div className="font-bold">{profile.casesJudged.toString()}</div>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Increase Stake */}
      <Card>
        <CardHeader>
          <CardTitle className="text-lg flex items-center gap-2">
            <ArrowUp className="h-5 w-5 text-green-400" />
            Increase Stake
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div>
            <label className="block text-sm font-medium mb-2">
              Additional Stake Amount (MNT)
            </label>
            <Input
              type="number"
              step="0.01"
              placeholder="0.00"
              value={stakeAmount}
              onChange={(e) => setStakeAmount(e.target.value)}
              className="bg-neutral-800 border-neutral-700"
            />
            <p className="text-xs text-neutral-400 mt-1">
              Increasing your stake improves your reputation and eligibility
            </p>
          </div>

          <Button
            onClick={handleIncreaseStake}
            disabled={!stakeAmount || parseFloat(stakeAmount) <= 0 || isIncreasing}
            className="w-full"
          >
            {isIncreasing ? (
              <>
                <Clock className="mr-2 h-4 w-4 animate-spin" />
                Confirm in Wallet...
              </>
            ) : (
              <>
                <ArrowUp className="mr-2 h-4 w-4" />
                Increase Stake
              </>
            )}
          </Button>
        </CardContent>
      </Card>

      {/* Withdrawal Section */}
      <Card className="border-red-500/20">
        <CardHeader>
          <CardTitle className="text-lg flex items-center gap-2">
            <ArrowDown className="h-5 w-5 text-red-400" />
            Withdraw Stake
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          {withdrawalStatus?.canWithdraw ? (
            // Can complete withdrawal
            <>
              <div className="p-3 bg-green-500/10 border border-green-500/30 rounded-lg">
                <p className="text-sm text-green-400 mb-2">
                  ✓ Withdrawal lock period completed
                </p>
                <p className="text-xs text-neutral-400">
                  You can now withdraw your stake of {profile.stakedAmountFormatted} MNT
                </p>
              </div>

              <Button
                onClick={handleCompleteWithdrawal}
                disabled={isCompletingWithdrawal}
                className="w-full bg-red-500 hover:bg-red-600"
              >
                {isCompletingWithdrawal ? (
                  <>
                    <Clock className="mr-2 h-4 w-4 animate-spin" />
                    Confirm in Wallet...
                  </>
                ) : (
                  <>
                    <ArrowDown className="mr-2 h-4 w-4" />
                    Complete Withdrawal
                  </>
                )}
              </Button>
            </>
          ) : withdrawalStatus && withdrawalStatus.withdrawalRequestTime > BigInt(0) ? (
            // Withdrawal requested, waiting for lock period
            <>
              <div className="p-3 bg-orange-500/10 border border-orange-500/30 rounded-lg">
                <div className="flex items-start gap-2 mb-2">
                  <Clock className="h-4 w-4 text-orange-400 mt-0.5" />
                  <div>
                    <p className="text-sm text-orange-400 font-medium">
                      Withdrawal lock period active
                    </p>
                    <p className="text-xs text-neutral-400 mt-1">
                      Time remaining: {formatTimeRemaining(withdrawalStatus.timeRemaining)}
                    </p>
                  </div>
                </div>
              </div>

              <div className="p-3 bg-neutral-800 rounded-lg text-xs text-neutral-400">
                <p>You can complete your withdrawal after the lock period expires.</p>
                <p className="mt-1">
                  Available:{" "}
                  {new Date(Number(withdrawalStatus.withdrawalAvailableTime) * 1000).toLocaleString()}
                </p>
              </div>
            </>
          ) : (
            // Can request withdrawal
            <>
              <div className="p-3 bg-yellow-500/10 border border-yellow-500/30 rounded-lg">
                <div className="flex items-start gap-2">
                  <AlertTriangle className="h-4 w-4 text-yellow-400 mt-0.5" />
                  <div>
                    <p className="text-sm text-yellow-400 font-medium mb-1">
                      Warning: Withdrawal Lock Period
                    </p>
                    <p className="text-xs text-neutral-400">
                      Requesting withdrawal starts a lock period during which you cannot judge cases
                      and your stake remains locked. You will not be able to cancel once started.
                    </p>
                  </div>
                </div>
              </div>

              <Button
                onClick={handleRequestWithdrawal}
                disabled={isRequestingWithdrawal}
                variant="outline"
                className="w-full bg-transparent border-red-500/30 hover:bg-red-500/10 text-red-400"
              >
                {isRequestingWithdrawal ? (
                  <>
                    <Clock className="mr-2 h-4 w-4 animate-spin" />
                    Confirm in Wallet...
                  </>
                ) : (
                  <>
                    <ArrowDown className="mr-2 h-4 w-4" />
                    Request Withdrawal
                  </>
                )}
              </Button>
            </>
          )}
        </CardContent>
      </Card>
    </div>
  )
}
