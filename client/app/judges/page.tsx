"use client"

import { Suspense } from "react"
import { useActiveAccount } from "thirdweb/react"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Card, CardContent } from "@/components/ui/card"
import { JudgeCard } from "@/components/judges/judge-card"
import { JudgeStakingPanel } from "@/components/judges/judge-staking-panel"
import { JudgeRegistrationForm } from "@/components/judges/judge-registration-form"
import { useJudgeProfile, useActiveJudgesCount, useJudgeRegistryConfig } from "@/lib/hooks/useJudgeRegistry"
import { Scale, Users, TrendingUp } from "lucide-react"

function JudgesPageContent() {
  const account = useActiveAccount()
  const address = account?.address
  const isConnected = !!account
  const { profile } = useJudgeProfile(address)
  const { count } = useActiveJudgesCount()
  const { config } = useJudgeRegistryConfig()

  const isRegistered = profile?.isActive || false

  return (
    <div className="container mx-auto px-4 py-20">
      {/* Header */}
      <div className="mb-8">
        <div className="flex items-center gap-3 mb-4">
          <Scale className="h-8 w-8 text-orange-500" />
          <h1 className="text-4xl font-bold">Judge Registry</h1>
        </div>
        <p className="text-neutral-400">
          Become a judge and earn rewards by resolving bet disputes fairly and transparently
        </p>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
        <Card>
          <CardContent className="pt-6">
            <div className="flex items-center gap-3">
              <Users className="h-8 w-8 text-cyan-400" />
              <div>
                <div className="text-sm text-neutral-400">Active Judges</div>
                <div className="text-2xl font-bold">{count ? count.toString() : "0"}</div>
              </div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="pt-6">
            <div className="flex items-center gap-3">
              <Scale className="h-8 w-8 text-orange-400" />
              <div>
                <div className="text-sm text-neutral-400">Min Stake</div>
                <div className="text-2xl font-bold">{config ? config.minStakeFormatted + " MNT" : "Loading..."}</div>
              </div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="pt-6">
            <div className="flex items-center gap-3">
              <TrendingUp className="h-8 w-8 text-green-400" />
              <div>
                <div className="text-sm text-neutral-400">Lock Period</div>
                <div className="text-2xl font-bold">{config ? config.withdrawalLockDays + " days" : "Loading..."}</div>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Tabs */}
      <Tabs defaultValue={isRegistered ? "my-position" : "register"} className="w-full">
        <TabsList className="w-full justify-start bg-transparent border-b border-neutral-700 h-auto p-0 rounded-none">
          <TabsTrigger
            value="judges"
            className="data-[state=active]:border-b-2 data-[state=active]:border-orange-500 rounded-none"
          >
            All Judges
          </TabsTrigger>
          {isConnected && isRegistered && (
            <TabsTrigger
              value="my-position"
              className="data-[state=active]:border-b-2 data-[state=active]:border-orange-500 rounded-none"
            >
              My Position
            </TabsTrigger>
          )}
          {isConnected && !isRegistered && (
            <TabsTrigger
              value="register"
              className="data-[state=active]:border-b-2 data-[state=active]:border-orange-500 rounded-none"
            >
              Register
            </TabsTrigger>
          )}
        </TabsList>

        <TabsContent value="judges" className="mt-8">
          <div className="mb-6">
            <h2 className="text-2xl font-bold mb-2">Active Judges</h2>
            <p className="text-neutral-400">Browse all registered judges in the network</p>
          </div>
          
          {count && Number(count) > 0 ? (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              <Card>
                <CardContent className="pt-6 text-center text-neutral-400">
                  <p>Judge listing coming soon</p>
                  <p className="text-sm mt-2">Total judges: {count.toString()}</p>
                </CardContent>
              </Card>
            </div>
          ) : (
            <Card>
              <CardContent className="pt-6 text-center text-neutral-400">
                <p>No judges registered yet. Be the first!</p>
              </CardContent>
            </Card>
          )}
        </TabsContent>

        {isConnected && isRegistered && (
          <TabsContent value="my-position" className="mt-8 space-y-6">
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              <div>
                <h2 className="text-2xl font-bold mb-4">Your Judge Profile</h2>
                {address && <JudgeCard judgeAddress={address as `0x${string}`} showActions={false} />}
              </div>
              <div>
                <h2 className="text-2xl font-bold mb-4">Manage Stake</h2>
                <JudgeStakingPanel />
              </div>
            </div>
          </TabsContent>
        )}

        {isConnected && !isRegistered && (
          <TabsContent value="register" className="mt-8">
            <div className="max-w-2xl mx-auto">
              <JudgeRegistrationForm />
            </div>
          </TabsContent>
        )}
      </Tabs>

      {/* Not Connected State */}
      {!isConnected && (
        <Card className="mt-8">
          <CardContent className="pt-6 text-center">
            <p className="text-neutral-400">Connect your wallet to view and interact with the judge registry</p>
          </CardContent>
        </Card>
      )}
    </div>
  )
}

export default function JudgesPage() {
  return (
    <Suspense
      fallback={
        <div className="container mx-auto px-4 py-8">
          <div className="animate-pulse space-y-4">
            <div className="h-8 bg-neutral-800 rounded w-1/4"></div>
            <div className="h-4 bg-neutral-800 rounded w-1/2"></div>
          </div>
        </div>
      }
    >
      <JudgesPageContent />
    </Suspense>
  )
}
