"use client"

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { AlertTriangle, Scale, User } from "lucide-react"

interface DisputeStatusCardProps {
  disputeReason: string
  assignedJudge?: string
  judgeUsername?: string
}

export function DisputeStatusCard({
  disputeReason,
  assignedJudge,
  judgeUsername,
}: DisputeStatusCardProps) {
  return (
    <Card className="border-red-500/50">
      <CardHeader>
        <div className="flex items-center gap-2">
          <Scale className="h-5 w-5 text-red-400" />
          <CardTitle className="text-lg text-red-400">Dispute in Progress</CardTitle>
        </div>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="bg-red-500/10 border border-red-500/30 rounded-lg p-4">
          <div className="flex items-start gap-3">
            <AlertTriangle className="h-5 w-5 text-red-400 mt-0.5 flex-shrink-0" />
            <div className="text-sm text-red-200">
              <p className="font-semibold mb-2">This bet is under dispute</p>
              <p className="text-red-300/80 mb-3">
                The parties disagreed on the outcome. A judge has been assigned to review the case and make a final decision.
              </p>
            </div>
          </div>
        </div>

        {/* Dispute Reason */}
        <div>
          <div className="text-sm font-medium text-neutral-400 mb-2">Dispute Reason</div>
          <div className="bg-neutral-900 border border-neutral-700 rounded-lg p-4 text-sm text-neutral-300">
            {disputeReason}
          </div>
        </div>

        {/* Assigned Judge */}
        <div>
          <div className="text-sm font-medium text-neutral-400 mb-2">Assigned Judge</div>
          <div className="bg-neutral-900 border border-neutral-700 rounded-lg p-4">
            {assignedJudge ? (
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-full bg-orange-500/20 flex items-center justify-center">
                  <User className="w-5 h-5 text-orange-400" />
                </div>
                <div>
                  <div className="font-medium">{judgeUsername || "Judge"}</div>
                  <div className="text-xs text-neutral-500 font-mono">{assignedJudge}</div>
                </div>
              </div>
            ) : (
              <div className="text-sm text-neutral-400 flex items-center gap-2">
                <div className="w-2 h-2 bg-orange-500 rounded-full animate-pulse" />
                Waiting for judge assignment...
              </div>
            )}
          </div>
        </div>

        {/* Status */}
        <div className="bg-orange-500/10 border border-orange-500/30 rounded-lg p-4 text-center">
          <Badge className="bg-orange-500/20 text-orange-400 border-0 mb-2">
            <Scale className="w-3 h-3 mr-1" />
            Under Review
          </Badge>
          <p className="text-sm text-orange-200/80">
            The judge will review all evidence and declare the final outcome. Both parties will be bound by the judge's decision.
          </p>
        </div>

        <p className="text-xs text-neutral-500 text-center">
          You will be notified when the judge makes a decision
        </p>
      </CardContent>
    </Card>
  )
}
