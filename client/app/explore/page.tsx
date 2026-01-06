import { Suspense } from "react"
import ExploreBetsClient from "@/components/explore/explore-bets-client"

export default function ExploreBetsPage() {
  return (
    <Suspense fallback={null}>
      <ExploreBetsClient />
    </Suspense>
  )
}
