"use client"

import { useState, useEffect } from "react"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Badge } from "@/components/ui/badge"
import { useJudgeRegistration, useJudgeRegistryConfig } from "@/lib/hooks/useJudgeRegistry"
import { Shield, AlertCircle, CheckCircle, Clock } from "lucide-react"
import { toast } from "sonner"

export function JudgeRegistrationForm() {
  const [currentStep, setCurrentStep] = useState(0)
  const [stakeAmount, setStakeAmount] = useState("")

  const { config, isLoading: isConfigLoading } = useJudgeRegistryConfig()
  const {
    registerJudge,
    isPending,
    isConfirming,
    isSuccess,
    error,
  } = useJudgeRegistration(stakeAmount)

  useEffect(() => {
    if (isSuccess) {
      toast.success(`Successfully registered as judge with ${stakeAmount} MNT staked!`)
      setCurrentStep(3)
    }
  }, [isSuccess, stakeAmount])

  useEffect(() => {
    if (error) {
      toast.error("Failed to register as judge. Please try again.")
    }
  }, [error])

  const steps = [
    { title: "Requirements", icon: AlertCircle },
    { title: "Stake Amount", icon: Shield },
    { title: "Confirm", icon: CheckCircle },
    { title: "Success", icon: CheckCircle },
  ]

  const handleRegisterClick = () => {
    toast.loading("Registering as judge...")
    registerJudge()
  }

  const renderStep = () => {
    switch (currentStep) {
      case 0:
        return (
          <div className="space-y-6">
            <div className="p-4 bg-orange-500/10 border border-orange-500/30 rounded-lg">
              <h3 className="font-bold mb-2 flex items-center gap-2">
                <Shield className="h-5 w-5 text-orange-400" />
                Judge Requirements
              </h3>
              <ul className="space-y-2 text-sm text-neutral-300">
                <li>Minimum stake: {config ? config.minStakeFormatted + " MNT" : "Loading..."}</li>
                <li>Withdrawal lock period: {config ? config.withdrawalLockDays + " days" : "Loading..."}</li>
                <li>Slashing penalty: {config ? config.slashPercentageFormatted + "%" : "Loading..."}</li>
                <li>Must maintain good reputation to remain eligible</li>
              </ul>
            </div>
            <Button onClick={() => setCurrentStep(1)} className="w-full" disabled={isConfigLoading}>
              I Understand - Continue
            </Button>
          </div>
        )
      case 1:
        return (
          <div className="space-y-6">
            <div>
              <label className="block text-sm font-medium mb-2">Stake Amount (MNT)</label>
              <Input
                type="number"
                step="0.01"
                placeholder={config ? config.minStakeFormatted : "0.00"}
                value={stakeAmount}
                onChange={(e) => setStakeAmount(e.target.value)}
                className="bg-neutral-800 border-neutral-700"
              />
              <p className="text-xs text-neutral-400 mt-2">
                Minimum: {config ? config.minStakeFormatted + " MNT" : "Loading..."}
              </p>
            </div>
            <div className="flex gap-3">
              <Button onClick={() => setCurrentStep(0)} variant="outline" className="flex-1 bg-transparent">
                Back
              </Button>
              <Button
                onClick={() => setCurrentStep(2)}
                className="flex-1"
                disabled={!stakeAmount || !config || parseFloat(stakeAmount) < parseFloat(config.minStakeFormatted)}
              >
                Continue
              </Button>
            </div>
          </div>
        )
      case 2:
        return (
          <div className="space-y-6">
            <div className="p-4 bg-neutral-800 rounded-lg space-y-3">
              <div className="flex justify-between">
                <span className="text-neutral-400">Stake Amount</span>
                <span className="font-bold">{stakeAmount} MNT</span>
              </div>
            </div>
            <div className="flex gap-3">
              <Button onClick={() => setCurrentStep(1)} variant="outline" className="flex-1 bg-transparent" disabled={isPending || isConfirming}>
                Back
              </Button>
              <Button onClick={handleRegisterClick} className="flex-1" disabled={isPending || isConfirming}>
                {isPending || isConfirming ? <Clock className="mr-2 h-4 w-4 animate-spin" /> : <Shield className="mr-2 h-4 w-4" />}
                {isPending ? "Confirm in Wallet..." : isConfirming ? "Registering..." : "Register as Judge"}
              </Button>
            </div>
          </div>
        )
      case 3:
        return (
          <div className="space-y-6 text-center">
            <div className="flex justify-center">
              <div className="h-16 w-16 bg-green-500/20 rounded-full flex items-center justify-center">
                <CheckCircle className="h-10 w-10 text-green-400" />
              </div>
            </div>
            <div>
              <h3 className="text-2xl font-bold mb-2">Registration Successful!</h3>
              <p className="text-neutral-400">You are now registered as a judge with {stakeAmount} MNT staked.</p>
            </div>
            <Button onClick={() => window.location.href = "/judges"} className="w-full">
              View Judge Dashboard
            </Button>
          </div>
        )
      default:
        return null
    }
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>Register as Judge</CardTitle>
        <div className="mt-4">
          <div className="flex items-center justify-between mb-2">
            {steps.map((step, index) => (
              <div key={index} className={"flex items-center " + (index < steps.length - 1 ? "flex-1" : "")}>
                <div className={"h-8 w-8 rounded-full flex items-center justify-center text-sm font-medium " + (index <= currentStep ? "bg-orange-500 text-white" : "bg-neutral-700 text-neutral-400")}>
                  {index < currentStep ? "✓" : index + 1}
                </div>
                {index < steps.length - 1 && <div className={"flex-1 h-1 mx-2 " + (index < currentStep ? "bg-orange-500" : "bg-neutral-700")} />}
              </div>
            ))}
          </div>
        </div>
      </CardHeader>
      <CardContent>{renderStep()}</CardContent>
    </Card>
  )
}
