import Groq from "groq-sdk"

const groq = new Groq({
  apiKey: process.env.NEXT_PUBLIC_GROQ_API_KEY,
  dangerouslyAllowBrowser: true, // Required for client-side usage
})

export interface AIValidationResult {
  isValid: boolean
  riskScore: number // 0-100 (higher = SAFER FOR HOUSE, lower = RISKIER FOR HOUSE)
  recommendedPool: string | null // Pool name that fits this bet, or null if no pool fits
  confidence: number // 0-100
  reasoning: string
  warnings?: string[]
}

export interface PoolOption {
  id: string
  name: string
  category: string
  description: string
  minStake: number
  maxStake: number
  targetAPY: number
}

export async function validateBetWithAI(
  description: string,
  outcomeDescription: string,
  duration: number, // in seconds
  stakeAmount: number, // in USDC (human readable, e.g., 100.50)
  tags: string[],
  availablePools: PoolOption[] // List of available liquidity pools
): Promise<AIValidationResult> {
  const durationInDays = Math.floor(duration / 86400)

  const poolsDescription = availablePools
    .map(
      (p) =>
        `- ${p.name} (${p.category}): ${p.description} | Min: $${p.minStake}, Max: $${p.maxStake}, APY: ${p.targetAPY}%`
    )
    .join("\n")

  const prompt = `You are a risk assessment AI working FOR THE HOUSE (liquidity pool) on a betting platform. Your job is to protect the house from risky bets that could drain liquidity.

IMPORTANT:
- You evaluate risk FROM THE HOUSE'S PERSPECTIVE
- High risk score = SAFE FOR HOUSE (house should accept)
- Low risk score = RISKY FOR HOUSE (house should reject)

Bet Details:
- Description: ${description}
- Outcome Criteria: ${outcomeDescription}
- Duration: ${durationInDays} days
- Stake Amount: $${stakeAmount} USDC
- Tags: ${tags.join(", ")}

Available Pools:
${poolsDescription}

Evaluation Criteria:

1. **Pool Assignment**: Which pool (if any) should accept this bet?
   - Match bet category to pool category
   - Check if stake amount fits pool's min/max limits
   - Consider if pool specializes in this type of bet
   - Return null if NO pool is suitable

2. **House Risk Assessment**: How risky is this bet FOR THE HOUSE?

   REJECT (0-39) if:
   - Easy win for bettor (e.g., "ETH will hit $2,980" when current price is $2,979)
   - Insider information advantage possible
   - Outcome cannot be objectively verified
   - Duration is too short for the bet type (manipulation risk)
   - Market manipulation potential
   - Bettor has unfair advantage

   CAUTION (40-59) if:
   - Some subjectivity in outcome determination
   - Moderate manipulation potential
   - Verification requires manual judgment
   - Duration is borderline for bet type

   ACCEPT (60-79) if:
   - Mostly objective outcome
   - Low manipulation risk
   - Fair duration for bet type
   - Verifiable through reliable sources
   - Both sides have reasonable chance

   STRONGLY ACCEPT (80-100) if:
   - Completely objective outcome (official scores, timestamps, etc.)
   - Zero manipulation potential
   - Perfect duration for bet type
   - Easy verification
   - House has EQUAL or BETTER odds than bettor

Risk Score Scale (FROM HOUSE'S PERSPECTIVE):
- 80-100: Very Safe for House - Accept immediately
- 60-79: Moderate Risk for House - Acceptable
- 40-59: High Risk for House - Reject
- 0-39: Very High Risk for House - Reject immediately

Response Format (JSON only):
{
  "isValid": boolean, // true if riskScore >= 60 AND recommendedPool is not null
  "riskScore": number, // 0-100 (higher = safer FOR HOUSE)
  "recommendedPool": string | null, // Pool name from available pools, or null if no pool fits
  "confidence": number, // 0-100
  "reasoning": string, // 2-3 sentences explaining WHY this is safe/risky FOR THE HOUSE
  "warnings": string[] // Optional array of specific concerns for the house
}

Examples:

BAD BET - High Risk for House (REJECT):
Input: "ETH will hit $2,980 in next 24 hours" (current price: $2,979)
{
  "isValid": false,
  "riskScore": 15,
  "recommendedPool": null,
  "confidence": 95,
  "reasoning": "EXTREMELY RISKY FOR HOUSE. Price target is only $1 away from current price with 24h duration. This is almost guaranteed to hit, making it an easy win for bettor and guaranteed loss for house. Clear manipulation/unfair advantage.",
  "warnings": ["Price proximity manipulation risk", "Almost certain loss for house", "Duration too short for price movement"]
}

BAD BET - No Suitable Pool (REJECT):
Input: "I will finish my homework by tomorrow" ($50 stake)
{
  "isValid": false,
  "riskScore": 20,
  "recommendedPool": null,
  "confidence": 90,
  "reasoning": "VERY RISKY FOR HOUSE. Personal bet with unverifiable outcome - only bettor knows if homework is done. House cannot verify result objectively. No pool specializes in personal unverifiable bets.",
  "warnings": ["Cannot verify outcome objectively", "Bettor has complete control over outcome", "No suitable pool"]
}

GOOD BET - Safe for House (ACCEPT):
Input: "Lakers will beat Celtics in tonight's NBA game" (7 day window, official game scheduled)
{
  "isValid": true,
  "riskScore": 85,
  "recommendedPool": "Sports Pool - NBA",
  "confidence": 90,
  "reasoning": "SAFE FOR HOUSE. Objective outcome verifiable via official NBA sources. Both teams have reasonable chance of winning based on historical data. Fair 50/50 probability for house. Duration matches game schedule.",
  "warnings": []
}

GOOD BET - Safe for House (ACCEPT):
Input: "Bitcoin will be above $100k by end of 2026" (bet created Jan 2026, 365 day duration)
{
  "isValid": true,
  "riskScore": 75,
  "recommendedPool": "Crypto Pool - Price Predictions",
  "confidence": 85,
  "reasoning": "ACCEPTABLE RISK FOR HOUSE. Long duration (365 days) reduces manipulation risk. Price target ($100k) is significantly different from current price, making outcome uncertain. Verifiable via major exchanges. Fair odds for both sides.",
  "warnings": ["Crypto volatility inherent", "Long-term price prediction"]
}

Now evaluate the bet above and respond with JSON only:`

  try {
    const completion = await groq.chat.completions.create({
      messages: [
        {
          role: "user",
          content: prompt,
        },
      ],
      model: "llama-3.3-70b-versatile", // Free tier model
      temperature: 0.3, // Lower temperature for more consistent risk assessment
      max_tokens: 500,
    })

    const responseText = completion.choices[0]?.message?.content || ""

    // Extract JSON from response (handle potential markdown code blocks)
    const jsonMatch = responseText.match(/\{[\s\S]*\}/)
    if (!jsonMatch) {
      throw new Error("Invalid AI response format")
    }

    const result = JSON.parse(jsonMatch[0]) as AIValidationResult

    // Validate result structure
    if (
      typeof result.isValid !== "boolean" ||
      typeof result.riskScore !== "number" ||
      typeof result.confidence !== "number" ||
      (result.recommendedPool !== null && typeof result.recommendedPool !== "string")
    ) {
      throw new Error("Invalid AI validation result structure")
    }

    // Double-check: isValid should be false if no pool or low risk score
    if (result.recommendedPool === null || result.riskScore < 60) {
      result.isValid = false
    }

    return result
  } catch (error) {
    console.error("AI validation error:", error)

    // Fallback: reject on error (fail-safe - protect the house)
    return {
      isValid: false,
      riskScore: 0,
      recommendedPool: null,
      confidence: 0,
      reasoning: "AI validation failed. Please try again or contact support.",
      warnings: ["AI service temporarily unavailable"],
    }
  }
}

