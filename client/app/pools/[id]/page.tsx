"use client"

import { useState, use, useCallback } from "react"
import { ArrowLeft, RefreshCw, Loader2 } from "lucide-react"
import Link from "next/link"
import { useActiveAccount } from "thirdweb/react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { usePoolStats, useUserPositions, useDepositToPool, useWithdrawFromPool, useTierConfig } from "@/lib/hooks/usePools"
import { useUSDCApproval, useUSDCAllowance, useUSDCBalance } from "@/lib/hooks/useBetCreation"
import { getContractAddresses } from "@/lib/contracts/addresses"
import { toast } from "sonner"
import { waitForReceipt } from "thirdweb"
import { client, mantleSepolia } from "@/lib/thirdweb"

export default function PoolDetailsPage({ params }: { params: Promise<{ id: string }> }) {
  const resolvedParams = use(params)
  const poolAddress = resolvedParams.id
  const account = useActiveAccount()

  const [selectedTier, setSelectedTier] = useState(0)
  const [depositAmount, setDepositAmount] = useState("")

  // Real blockchain data
  const { data: poolStats, isLoading: isLoadingStats, refetch: refetchStats } = usePoolStats(poolAddress)
  const { data: userPositions, isLoading: isLoadingPositions, refetch: refetchPositions } = useUserPositions(poolAddress, account?.address)
  const { tiers } = useTierConfig()
  const { balance: usdcBalanceRaw } = useUSDCBalance(account?.address)
  const usdcBalance = usdcBalanceRaw ? Number(usdcBalanceRaw) / 1e6 : 0

  // Get pool info from addresses config
  const addresses = getContractAddresses(5003)
  const poolInfo = Object.values(addresses.pools).find(p => p.address.toLowerCase() === poolAddress.toLowerCase())

  // Pool descriptions
  const descriptions: Record<string, string> = {
    sports: "Back the house in sports betting markets. Earn yield from NBA, NFL, and more.",
    crypto: "Provide liquidity for crypto prediction markets. BTC, ETH price movements.",
    politics: "Support political prediction markets. Elections, policy outcomes, and more.",
    general: "Diversified pool for general betting markets across all categories.",
  }

  const baseAPY = 10
  const selectedTierConfig = tiers[selectedTier]
  const totalAPY = baseAPY + (selectedTierConfig?.apyBoost || 0)

  // USDC approval and deposit hooks
  const { approve: approveUSDC, isPending: isApproving } = useUSDCApproval(poolAddress)
  const { allowance: allowanceRaw, refetch: refetchAllowance } = useUSDCAllowance(account?.address, poolAddress)
  const allowance = allowanceRaw || BigInt(0)
  const { deposit, isPending: isDepositing } = useDepositToPool(poolAddress)
  const { withdraw, isPending: isWithdrawing } = useWithdrawFromPool(poolAddress)

  const handleDeposit = useCallback(async () => {
    if (!depositAmount || Number(depositAmount) <= 0) {
      toast.error("Please enter a valid deposit amount")
      return
    }

    if (Number(depositAmount) < 10) {
      toast.error("Minimum deposit is 10 USDC")
      return
    }

    if (!account?.address) {
      toast.error("Please connect your wallet")
      return
    }

    const depositAmountNum = Number(depositAmount)
    const allowanceNum = Number(allowance) / 1e6

    console.log("Deposit amount:", depositAmountNum, "Allowance:", allowanceNum)

    if (allowanceNum < depositAmountNum) {
      // Need approval first
      const toastId = toast.loading("Approving USDC spending...")

      approveUSDC(depositAmount, {
        onSuccess: async (result) => {
          console.log("Approval transaction submitted:", result)
          toast.loading("Waiting for approval confirmation...", { id: toastId })

          try {
            // Wait for the approval transaction to be mined
            const receipt = await waitForReceipt({
              client,
              chain: mantleSepolia,
              transactionHash: result.transactionHash,
            })

            console.log("Approval confirmed:", receipt)
            toast.success("USDC approved! Proceeding with deposit...", { id: toastId })

            // Refetch allowance to get updated value
            await refetchAllowance()

            // Now trigger deposit
            const depositToastId = toast.loading("Confirming deposit transaction...")

            deposit(depositAmount, selectedTier, {
              onSuccess: () => {
                toast.success("Deposit successful!", { id: depositToastId })
                setDepositAmount("")
                setTimeout(() => {
                  refetchStats()
                  refetchPositions()
                }, 2000)
              },
              onError: (error) => {
                console.error("Deposit failed:", error)
                toast.error("Deposit failed. Please try again.", { id: depositToastId })
              }
            })
          } catch (err) {
            console.error("Error waiting for approval:", err)
            toast.error("Approval confirmation failed", { id: toastId })
          }
        },
        onError: (error) => {
          console.error("Approval failed:", error)
          toast.error("Approval failed. Please try again.", { id: toastId })
        }
      })
    } else {
      // Already have approval, just deposit
      const toastId = toast.loading("Confirming deposit transaction...")

      deposit(depositAmount, selectedTier, {
        onSuccess: () => {
          toast.success("Deposit successful!", { id: toastId })
          setDepositAmount("")
          setTimeout(() => {
            refetchStats()
            refetchPositions()
          }, 2000)
        },
        onError: (error) => {
          console.error("Deposit failed:", error)
          toast.error("Deposit failed. Please try again.", { id: toastId })
        }
      })
    }
  }, [depositAmount, account, allowance, selectedTier, approveUSDC, deposit, refetchAllowance, refetchStats, refetchPositions])

  const handleWithdraw = useCallback((positionId: number) => {
    if (!account?.address) {
      toast.error("Please connect your wallet")
      return
    }

    const toastId = toast.loading("Confirming withdrawal transaction...")

    withdraw(positionId, {
      onSuccess: () => {
        toast.success("Withdrawal successful!", { id: toastId })
        setTimeout(() => {
          refetchStats()
          refetchPositions()
        }, 2000)
      },
      onError: (error) => {
        console.error("Withdrawal failed:", error)
        toast.error("Withdrawal failed. Please try again.", { id: toastId })
      }
    })
  }, [account, withdraw, refetchStats, refetchPositions])

  const handleRefresh = () => {
    refetchStats()
    refetchPositions()
    toast.success("Data refreshed!")
  }

  if (!poolInfo) {
    return (
      <main className="pt-16 pb-20">
        <div className="max-w-6xl mx-auto px-6 py-12">
          <div className="text-center">
            <h2 className="text-2xl font-bold mb-4">Pool Not Found</h2>
            <Link href="/pools">
              <Button>Back to Pools</Button>
            </Link>
          </div>
        </div>
      </main>
    )
  }

  const isLoading = isLoadingStats || isLoadingPositions

  return (
    <main className="pt-16 pb-20">
      <div className="max-w-6xl mx-auto px-6 py-12">
        {/* Back Button & Refresh */}
        <div className="flex justify-between items-center mb-6">
          <Link href="/pools">
            <Button variant="ghost">
              <ArrowLeft className="w-4 h-4 mr-2" />
              Back to Pools
            </Button>
          </Link>
          <Button variant="outline" onClick={handleRefresh} disabled={isLoading}>
            <RefreshCw className={`w-4 h-4 mr-2 ${isLoading ? 'animate-spin' : ''}`} />
            Refresh
          </Button>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Main Content */}
          <div className="lg:col-span-2 space-y-6">
            {/* Pool Overview */}
            <Card>
              <CardHeader>
                <div className="flex justify-between items-start">
                  <div>
                    <CardTitle className="text-2xl mb-3">{poolInfo.name}</CardTitle>
                    <Badge className="bg-blue-500/20 text-blue-400 border-0">{poolInfo.category}</Badge>
                  </div>
                  <div className="text-right">
                    <div className="text-4xl font-bold text-orange-500">{baseAPY.toFixed(1)}%</div>
                    <div className="text-xs text-neutral-400 uppercase">Base APY</div>
                  </div>
                </div>
              </CardHeader>
              <CardContent className="space-y-6">
                {isLoading ? (
                  <div className="flex items-center justify-center py-8">
                    <Loader2 className="w-8 h-8 animate-spin text-orange-500" />
                  </div>
                ) : (
                  <>
                    <p className="text-neutral-400">
                      {descriptions[poolInfo.category.toLowerCase()] || descriptions.general}
                    </p>

                    {/* Stats Grid */}
                    <div className="grid grid-cols-3 gap-4">
                      <div>
                        <div className="text-xs text-neutral-400 uppercase mb-1">Total Deposits</div>
                        <div className="text-lg font-bold">
                          ${poolStats?.totalDepositsFormatted.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                        </div>
                      </div>
                      <div>
                        <div className="text-xs text-neutral-400 uppercase mb-1">Available</div>
                        <div className="text-lg font-bold">
                          ${poolStats?.availableLiquidityFormatted.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                        </div>
                      </div>
                      <div>
                        <div className="text-xs text-neutral-400 uppercase mb-1">Active Bets</div>
                        <div className="text-lg font-bold">{poolStats?.totalBetsMatched.toString() || "0"}</div>
                      </div>
                      <div>
                        <div className="text-xs text-neutral-400 uppercase mb-1">Matched Amount</div>
                        <div className="text-lg font-bold">
                          ${poolStats?.activeMatchedAmountFormatted.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                        </div>
                      </div>
                      <div>
                        <div className="text-xs text-neutral-400 uppercase mb-1">Utilization</div>
                        <div className="text-lg font-bold">{poolStats?.utilizationRate.toFixed(1)}%</div>
                      </div>
                      <div>
                        <div className="text-xs text-neutral-400 uppercase mb-1">Pool ID</div>
                        <div className="text-lg font-bold">{poolInfo.poolId}</div>
                      </div>
                    </div>
                  </>
                )}

                {/* Risk Parameters */}
                <div className="bg-neutral-900 border border-neutral-700 rounded p-4">
                  <h4 className="font-bold uppercase text-sm mb-4">Risk Parameters</h4>
                  <div className="space-y-3 text-sm">
                    <div className="flex justify-between">
                      <span className="text-neutral-400">Risk Tier:</span>
                      <Badge className={`border-0 ${poolStats && poolStats.utilizationRate > 70
                          ? "bg-red-500/20 text-red-400"
                          : poolStats && poolStats.utilizationRate > 40
                            ? "bg-yellow-500/20 text-yellow-400"
                            : "bg-green-500/20 text-green-400"
                        }`}>
                        {poolStats && poolStats.utilizationRate > 70 ? "High Risk" : poolStats && poolStats.utilizationRate > 40 ? "Medium Risk" : "Low Risk"}
                      </Badge>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-neutral-400">Category:</span>
                      <span>{poolInfo.category}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-neutral-400">Lock Periods:</span>
                      <span>Flexible, 30d, 90d, 365d</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-neutral-400">CDO Token:</span>
                      <span className="text-xs">{poolInfo.cdoToken.slice(0, 6)}...{poolInfo.cdoToken.slice(-4)}</span>
                    </div>
                  </div>
                </div>
              </CardContent>
            </Card>
          </div>

          {/* Sidebar */}
          <div className="space-y-6">
            {/* Deposit Card */}
            <Card>
              <CardHeader>
                <CardTitle className="text-lg">Deposit to Pool</CardTitle>
              </CardHeader>
              <CardContent className="space-y-6">
                {/* Lock Period Selector */}
                <div>
                  <label className="block text-xs font-bold uppercase mb-3">Lock Period</label>
                  <div className="space-y-2">
                    {tiers.map((tier) => (
                      <div
                        key={tier.id}
                        onClick={() => setSelectedTier(tier.id)}
                        className={`p-3 rounded border cursor-pointer transition-all ${selectedTier === tier.id
                            ? "border-orange-500 bg-orange-500/10"
                            : "border-neutral-700 hover:border-neutral-600"
                          }`}
                      >
                        <div className="flex justify-between items-center mb-1">
                          <div className="font-bold text-sm">{tier.name}</div>
                          {tier.apyBoost > 0 && (
                            <Badge className="bg-orange-500/20 text-orange-400 border-0 text-xs">
                              +{tier.apyBoost}%
                            </Badge>
                          )}
                        </div>
                        <div className="text-xs text-neutral-400">{tier.description}</div>
                      </div>
                    ))}
                  </div>
                </div>

                {/* Amount Input */}
                <div className="border-t border-neutral-700 pt-4">
                  <label className="block text-xs font-bold uppercase mb-2">Deposit Amount (USDC)</label>
                  <Input
                    type="number"
                    placeholder="0.00"
                    value={depositAmount}
                    onChange={(e) => setDepositAmount(e.target.value)}
                    className="bg-neutral-800 border-neutral-700 mb-2"
                    disabled={isApproving || isDepositing}
                  />
                  <div className="flex justify-between items-center">
                    <Button
                      variant="ghost"
                      size="sm"
                      className="text-xs text-neutral-400"
                      onClick={() => setDepositAmount(usdcBalance?.toString() || "0")}
                    >
                      Balance: {usdcBalance?.toFixed(2) || "0"} USDC
                    </Button>
                    <Button
                      variant="ghost"
                      size="sm"
                      className="text-xs text-orange-500"
                      onClick={() => setDepositAmount((Number(usdcBalance || 0) * 0.5).toFixed(2))}
                    >
                      50%
                    </Button>
                  </div>
                </div>

                {/* Summary */}
                <div className="border-t border-neutral-700 pt-4 space-y-3 text-sm">
                  <div className="flex justify-between">
                    <span className="text-neutral-400">Your deposit:</span>
                    <span>{depositAmount || "0"} USDC</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-neutral-400">Base APY:</span>
                    <span>{baseAPY.toFixed(1)}%</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-neutral-400">Lock boost:</span>
                    <span>+{selectedTierConfig?.apyBoost || 0}%</span>
                  </div>
                  <div className="flex justify-between font-bold text-lg pt-3 border-t border-neutral-700">
                    <span>Total APY:</span>
                    <span className="text-orange-500">{totalAPY.toFixed(1)}%</span>
                  </div>
                  {depositAmount && Number(depositAmount) > 0 && (
                    <div className="text-xs text-neutral-400 pt-2">
                      Estimated earnings: ~${(Number(depositAmount) * (totalAPY / 100)).toFixed(2)}/year
                    </div>
                  )}
                </div>

                <Button
                  className="w-full mt-4"
                  onClick={handleDeposit}
                  disabled={!account?.address || isApproving || isDepositing || !depositAmount || Number(depositAmount) <= 0}
                >
                  {isApproving ? (
                    <>
                      <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                      Approving USDC...
                    </>
                  ) : isDepositing ? (
                    <>
                      <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                      Depositing...
                    </>
                  ) : !account?.address ? (
                    "Connect Wallet"
                  ) : (
                    "Deposit USDC"
                  )}
                </Button>
              </CardContent>
            </Card>

            {/* Your Positions */}
            <Card>
              <CardHeader>
                <CardTitle className="text-lg">Your Positions</CardTitle>
              </CardHeader>
              <CardContent>
                {!account?.address ? (
                  <div className="text-sm text-neutral-400 text-center py-6">
                    Connect wallet to see your positions
                  </div>
                ) : isLoadingPositions ? (
                  <div className="flex items-center justify-center py-6">
                    <Loader2 className="w-6 h-6 animate-spin text-orange-500" />
                  </div>
                ) : !userPositions || userPositions.length === 0 ? (
                  <div className="text-sm text-neutral-400 text-center py-6">
                    No positions yet. Deposit to get started!
                  </div>
                ) : (
                  <div className="space-y-3">
                    {userPositions.map((position) => {
                      const tierInfo = tiers[position.tier]
                      const lockEndDate = new Date(Number(position.lockEndTime) * 1000)
                      const now = new Date()
                      const isLocked = position.isLocked
                      const daysRemaining = isLocked
                        ? Math.ceil((lockEndDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24))
                        : 0

                      return (
                        <div
                          key={position.id}
                          className="p-3 bg-neutral-900 border border-neutral-700 rounded space-y-2"
                        >
                          <div className="flex justify-between items-start">
                            <div>
                              <div className="font-bold text-sm">${position.depositAmountFormatted.toFixed(2)}</div>
                              <div className="text-xs text-neutral-400">{tierInfo?.name}</div>
                            </div>
                            {isLocked ? (
                              <Badge className="bg-orange-500/20 text-orange-400 border-0 text-xs">
                                Locked {daysRemaining}d
                              </Badge>
                            ) : (
                              <Badge className="bg-green-500/20 text-green-400 border-0 text-xs">
                                Unlocked
                              </Badge>
                            )}
                          </div>

                          <div className="text-xs text-neutral-500 space-y-1">
                            <div className="flex justify-between">
                              <span>APY Boost:</span>
                              <span>+{tierInfo?.apyBoost || 0}%</span>
                            </div>
                            <div className="flex justify-between">
                              <span>Shares:</span>
                              <span>{position.shares.toString()}</span>
                            </div>
                          </div>

                          <Button
                            size="sm"
                            variant="outline"
                            className="w-full mt-2"
                            onClick={() => handleWithdraw(position.id)}
                            disabled={isLocked || isWithdrawing}
                          >
                            {isWithdrawing ? (
                              <>
                                <Loader2 className="w-3 h-3 mr-1 animate-spin" />
                                Withdrawing...
                              </>
                            ) : isLocked ? (
                              `Locked for ${daysRemaining}d`
                            ) : (
                              "Withdraw"
                            )}
                          </Button>
                        </div>
                      )
                    })}
                  </div>
                )}
              </CardContent>
            </Card>
          </div>
        </div>
      </div>
    </main>
  )
}
