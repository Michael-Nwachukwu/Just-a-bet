"use client"

import { useState } from "react"
import Link from "next/link"
import { ArrowLeft } from "lucide-react"
import { useActiveAccount } from "thirdweb/react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Textarea } from "@/components/ui/textarea"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { validateBetWithAI, AIValidationResult, AVAILABLE_POOLS, getPoolCategoryKey } from "@/lib/groq-ai"
import { useCreateBet, useUSDCApproval, useUSDCAllowance, useUSDCBalance } from "@/lib/hooks/useBetCreation"
import { useContractAddresses } from "@/lib/hooks/useContracts"
import { useAllPoolsStats } from "@/lib/hooks/usePools"
import { durationToSeconds, formatUSDC } from "@/lib/utils"
import { toast } from "sonner"

type Step = "details" | "opponent" | "settings" | "ai-validation" | "review"

export default function CreateBetPage() {
  const account = useActiveAccount()
  const address = account?.address
  const isConnected = !!account
  const contractAddresses = useContractAddresses()
  const [step, setStep] = useState<Step>("details")
  const [formData, setFormData] = useState({
    description: "",
    outcomeCriteria: "",
    tags: [] as string[],
    opponentType: "friend" as "friend" | "house",
    opponentName: "",
    stakeAmount: "",
    duration: "",
    durationUnit: "days" as "hours" | "days" | "weeks",
  })
  const [currentTag, setCurrentTag] = useState("")
  const [aiValidation, setAiValidation] = useState<AIValidationResult | null>(null)
  const [isValidating, setIsValidating] = useState(false)

  // Contract hooks
  const { createBet, isPending: isCreating, isConfirming, isSuccess, hash } = useCreateBet()
  const { approve, isPending: isApproving, isConfirming: isApprovingConfirm, isSuccess: isApproved } = useUSDCApproval(
    contractAddresses.betFactory
  )
  const { allowance, refetch: refetchAllowance } = useUSDCAllowance(address, contractAddresses.betFactory)
  const { balance: usdcBalance } = useUSDCBalance(address)
  const { pools: allPools } = useAllPoolsStats()

  const handleAddTag = () => {
    if (currentTag && formData.tags.length < 5) {
      setFormData({ ...formData, tags: [...formData.tags, currentTag] })
      setCurrentTag("")
    }
  }

  const handleRemoveTag = (index: number) => {
    setFormData({ ...formData, tags: formData.tags.filter((_, i) => i !== index) })
  }

  const isStepValid = () => {
    switch (step) {
      case "details":
        return formData.description && formData.outcomeCriteria
      case "opponent":
        return formData.opponentType === "house" || formData.opponentName
      case "settings":
        return formData.stakeAmount && formData.duration
      case "ai-validation":
        return aiValidation?.isValid
      default:
        return true
    }
  }

  const handleNextStep = () => {
    if (!isStepValid()) return

    const steps: Step[] = ["details", "opponent", "settings", formData.opponentType === "house" ? "ai-validation" : "review"]
    const currentIndex = steps.indexOf(step)
    if (currentIndex < steps.length - 1) {
      setStep(steps[currentIndex + 1])

      // If moving to AI validation step, run AI validation
      if (steps[currentIndex + 1] === "ai-validation") {
        handleAIValidation()
      }
    }
  }

  const handlePrevStep = () => {
    const steps: Step[] = ["details", "opponent", "settings", formData.opponentType === "house" ? "ai-validation" : "review"]
    const currentIndex = steps.indexOf(step)
    if (currentIndex > 0) {
      setStep(steps[currentIndex - 1])
    }
  }

  const handleAIValidation = async () => {
    setIsValidating(true)
    try {
      const durationInSeconds = durationToSeconds(Number(formData.duration), formData.durationUnit)
      const result = await validateBetWithAI(
        formData.description,
        formData.outcomeCriteria,
        durationInSeconds,
        Number(formData.stakeAmount),
        formData.tags,
        AVAILABLE_POOLS
      )
      setAiValidation(result)
    } catch (error) {
      console.error("AI validation failed:", error)
      setAiValidation({
        isValid: false,
        riskScore: 0,
        recommendedPool: null,
        confidence: 0,
        reasoning: "Failed to validate with AI. Please try again.",
        warnings: ["AI service error"],
      })
    } finally {
      setIsValidating(false)
    }
  }

  const handleApprove = async () => {
    if (!formData.stakeAmount) return
    const toastId = toast.loading("Approving USDC spending...")

    try {
      await approve(formData.stakeAmount)
      await refetchAllowance()
      toast.success("USDC approved successfully!", { id: toastId })
    } catch (error) {
      toast.error("Failed to approve USDC", { id: toastId })
    }
  }

  const handleCreateBet = async () => {
    console.log("handleCreateBet")
    if (!isConnected) {
      toast.error("Please connect your wallet first")
      return
    }

    const durationInSeconds = durationToSeconds(Number(formData.duration), formData.durationUnit)
    const opponentIdentifier = formData.opponentType === "house" ? "HOUSE" : formData.opponentName

    console.log("opponentIdentifier", opponentIdentifier)

    // For house bets, prepend the category key as the first tag
    // The smart contract uses the first tag to select the pool via poolFactory.getPoolByCategory()
    let tagsToUse = formData.tags

    if (formData.opponentType === "house" && aiValidation?.recommendedPool) {
      const categoryKey = getPoolCategoryKey(aiValidation.recommendedPool)
      if (categoryKey) {
        // Prepend category key as first tag
        tagsToUse = [categoryKey, ...formData.tags]
        console.log("House bet - using category key as first tag:", categoryKey)
      } else {
        toast.error("Failed to map AI pool recommendation to category key")
        return
      }
    }

    const toastId = toast.loading("Creating bet...")

    try {
      await createBet({
        opponentIdentifier,
        stakeAmount: formData.stakeAmount,
        description: formData.description,
        outcomeDescription: formData.outcomeCriteria,
        duration: durationInSeconds,
        tags: tagsToUse,
      })
      toast.success("Bet created successfully!", { id: toastId })
    } catch (error: any) {
      console.error("Bet creation error:", error)

      // Parse error message for user-friendly display
      const errorMessage = error?.message || error?.toString() || ""

      if (errorMessage.includes("0xb79fbb6e") || errorMessage.includes("InsufficientPoolLiquidity")) {
        const poolName = aiValidation?.recommendedPool || "selected pool"
        toast.error(
          `Insufficient liquidity in ${poolName}. Please deposit USDC to the pool first or try a different bet category.`,
          { id: toastId, duration: 6000 }
        )
      } else if (errorMessage.includes("InsufficientAllowance")) {
        toast.error("Please approve USDC spending first", { id: toastId })
      } else if (errorMessage.includes("InsufficientBalance")) {
        toast.error("Insufficient USDC balance", { id: toastId })
      } else {
        toast.error("Failed to create bet. Please try again.", { id: toastId })
      }
    }
  }

  const getRiskColor = (score: number) => {
    if (score >= 80) return "text-green-600 bg-green-50 border-green-200"
    if (score >= 60) return "text-yellow-600 bg-yellow-50 border-yellow-200"
    if (score >= 40) return "text-orange-600 bg-orange-50 border-orange-200"
    return "text-red-600 bg-red-50 border-red-200"
  }

  const getRiskLabel = (score: number) => {
    if (score >= 80) return "Very Safe for House"
    if (score >= 60) return "Acceptable for House"
    if (score >= 40) return "Risky for House"
    return "Very Risky for House"
  }

  // Determine steps to show
  const steps = formData.opponentType === "house"
    ? ["details", "opponent", "settings", "ai-validation", "review"]
    : ["details", "opponent", "settings", "review"]
  const currentStepIndex = steps.indexOf(step)

  // Check if approval needed
  const needsApproval = allowance && formData.stakeAmount
    ? allowance < BigInt(Number(formData.stakeAmount) * 1e6)
    : true

  return (
    <main className="pt-16 pb-20">
      <div className="max-w-2xl mx-auto px-6 py-12">
        {/* Header */}
        <div className="mb-8">
          <Link href="/explore">
            <Button variant="ghost" className="mb-4">
              <ArrowLeft className="w-4 h-4 mr-2" />
              Back
            </Button>
          </Link>
          <h1 className="text-4xl font-bold uppercase mb-2">
            <span className="text-orange-500">CREATE</span> NEW BET
          </h1>
          <p className="text-neutral-400">Fill in the details for your custom bet</p>
        </div>

        {/* Wallet Connection Warning */}
        {!isConnected && (
          <Card className="mb-6 border-orange-500/50 bg-orange-500/10">
            <CardContent className="pt-6">
              <p className="text-orange-400 text-center">Please connect your wallet to create a bet</p>
            </CardContent>
          </Card>
        )}

        {/* Progress Indicator */}
        <div className="mb-12">
          <div className="flex justify-between mb-4">
            {steps.map((s, idx) => (
              <div key={s} className="flex flex-col items-center flex-1">
                <div
                  className={`w-10 h-10 rounded-full flex items-center justify-center font-bold mb-2 ${
                    idx <= currentStepIndex
                      ? "bg-orange-500 text-black"
                      : "bg-neutral-800 text-neutral-400 border border-neutral-700"
                  }`}
                >
                  {idx + 1}
                </div>
                <span className="text-xs text-neutral-500 uppercase text-center">{s.replace("-", " ")}</span>
              </div>
            ))}
          </div>
          <div className="h-1 bg-neutral-800 rounded-full overflow-hidden">
            <div
              className="h-full bg-orange-500 transition-all"
              style={{ width: `${((currentStepIndex + 1) / steps.length) * 100}%` }}
            ></div>
          </div>
        </div>

        {/* Step 1: Details */}
        {step === "details" && (
          <Card className="mb-6">
            <CardHeader>
              <CardTitle>Bet Details</CardTitle>
            </CardHeader>
            <CardContent className="space-y-6">
              {/* Description */}
              <div>
                <label className="block text-sm font-medium mb-2">What's the bet?</label>
                <Textarea
                  placeholder="E.g., Lakers will beat Celtics in tonight's game"
                  value={formData.description}
                  onChange={(e) => setFormData({ ...formData, description: e.target.value.substring(0, 280) })}
                  className="bg-neutral-800 border-neutral-700"
                />
                <div className="text-xs text-neutral-500 mt-2">{formData.description.length}/280 characters</div>
              </div>

              {/* Outcome Criteria */}
              <div>
                <label className="block text-sm font-medium mb-2">How will the winner be determined?</label>
                <Textarea
                  placeholder="E.g., Final score from official NBA website"
                  value={formData.outcomeCriteria}
                  onChange={(e) => setFormData({ ...formData, outcomeCriteria: e.target.value })}
                  className="bg-neutral-800 border-neutral-700"
                />
                <p className="text-xs text-neutral-500 mt-2">Be specific to avoid disputes</p>
              </div>

              {/* Tags */}
              <div>
                <label className="block text-sm font-medium mb-2">Tags (optional, max 5)</label>
                <div className="flex gap-2 mb-3">
                  <Input
                    placeholder="Add tag and press Add"
                    value={currentTag}
                    onChange={(e) => setCurrentTag(e.target.value)}
                    onKeyPress={(e) => e.key === "Enter" && (e.preventDefault(), handleAddTag())}
                    className="bg-neutral-800 border-neutral-700"
                  />
                  <Button onClick={handleAddTag} variant="outline" className="shrink-0 bg-transparent">
                    Add
                  </Button>
                </div>
                {formData.tags.length > 0 && (
                  <div className="flex flex-wrap gap-2">
                    {formData.tags.map((tag, idx) => (
                      <Badge
                        key={idx}
                        className="bg-orange-500/20 text-orange-400 border-0 cursor-pointer"
                        onClick={() => handleRemoveTag(idx)}
                      >
                        {tag} ×
                      </Badge>
                    ))}
                  </div>
                )}
              </div>

              <Button onClick={handleNextStep} className="w-full" disabled={!isStepValid()}>
                Next: Choose Opponent
              </Button>
            </CardContent>
          </Card>
        )}

        {/* Step 2: Opponent */}
        {step === "opponent" && (
          <div className="space-y-4 mb-6">
            {[
              {
                type: "friend" as const,
                icon: "👤",
                title: "Challenge a Friend",
                desc: "Invite a specific person by username or wallet address",
              },
              {
                type: "house" as const,
                icon: "🏛",
                title: "Bet Against the House",
                desc: "Matched instantly with liquidity pool. AI validates bet fairness.",
              },
            ].map((option) => (
              <Card
                key={option.type}
                className={`cursor-pointer transition-all ${
                  formData.opponentType === option.type ? "border-orange-500 bg-orange-500/5" : ""
                }`}
                onClick={() => setFormData({ ...formData, opponentType: option.type })}
              >
                <CardContent className="pt-6">
                  <div className="flex items-start gap-4">
                    <input
                      type="radio"
                      checked={formData.opponentType === option.type}
                      onChange={() => {}}
                      className="mt-1"
                    />
                    <div className="flex-1">
                      <h3 className="font-bold text-lg">{option.title}</h3>
                      <p className="text-neutral-400 text-sm">{option.desc}</p>

                      {option.type === "friend" && formData.opponentType === "friend" && (
                        <Input
                          placeholder="Enter username or wallet address"
                          value={formData.opponentName}
                          onChange={(e) => setFormData({ ...formData, opponentName: e.target.value })}
                          className="mt-4 bg-neutral-800 border-neutral-700"
                        />
                      )}

                      {option.type === "house" && formData.opponentType === "house" && (
                        <div className="mt-4 p-3 bg-neutral-900 border border-orange-500/20 rounded text-sm">
                          Your bet will be validated by AI to ensure fair odds for both sides
                        </div>
                      )}
                    </div>
                  </div>
                </CardContent>
              </Card>
            ))}

            <div className="flex gap-3">
              <Button onClick={handlePrevStep} variant="outline" className="flex-1 bg-transparent">
                Back
              </Button>
              <Button onClick={handleNextStep} className="flex-1" disabled={!isStepValid()}>
                Next: Settings
              </Button>
            </div>
          </div>
        )}

        {/* Step 3: Settings */}
        {step === "settings" && (
          <Card className="mb-6">
            <CardHeader>
              <CardTitle>Bet Settings</CardTitle>
            </CardHeader>
            <CardContent className="space-y-6">
              {/* USDC Balance Display */}
              {isConnected && usdcBalance !== undefined && (
                <div className="p-3 bg-neutral-900 border border-neutral-700 rounded">
                  <span className="text-sm text-neutral-400">Your USDC Balance: </span>
                  <span className="text-lg font-bold text-orange-400">{formatUSDC(usdcBalance)} USDC</span>
                </div>
              )}

              {/* Stake Amount */}
              <div>
                <label className="block text-sm font-medium mb-2">Stake Amount (USDC)</label>
                <Input
                  type="number"
                  placeholder="Amount"
                  min="1"
                  max="1000000"
                  step="0.01"
                  value={formData.stakeAmount}
                  onChange={(e) => setFormData({ ...formData, stakeAmount: e.target.value })}
                  className="bg-neutral-800 border-neutral-700"
                />
                <p className="text-xs text-neutral-500 mt-2">Both you and opponent will stake this amount</p>
                {formData.stakeAmount && (
                  <div className="mt-4 p-3 bg-orange-500/10 border border-orange-500/20 rounded">
                    <div className="text-lg font-bold text-orange-400">
                      Total Pool: {Number(formData.stakeAmount) * 2} USDC
                    </div>
                  </div>
                )}
              </div>

              {/* Duration */}
              <div>
                <label className="block text-sm font-medium mb-2">Bet Duration</label>
                <div className="flex gap-2">
                  <Input
                    type="number"
                    placeholder="Duration"
                    min="1"
                    value={formData.duration}
                    onChange={(e) => setFormData({ ...formData, duration: e.target.value })}
                    className="bg-neutral-800 border-neutral-700 flex-1"
                  />
                  <select
                    value={formData.durationUnit}
                    onChange={(e) => setFormData({ ...formData, durationUnit: e.target.value as any })}
                    className="bg-neutral-800 border border-neutral-700 rounded-md px-3 w-32"
                  >
                    <option value="hours">Hours</option>
                    <option value="days">Days</option>
                    <option value="weeks">Weeks</option>
                  </select>
                </div>
              </div>

              <div className="flex gap-3">
                <Button onClick={handlePrevStep} variant="outline" className="flex-1 bg-transparent">
                  Back
                </Button>
                <Button onClick={handleNextStep} className="flex-1" disabled={!isStepValid()}>
                  {formData.opponentType === "house" ? "Next: AI Validation" : "Review Bet"}
                </Button>
              </div>
            </CardContent>
          </Card>
        )}

        {/* Step 4: AI Validation (House only) */}
        {step === "ai-validation" && (
          <Card className="mb-6">
            <CardHeader>
              <CardTitle>AI Risk Assessment</CardTitle>
            </CardHeader>
            <CardContent className="space-y-6">
              {isValidating && (
                <div className="text-center py-8">
                  <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-orange-500 mx-auto mb-4"></div>
                  <p className="text-neutral-400">Analyzing bet with AI...</p>
                </div>
              )}

              {!isValidating && aiValidation && (
                <div className={`border-2 rounded-lg p-6 ${getRiskColor(aiValidation.riskScore)}`}>
                  <div className="flex items-center justify-between mb-4">
                    <h3 className="text-xl font-bold">House Risk Assessment</h3>
                    <span className="text-2xl font-bold">{aiValidation.riskScore}/100</span>
                  </div>

                  <div className="space-y-3">
                    <div>
                      <span className="font-semibold">Risk for House: </span>
                      {getRiskLabel(aiValidation.riskScore)}
                    </div>

                    {aiValidation.recommendedPool ? (
                      <>
                        <div className="bg-white bg-opacity-50 p-3 rounded-lg">
                          <span className="font-semibold">✓ Recommended Pool: </span>
                          <span className="font-bold">{aiValidation.recommendedPool}</span>
                        </div>

                        {/* Check pool liquidity */}
                        {(() => {
                          const pool = allPools?.find(p => p?.poolInfo?.name === aiValidation.recommendedPool)
                          const stakeAmount = Number(formData.stakeAmount) || 0
                          const availableLiquidity = pool ? pool.availableLiquidityFormatted : 0

                          if (pool && availableLiquidity < stakeAmount) {
                            return (
                              <div className="bg-red-100 border border-red-400 p-3 rounded-lg">
                                <span className="font-semibold text-red-700">⚠️ Insufficient Pool Liquidity</span>
                                <p className="text-sm mt-1 text-red-600">
                                  The {aiValidation.recommendedPool} only has ${availableLiquidity.toFixed(2)} USDC available,
                                  but your bet requires ${stakeAmount.toFixed(2)} USDC.
                                  <br />
                                  <strong>Action Required:</strong> Deposit USDC to the pool first or reduce your stake amount.
                                </p>
                              </div>
                            )
                          }

                          if (pool && availableLiquidity > 0) {
                            return (
                              <div className="bg-green-100 border border-green-400 p-3 rounded-lg text-sm">
                                <span className="font-semibold text-green-700">✓ Pool Liquidity Available</span>
                                <p className="text-green-600 mt-1">
                                  Pool has ${availableLiquidity.toFixed(2)} USDC available. Your ${stakeAmount.toFixed(2)} bet can be matched.
                                </p>
                              </div>
                            )
                          }

                          return null
                        })()}
                      </>
                    ) : (
                      <div className="bg-red-100 p-3 rounded-lg">
                        <span className="font-semibold">✗ No Suitable Pool Found</span>
                        <p className="text-sm mt-1">This bet doesn't match any available pool criteria.</p>
                      </div>
                    )}

                    <div>
                      <span className="font-semibold">AI Confidence: </span>
                      {aiValidation.confidence}%
                    </div>

                    <div>
                      <span className="font-semibold">Analysis: </span>
                      <p className="mt-1">{aiValidation.reasoning}</p>
                    </div>

                    {aiValidation.warnings && aiValidation.warnings.length > 0 && (
                      <div>
                        <span className="font-semibold">⚠️ Concerns for House:</span>
                        <ul className="list-disc list-inside mt-1">
                          {aiValidation.warnings.map((warning, idx) => (
                            <li key={idx}>{warning}</li>
                          ))}
                        </ul>
                      </div>
                    )}
                  </div>

                  {!aiValidation.isValid && (
                    <p className="text-sm mt-4 text-center font-semibold">
                      ⚠️ This bet is too risky for the House. Please modify your bet or try a different one.
                    </p>
                  )}
                </div>
              )}

              <div className="flex gap-3">
                <Button onClick={handlePrevStep} variant="outline" className="flex-1 bg-transparent">
                  Back
                </Button>
                <Button
                  onClick={() => {
                    if (aiValidation?.isValid) {
                      setStep("review")
                    } else {
                      handleAIValidation()
                    }
                  }}
                  className="flex-1"
                  disabled={isValidating || !aiValidation?.isValid}
                >
                  {aiValidation?.isValid ? "Review Bet" : "Re-validate"}
                </Button>
              </div>
            </CardContent>
          </Card>
        )}

        {/* Step 5: Review */}
        {step === "review" && (
          <Card className="mb-6">
            <CardHeader>
              <CardTitle>Review Your Bet</CardTitle>
            </CardHeader>
            <CardContent className="space-y-6">
              {/* Bet Details */}
              <div>
                <h3 className="font-bold uppercase text-sm mb-2 text-orange-500">Bet Details</h3>
                <div className="space-y-2 text-sm">
                  <p>{formData.description}</p>
                  <p className="text-neutral-500">Outcome: {formData.outcomeCriteria}</p>
                  {formData.tags.length > 0 && (
                    <div className="flex flex-wrap gap-2">
                      {formData.tags.map((tag, idx) => (
                        <Badge key={idx} className="bg-blue-500/20 text-blue-400 border-0">
                          {tag}
                        </Badge>
                      ))}
                    </div>
                  )}
                </div>
              </div>

              {/* Match Details */}
              <div className="border-t border-neutral-700 pt-4">
                <h3 className="font-bold uppercase text-sm mb-2 text-orange-500">Match Details</h3>
                <div className="text-sm">
                  {formData.opponentType === "friend" ? (
                    <p>Opponent: {formData.opponentName}</p>
                  ) : (
                    <>
                      <p>Matched with liquidity pool</p>
                      {aiValidation?.recommendedPool && (
                        <p className="text-orange-400 font-semibold mt-1">Pool: {aiValidation.recommendedPool}</p>
                      )}
                    </>
                  )}
                </div>
              </div>

              {/* Financial Details */}
              <div className="border-t border-neutral-700 pt-4">
                <h3 className="font-bold uppercase text-sm mb-2 text-orange-500">Financial Details</h3>
                <div className="space-y-2 text-sm">
                  <div className="flex justify-between">
                    <span>Your stake:</span>
                    <span className="text-orange-400">{formData.stakeAmount} USDC</span>
                  </div>
                  <div className="flex justify-between">
                    <span>Opponent stake:</span>
                    <span className="text-orange-400">{formData.stakeAmount} USDC</span>
                  </div>
                  <div className="flex justify-between font-bold">
                    <span>Total pool:</span>
                    <span className="text-orange-500">{Number(formData.stakeAmount) * 2} USDC</span>
                  </div>
                </div>
              </div>

              {/* Timeline */}
              <div className="border-t border-neutral-700 pt-4">
                <h3 className="font-bold uppercase text-sm mb-2 text-orange-500">Timeline</h3>
                <div className="text-sm">
                  <p>
                    Duration: {formData.duration} {formData.durationUnit}
                  </p>
                </div>
              </div>

              {/* Success/Error Messages */}
              {isSuccess && hash && (
                <div className="bg-green-500/10 border border-green-500/20 rounded p-4 text-green-400">
                  ✅ Bet created successfully! Transaction: {hash.slice(0, 10)}...
                </div>
              )}

              <div className="flex gap-3">
                <Button onClick={handlePrevStep} variant="outline" className="flex-1 bg-transparent">
                  Back
                </Button>

                {needsApproval && !isApproved ? (
                  <Button
                    onClick={handleApprove}
                    className="flex-1"
                    disabled={!isConnected || isApproving || isApprovingConfirm}
                  >
                    {isApproving || isApprovingConfirm ? "Approving USDC..." : "Approve USDC"}
                  </Button>
                ) : (
                  <Button
                    onClick={handleCreateBet}
                    className="flex-1"
                    disabled={!isConnected || isCreating || isConfirming || isSuccess}
                  >
                    {isCreating || isConfirming ? "Creating Bet..." : isSuccess ? "Bet Created!" : "Create Bet"}
                  </Button>
                )}
              </div>
            </CardContent>
          </Card>
        )}
      </div>
    </main>
  )
}