// Example available pools configuration
export const AVAILABLE_POOLS: PoolOption[] = [
  {
    id: "sports-nba",
    name: "Sports Pool - NBA",
    category: "Sports",
    description: "NBA basketball games and player performance bets",
    minStake: 10,
    maxStake: 10000,
    targetAPY: 12,
  },
  {
    id: "sports-soccer",
    name: "Sports Pool - Soccer",
    category: "Sports",
    description: "International soccer matches and tournaments",
    minStake: 10,
    maxStake: 10000,
    targetAPY: 12,
  },
  {
    id: "crypto-price",
    name: "Crypto Pool - Price Predictions",
    category: "Crypto",
    description: "Cryptocurrency price movements (BTC, ETH, etc.)",
    minStake: 50,
    maxStake: 50000,
    targetAPY: 15,
  },
  {
    id: "crypto-events",
    name: "Crypto Pool - Events",
    category: "Crypto",
    description: "Crypto events like halvings, ETF approvals, protocol upgrades",
    minStake: 25,
    maxStake: 25000,
    targetAPY: 18,
  },
  {
    id: "entertainment",
    name: "Entertainment Pool",
    category: "Entertainment",
    description: "Movies, TV shows, awards ceremonies, box office predictions",
    minStake: 5,
    maxStake: 5000,
    targetAPY: 10,
  },
  {
    id: "politics",
    name: "Politics Pool",
    category: "Politics",
    description: "Elections, policy decisions, government actions",
    minStake: 20,
    maxStake: 20000,
    targetAPY: 14,
  },
]
