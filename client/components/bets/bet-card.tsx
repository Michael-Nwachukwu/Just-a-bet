import Link from "next/link"
import { Clock, DollarSign } from "lucide-react"
import { Card, CardContent } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"

interface BetCardProps {
  id: string
  description: string
  status: "pending" | "active" | "completed"
  category: string
  creator: string
  opponent?: string
  stake: number
  duration: string
  endDate: string
}

export default function BetCard({
  id,
  description,
  status,
  category,
  creator,
  opponent,
  stake,
  duration,
  endDate,
}: BetCardProps) {
  const statusColors = {
    pending: "bg-neutral-500/20 text-neutral-300",
    active: "bg-orange-500/20 text-orange-400",
    completed: "bg-cyan-500/20 text-cyan-400",
  }

  const categoryColors = {
    sports: "bg-blue-500/20 text-blue-400",
    crypto: "bg-purple-500/20 text-purple-400",
    politics: "bg-red-500/20 text-red-400",
    entertainment: "bg-pink-500/20 text-pink-400",
    other: "bg-neutral-500/20 text-neutral-400",
  }

  return (
    <Link href={`/bets/${id}`}>
      <Card className="hover:border-orange-500/40 transition-all hover:shadow-lg cursor-pointer h-full">
        <CardContent className="pt-6">
          {/* Header */}
          <div className="flex justify-between items-start mb-4">
            <Badge className={`${statusColors[status]} border-0`}>{status.toUpperCase()}</Badge>
            <Badge className={`${categoryColors[category as keyof typeof categoryColors]} border-0 text-xs`}>
              {category}
            </Badge>
          </div>

          {/* Description */}
          <p className="font-medium text-base mb-4 line-clamp-2">{description}</p>

          {/* Participants */}
          <div className="flex items-center justify-between mb-4 text-sm">
            <span className="text-neutral-400">{creator}</span>
            <span className="text-orange-500 font-bold">VS</span>
            <span className="text-neutral-400">{opponent || "🏠 House"}</span>
          </div>

          {/* Details Grid */}
          <div className="grid grid-cols-2 gap-4 mb-4 text-sm">
            <div className="flex items-center gap-2">
              <DollarSign className="w-4 h-4 text-orange-500" />
              <span className="text-neutral-400">{stake} USDC</span>
            </div>
            <div className="flex items-center gap-2">
              <Clock className="w-4 h-4 text-orange-500" />
              <span className="text-neutral-400">{duration}</span>
            </div>
          </div>

          {/* Footer */}
          <div className="text-xs text-neutral-500 border-t border-neutral-700 pt-3">Ends {endDate}</div>
        </CardContent>
      </Card>
    </Link>
  )
}
