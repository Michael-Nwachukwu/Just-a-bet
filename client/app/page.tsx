import Link from "next/link"
import { Handshake, Brain, TrendingUp, ArrowRight } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Card, CardContent } from "@/components/ui/card"

export default function Home() {
  return (
    <main className="pt-16">
      {/* Hero Section */}
      <section className="min-h-[600px] bg-gradient-to-b from-orange-500/10 to-transparent border-b border-orange-500/20 flex items-center justify-center">
        <div className="max-w-4xl mx-auto px-6 text-center py-20">
          <h1 className="text-5xl md:text-6xl font-bold mb-6 leading-tight">
            <span className="text-orange-500">BET</span> ON ANYTHING
            <br />
            <span className="text-cyan-400">WITH ANYONE</span>
          </h1>
          <p className="text-xl text-neutral-400 mb-8 max-w-2xl mx-auto">
            Create custom P2P bets or challenge the house with AI-powered risk assessment
          </p>

          <div className="flex flex-col sm:flex-row gap-4 justify-center mb-12">
            <Link href="/create">
              <Button size="lg">Create Your First Bet</Button>
            </Link>
            <Link href="/explore">
              <Button size="lg" variant="outline">
                Explore Bets
              </Button>
            </Link>
          </div>

          {/* Stats */}
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            {[
              { label: "Active Bets", value: "1,234" },
              { label: "Total Volume", value: "$2.5M" },
              { label: "Pool Liquidity", value: "$5.2M" },
            ].map((stat) => (
              <div key={stat.label} className="bg-neutral-900/50 border border-orange-500/20 rounded-lg p-4">
                <div className="text-3xl font-bold text-orange-500 mb-2">{stat.value}</div>
                <div className="text-sm text-neutral-400 uppercase tracking-wide">{stat.label}</div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Features Section */}
      <section className="py-20 border-b border-orange-500/20">
        <div className="max-w-6xl mx-auto px-6">
          <h2 className="text-4xl font-bold text-center mb-12 uppercase">
            Why <span className="text-orange-500">Just-a-Bet</span>
          </h2>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            {[
              {
                icon: Handshake,
                title: "Peer-to-Peer Betting",
                description:
                  "Create custom bets and challenge friends or anyone with a username. No middleman, no limits.",
              },
              {
                icon: Brain,
                title: "AI-Powered House Bets",
                description:
                  "Bet against liquidity pools protected by AI risk analysis. Fair odds, transparent verification.",
              },
              {
                icon: TrendingUp,
                title: "Earn While You Stake",
                description:
                  "All stakes generate yield through DeFi protocols. Win or lose, your capital works for you.",
              },
            ].map((feature, idx) => {
              const Icon = feature.icon
              return (
                <Card key={idx} className="hover:border-orange-500/40 transition-colors">
                  <CardContent className="pt-6">
                    <Icon className="w-12 h-12 text-orange-500 mb-4" />
                    <h3 className="text-lg font-bold mb-3 uppercase">{feature.title}</h3>
                    <p className="text-neutral-400 text-sm">{feature.description}</p>
                  </CardContent>
                </Card>
              )
            })}
          </div>
        </div>
      </section>

      {/* How It Works */}
      <section className="py-20 border-b border-orange-500/20">
        <div className="max-w-6xl mx-auto px-6">
          <h2 className="text-4xl font-bold text-center mb-12 uppercase">How It Works</h2>

          <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
            {[
              { num: "01", title: "Create Bet", desc: "Define your custom bet terms" },
              { num: "02", title: "Find Opponent", desc: "Invite friend or challenge the house" },
              { num: "03", title: "Stake USDC", desc: "Both parties stake, funds earn yield" },
              { num: "04", title: "Settle", desc: "Judge determines winner, automatic payout" },
            ].map((step, idx) => (
              <div key={idx} className="relative">
                <Card className="text-center">
                  <CardContent className="pt-6">
                    <div className="text-4xl font-bold text-orange-500 mb-3">{step.num}</div>
                    <h3 className="font-bold uppercase mb-2">{step.title}</h3>
                    <p className="text-sm text-neutral-400">{step.desc}</p>
                  </CardContent>
                </Card>
                {idx < 3 && (
                  <div className="hidden md:flex absolute -right-3 top-1/2 -translate-y-1/2">
                    <ArrowRight className="w-6 h-6 text-orange-500" />
                  </div>
                )}
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA Section */}
      <section className="py-20 bg-gradient-to-r from-orange-500/10 to-cyan-400/10 border-b border-orange-500/20">
        <div className="max-w-4xl mx-auto px-6 text-center">
          <h2 className="text-4xl font-bold mb-6">Ready to Start Betting?</h2>
          <Link href="/create">
            <Button size="xl">Connect Wallet & Create Bet</Button>
          </Link>
        </div>
      </section>
    </main>
  )
}
