import { ArrowLeft, Calendar } from "lucide-react"
import Link from "next/link"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"

export default function BetDetailsPage({ params }: { params: { id: string } }) {
  // Mock data
  const bet = {
    id: params.id,
    description: "Lakers will beat Celtics in tonight's game",
    status: "active" as const,
    category: "sports",
    createdAt: "Jan 10, 2024",
    creator: { name: "john_doe", address: "0x1234...5678" },
    opponent: { name: "jane_smith", address: "0x8765...4321" },
    stake: 100,
    duration: "1 day",
    endDate: "Jan 15, 2024",
    outcomeCriteria: "Final score from official NBA website at end of regulation time. No overtime scoring counts.",
  }

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
                    <Badge className="mb-3 bg-orange-500/20 text-orange-400 border-0">{bet.status.toUpperCase()}</Badge>
                    <CardTitle className="text-2xl">{bet.description}</CardTitle>
                  </div>
                  <Badge className="bg-blue-500/20 text-blue-400 border-0">{bet.category}</Badge>
                </div>
                <p className="text-sm text-neutral-500 mt-4">Created {bet.createdAt}</p>
              </CardHeader>
              <CardContent className="space-y-6">
                {/* Outcome Criteria */}
                <div>
                  <h3 className="font-bold uppercase text-sm mb-3">How to Determine Winner</h3>
                  <div className="bg-neutral-900 border border-neutral-700 rounded p-4 text-neutral-300">
                    {bet.outcomeCriteria}
                  </div>
                </div>

                {/* Participants */}
                <div>
                  <h3 className="font-bold uppercase text-sm mb-4">Participants</h3>
                  <div className="grid grid-cols-2 gap-4">
                    {[bet.creator, bet.opponent].map((participant, idx) => (
                      <div key={idx} className="bg-neutral-900 border border-neutral-700 rounded p-4">
                        <div className="font-bold mb-2">{participant.name}</div>
                        <div className="text-xs text-neutral-500 mb-3">{participant.address}</div>
                        <Badge className="bg-orange-500/20 text-orange-400 border-0 text-xs">
                          {idx === 0 ? "Creator" : "Opponent"}
                        </Badge>
                      </div>
                    ))}
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
                        <div className="text-sm text-neutral-500">Jan 10, 2024</div>
                      </div>
                    </div>
                    <div className="flex gap-4 ml-1 border-l border-neutral-700 pl-3">
                      <div className="w-2 h-2 bg-orange-500 rounded-full mt-2 -ml-4"></div>
                      <div>
                        <div className="font-medium">Ends</div>
                        <div className="text-sm text-neutral-500">{bet.endDate}</div>
                      </div>
                    </div>
                  </div>
                </div>
              </CardContent>
            </Card>
          </div>

          {/* Sidebar */}
          <div className="space-y-6">
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
                    <Calendar className="w-4 h-4 text-orange-500" />
                    <span className="font-medium">{bet.duration}</span>
                  </div>
                  <div className="text-sm text-neutral-500">Ends {bet.endDate} at 3:00 PM</div>
                </div>

                {/* Category */}
                <div className="border-t border-neutral-700 pt-4">
                  <Badge className="bg-blue-500/20 text-blue-400 border-0">{bet.category}</Badge>
                </div>

                {/* Action */}
                <Button className="w-full mt-4">View Details</Button>
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
                    <div className="font-medium">Bet created by @{bet.creator.name}</div>
                    <div className="text-xs text-neutral-500 mt-1">{bet.createdAt}</div>
                  </div>
                  <div className="border-b border-neutral-700 pb-4 last:border-0">
                    <div className="font-medium">Matched by @{bet.opponent.name}</div>
                    <div className="text-xs text-neutral-500 mt-1">Jan 11, 2024</div>
                  </div>
                </div>
              </CardContent>
            </Card>
          </div>
        </div>
      </div>
    </main>
  )
}
