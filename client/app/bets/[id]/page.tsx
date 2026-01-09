"use client"

import React, { use } from "react"
import { ArrowLeft, Loader2, AlertCircle, Clock } from "lucide-react"
import Link from "next/link"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { useActiveAccount } from "thirdweb/react"
import { useBetDetails } from "@/lib/hooks/useBets"
import { transformBetData, getTimeRemaining, type BetStatus } from "@/lib/utils/bet-helpers"
import { useDisplayName } from "@/lib/hooks/useUsernameRegistry"
import { useAcceptBet, useFundBet } from "@/lib/hooks/useBetActions"
import { useUSDCApproval, useUSDCAllowance, useUSDCBalance } from "@/lib/hooks/useBetCreation"
import { toast } from "sonner"

export default function BetDetailsPage({ params }: { params: Promise<{ id: string }> }) {
  const { id: betAddress } = use(params)
  const account = useActiveAccount()

  // Fetch bet data
  const { data: rawBetData, isLoading, refetch } = useBetDetails(betAddress)
  const [optimisticBet, setOptimisticBet] = React.useState<Partial<typeof rawBetData> | null>(null)

  const betData = React.useMemo(() => {
    if (!rawBetData) return null
    if (!optimisticBet) return rawBetData
    return { ...rawBetData, ...optimisticBet } as NonNullable<typeof rawBetData>
  }, [rawBetData, optimisticBet])
  const bet = betData ? transformBetData(betData) : null

  // Get display names
  const { displayName: creatorDisplay } = useDisplayName(bet?.creator)
  const { displayName: opponentDisplay } = useDisplayName(
    bet?.opponent === "0x0000000000000000000000000000000000000000" ? undefined : bet?.opponent
  )

  // Check user role
  const isCreator = account?.address?.toLowerCase() === bet?.creator?.toLowerCase()
  const isOpponent = account?.address?.toLowerCase() === bet?.opponent?.toLowerCase()
  const isHouseBet = bet?.opponent === "0x0000000000000000000000000000000000000000"
  const canAccept = bet?.status === "pending" && isOpponent && !bet?.opponentFunded

  // Bet actions
  const { acceptBet, isPending: isAccepting } = useAcceptBet(betAddress)
  const { fundCreator, isPending: isFunding } = useFundBet(betAddress)

  // USDC approval
  const { allowance, refetch: refetchAllowance } = useUSDCAllowance(account?.address, betAddress)
  const { balance } = useUSDCBalance(account?.address)
  const { approve, isPending: isApproving, isSuccess: approvalSuccess } = useUSDCApproval(betAddress)

  // Use stakeAmount (bigint) for comparisons - check if allowance is defined (could be 0)
  const needsApproval = allowance !== undefined && bet ? allowance < bet.stakeAmount : true
  const hasBalance = balance !== undefined && bet ? balance >= bet.stakeAmount : false



  // Handle accept bet
  const handleAccept = async () => {
    if (!canAccept || !bet) return

    let toastId: string | number | undefined

    const onSuccess = () => {
      console.log("Accept bet successful (optimistic update)")
      setOptimisticBet({ ...rawBetData, opponentFunded: true })
      if (toastId) {
        toast.success("Bet accepted successfully!", { id: toastId })
      }
      setTimeout(() => refetch(), 2000)
    }

    const onError = (error: any) => {
      console.error("Accept bet error:", error)
      if (toastId) {
        toast.error("Failed to accept bet", { id: toastId })
      }
    }

    if (needsApproval) {
      toastId = toast.loading("Approving USDC...")
      console.log("Approving USDC with stake:", bet.stake.toString())
      approve(bet.stake.toString(), {
        onSuccess: () => {
          console.log("Approval successful, accepting bet...")
          toast.success("USDC approved! Accepting bet...", { id: toastId })
          toastId = toast.loading("Confirming acceptance...")
          acceptBet({ onSuccess, onError })
        },
        onError: (error) => {
          toast.error("Failed to approve USDC", { id: toastId })
        }
      })
    } else {
      toastId = toast.loading("Confirming acceptance...")
      console.log("Accepting bet (already approved)")
      acceptBet({ onSuccess, onError })
    }
  }

  // Handle fund stake
  const handleFund = async () => {
    if (!bet) return

    let toastId: string | number | undefined

    const onSuccess = () => {
      console.log("Fund creator successful (optimistic update)")
      setOptimisticBet({ ...rawBetData, creatorFunded: true })
      if (toastId) {
        toast.success("Bet funded successfully!", { id: toastId })
      }
      setTimeout(() => refetch(), 2000)
    }

    const onError = (error: any) => {
      console.error("Fund creator error:", error)
      if (toastId) {
        toast.error("Failed to fund bet", { id: toastId })
      }
    }

    if (needsApproval) {
      toastId = toast.loading("Approving USDC...")
      console.log("Approving USDC with stake:", bet.stake.toString())
      approve(bet.stake.toString(), {
        onSuccess: () => {
          console.log("Approval successful, funding creator...")
          toast.success("USDC approved! Funding bet...", { id: toastId })
          toastId = toast.loading("Confirming funding...")
          fundCreator({ onSuccess, onError })
        },
        onError: (error) => {
          toast.error("Failed to approve USDC", { id: toastId })
        }
      })
    } else {
      toastId = toast.loading("Confirming funding...")
      console.log("Funding creator (already approved)")
      fundCreator({ onSuccess, onError })
    }
  }

  if (isLoading) {
    return (
      <main className="pt-16 pb-20">
        <div className="max-w-6xl mx-auto px-6 py-12">
          <div className="flex items-center justify-center py-20">
            <Loader2 className="w-12 h-12 animate-spin text-orange-500" />
          </div>
        </div>
      </main>
    )
  }

  if (!bet) {
    return (
      <main className="pt-16 pb-20">
        <div className="max-w-6xl mx-auto px-6 py-12">
          <Card>
            <CardContent className="py-12 text-center">
              <AlertCircle className="w-12 h-12 text-red-500 mx-auto mb-4" />
              <h3 className="text-xl font-bold mb-2">Bet Not Found</h3>
              <p className="text-neutral-400">The bet you're looking for doesn't exist.</p>
            </CardContent>
          </Card>
        </div>
      </main>
    )
  }

  const statusColors: Record<BetStatus, string> = {
    pending: "bg-yellow-500/20 text-yellow-400",
    active: "bg-green-500/20 text-green-400",
    awaiting_resolution: "bg-blue-500/20 text-blue-400",
    in_dispute: "bg-red-500/20 text-red-400",
    completed: "bg-cyan-500/20 text-cyan-400",
    cancelled: "bg-neutral-600/20 text-neutral-500",
  }

  const timeRemaining = getTimeRemaining(bet.expiresAt)

  return (
    <main className="pt-16 pb-20">
      <div className="max-w-6xl mx-auto px-6 py-12">
        {/* Back Button */}
        <Link href="/explore">
          <Button variant="ghost" className="mb-6">
            <ArrowLeft className="w-4 h-4 mr-2" />
            Back to Bets
          </Button>
        </Link>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Main Content */}
          <div className="lg:col-span-2 space-y-6">
            {/* Bet Details Card */}
            <Card>
              <CardHeader>
                <div className="flex justify-between items-start">
                  <div>
                    <Badge className={`mb-3 border-0 ${statusColors[bet.status]}`}>
                      {bet.status.replace(/_/g, ' ').toUpperCase()}
                    </Badge>
                    <CardTitle className="text-2xl">{bet.description}</CardTitle>
                  </div>
                  <Badge className="bg-blue-500/20 text-blue-400 border-0">{bet.category}</Badge>
                </div>
                <p className="text-sm text-neutral-500 mt-4">
                  Created {new Date(bet.createdAt * 1000).toLocaleDateString()}
                </p>
              </CardHeader>
              <CardContent className="space-y-6">
                {/* Outcome Criteria */}
                <div>
                  <h3 className="font-bold uppercase text-sm mb-3">How to Determine Winner</h3>
                  <div className="bg-neutral-900 border border-neutral-700 rounded p-4 text-neutral-300">
                    {bet.outcomeDescription}
                  </div>
                </div>

                {/* Participants */}
                <div>
                  <h3 className="font-bold uppercase text-sm mb-4">Participants</h3>
                  <div className="grid grid-cols-2 gap-4">
                    {/* Creator */}
                    <div className="bg-neutral-900 border border-neutral-700 rounded p-4">
                      <div className="font-bold mb-2">{creatorDisplay}</div>
                      <div className="text-xs text-neutral-500 mb-3">{bet.creator}</div>
                      <div className="flex items-center gap-2">
                        <Badge className="bg-orange-500/20 text-orange-400 border-0 text-xs">
                          Creator
                        </Badge>
                        {bet.creatorFunded && (
                          <Badge className="bg-green-500/20 text-green-400 border-0 text-xs">
                            Funded
                          </Badge>
                        )}
                      </div>
                    </div>

                    {/* Opponent */}
                    <div className="bg-neutral-900 border border-neutral-700 rounded p-4">
                      <div className="font-bold mb-2">
                        {isHouseBet ? "🏠 House" : opponentDisplay}
                      </div>
                      <div className="text-xs text-neutral-500 mb-3">
                        {isHouseBet ? "Pool Liquidity" : bet.opponent}
                      </div>
                      <div className="flex items-center gap-2">
                        <Badge className="bg-blue-500/20 text-blue-400 border-0 text-xs">
                          Opponent
                        </Badge>
                        {bet.opponentFunded && (
                          <Badge className="bg-green-500/20 text-green-400 border-0 text-xs">
                            Funded
                          </Badge>
                        )}
                      </div>
                    </div>
                  </div>
                </div>

                {/* Timeline */}
                <div>
                  <h3 className="font-bold uppercase text-sm mb-4">Timeline</h3>
                  <div className="space-y-3">
                    <div className="flex gap-4">
                      <div className="w-2 h-2 bg-orange-500 rounded-full mt-2"></div>
                      <div>
                        <div className="font-medium">Created</div>
                        <div className="text-sm text-neutral-500">
                          {new Date(bet.createdAt * 1000).toLocaleDateString()}
                        </div>
                      </div>
                    </div>
                    <div className="flex gap-4 ml-1 border-l border-neutral-700 pl-3">
                      <div className="w-2 h-2 bg-orange-500 rounded-full mt-2 -ml-4"></div>
                      <div>
                        <div className="font-medium">Expires</div>
                        <div className="text-sm text-neutral-500">
                          {new Date(bet.expiresAt * 1000).toLocaleDateString()}
                        </div>
                        {!timeRemaining.expired && (
                          <div className="text-xs text-orange-400 mt-1">
                            {timeRemaining.formatted} remaining
                          </div>
                        )}
                      </div>
                    </div>
                  </div>
                </div>
              </CardContent>
            </Card>
          </div>

          {/* Sidebar */}
          <div className="space-y-6">
            {/* Action Card - Accept Bet */}
            {canAccept && (
              <Card className="border-orange-500/50">
                <CardHeader>
                  <CardTitle className="text-lg">You're Invited!</CardTitle>
                </CardHeader>
                <CardContent className="space-y-4">
                  <p className="text-sm text-neutral-400">
                    {creatorDisplay} has invited you to this bet. Accept to participate.
                  </p>

                  {!hasBalance && (
                    <div className="bg-red-500/10 border border-red-500/30 rounded p-3 text-sm text-red-400">
                      Insufficient USDC balance. You need {bet.stake} USDC.
                    </div>
                  )}

                  <Button
                    className="w-full"
                    onClick={handleAccept}
                    disabled={isApproving || isAccepting || !hasBalance}
                  >
                    {isApproving
                      ? "Approving USDC..."
                      : isAccepting
                        ? "Accepting Bet..."
                        : needsApproval
                          ? `Approve ${bet.stake} USDC`
                          : "Accept Bet"}
                  </Button>
                  {approvalSuccess && needsApproval && (
                    <p className="text-xs text-orange-400 mt-2">
                      ✓ Approval successful! Click again to accept bet.
                    </p>
                  )}
                </CardContent>
              </Card>
            )}

            {/* Action Card - Fund Stake */}
            {((isCreator && !bet.creatorFunded) || (isOpponent && !bet.opponentFunded && bet.status !== "pending")) && (
              <Card className="border-orange-500/50">
                <CardHeader>
                  <CardTitle className="text-lg">Fund Your Stake</CardTitle>
                </CardHeader>
                <CardContent className="space-y-4">
                  <p className="text-sm text-neutral-400">
                    Deposit {bet.stake} USDC to activate the bet.
                  </p>

                  {!hasBalance && (
                    <div className="bg-red-500/10 border border-red-500/30 rounded p-3 text-sm text-red-400">
                      Insufficient USDC balance. You need {bet.stake} USDC.
                    </div>
                  )}

                  <Button
                    className="w-full"
                    onClick={handleFund}
                    disabled={isApproving || isFunding || !hasBalance}
                  >
                    {isApproving
                      ? "Approving USDC..."
                      : isFunding
                        ? "Funding Stake..."
                        : needsApproval
                          ? `Approve ${bet.stake} USDC`
                          : "Fund Stake"}
                  </Button>
                  {approvalSuccess && needsApproval && (
                    <p className="text-xs text-orange-400 mt-2">
                      ✓ Approval successful! Click again to fund stake.
                    </p>
                  )}
                </CardContent>
              </Card>
            )}

            {/* Bet Info Card */}
            <Card>
              <CardHeader>
                <CardTitle className="text-lg">Bet Details</CardTitle>
              </CardHeader>
              <CardContent className="space-y-6">
                {/* Stake */}
                <div>
                  <div className="text-3xl font-bold text-orange-500 mb-1">{bet.stake} USDC</div>
                  <div className="text-xs text-neutral-400 uppercase">Stake per side</div>
                  <div className="text-sm text-neutral-500 mt-2">Total pool: {bet.stake * 2} USDC</div>
                </div>

                {/* Duration */}
                <div className="border-t border-neutral-700 pt-4">
                  <div className="flex items-center gap-2 mb-2">
                    <Clock className="w-4 h-4 text-orange-500" />
                    <span className="font-medium">{bet.duration}</span>
                  </div>
                  <div className="text-sm text-neutral-500">
                    {timeRemaining.expired ? (
                      <span className="text-red-400">Expired</span>
                    ) : (
                      <>Expires {new Date(bet.expiresAt * 1000).toLocaleDateString()}</>
                    )}
                  </div>
                </div>

                {/* Category */}
                <div className="border-t border-neutral-700 pt-4">
                  <div className="text-xs text-neutral-400 uppercase mb-2">Category</div>
                  <Badge className="bg-blue-500/20 text-blue-400 border-0">{bet.category}</Badge>
                </div>

                {/* Tags */}
                {bet.tags && bet.tags.length > 0 && (
                  <div className="border-t border-neutral-700 pt-4">
                    <div className="text-xs text-neutral-400 uppercase mb-2">Tags</div>
                    <div className="flex flex-wrap gap-2">
                      {bet.tags.map((tag, idx) => (
                        <Badge key={idx} variant="outline" className="text-xs">
                          {tag}
                        </Badge>
                      ))}
                    </div>
                  </div>
                )}

                {/* Contract Address */}
                <div className="border-t border-neutral-700 pt-4">
                  <div className="text-xs text-neutral-400 uppercase mb-2">Contract</div>
                  <div className="text-xs text-neutral-500 font-mono break-all">
                    {betAddress}
                  </div>
                </div>
              </CardContent>
            </Card>

            {/* Activity Log */}
            <Card>
              <CardHeader>
                <CardTitle className="text-lg">Activity</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="space-y-4 text-sm">
                  <div className="border-b border-neutral-700 pb-4 last:border-0">
                    <div className="font-medium">Bet created by {creatorDisplay}</div>
                    <div className="text-xs text-neutral-500 mt-1">
                      {new Date(bet.createdAt * 1000).toLocaleString()}
                    </div>
                  </div>

                  {bet.creatorFunded && (
                    <div className="border-b border-neutral-700 pb-4 last:border-0">
                      <div className="font-medium">Creator funded stake</div>
                      <div className="text-xs text-neutral-500 mt-1">
                        {bet.stake} USDC deposited
                      </div>
                    </div>
                  )}

                  {!isHouseBet && bet.status !== "pending" && (
                    <div className="border-b border-neutral-700 pb-4 last:border-0">
                      <div className="font-medium">Bet accepted by {opponentDisplay}</div>
                      <div className="text-xs text-neutral-500 mt-1">
                        Opponent joined the bet
                      </div>
                    </div>
                  )}

                  {bet.opponentFunded && (
                    <div className="border-b border-neutral-700 pb-4 last:border-0">
                      <div className="font-medium">Opponent funded stake</div>
                      <div className="text-xs text-neutral-500 mt-1">
                        {bet.stake} USDC deposited
                      </div>
                    </div>
                  )}

                  {bet.status === "active" && bet.creatorFunded && bet.opponentFunded && (
                    <div className="border-b border-neutral-700 pb-4 last:border-0">
                      <div className="font-medium text-green-400">Bet is now active!</div>
                      <div className="text-xs text-neutral-500 mt-1">
                        Both parties have funded their stakes
                      </div>
                    </div>
                  )}

                  {bet.status === "completed" && (
                    <div className="pb-4 last:border-0">
                      <div className="font-medium text-cyan-400">Bet completed</div>
                      <div className="text-xs text-neutral-500 mt-1">
                        Outcome: {bet.outcome}
                      </div>
                    </div>
                  )}
                </div>
              </CardContent>
            </Card>
          </div>
        </div>
      </div>
    </main>
  )
}
