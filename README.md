# Just-a-Bet 🎲

A decentralized peer-to-peer betting platform built on Mantle Sepolia testnet with AI-powered risk validation, liquidity pools, and dispute resolution through a decentralized judge system.

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Key Features](#key-features)
- [Smart Contract System](#smart-contract-system)
- [Deployed Contracts](#deployed-contracts)
- [User Flows](#user-flows)
- [Tech Stack](#tech-stack)
- [Getting Started](#getting-started)
- [Project Structure](#project-structure)
- [Testing](#testing)
- [License](#license)

---

## 🎯 Overview

Just-a-Bet is a trustless betting platform that enables users to:
- Create and accept P2P bets with collateral
- Bet against the house using AI-validated odds
- Provide liquidity and earn yield from betting fees
- Resolve disputes through a decentralized judge system
- Register unique usernames on-chain

### Platform Statistics
- **Network**: Mantle Sepolia (ChainID: 5003)
- **Stablecoin**: MockUSDC (ERC20)
- **Liquidity Pools**: 4 category-specific CDO pools
- **Bet Types**: P2P & House Bets

---

## 🏗 Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Frontend (Next.js)                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐             │
│  │  Create Bet  │  │  My Bets     │  │  Liquidity   │             │
│  │  Page        │  │  Dashboard   │  │  Pools       │             │
│  └──────────────┘  └──────────────┘  └──────────────┘             │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
                    ┌───────────▼──────────────┐
                    │   Thirdweb SDK           │
                    │   (Wallet & Contracts)   │
                    └───────────┬──────────────┘
                                │
        ┌───────────────────────┼────────────────────────┐
        │                       │                        │
┌───────▼────────┐    ┌────────▼─────────┐    ┌────────▼─────────┐
│  BetFactory    │    │  CDOPoolFactory  │    │  UsernameRegistry│
│  - Create P2P  │    │  - 4 Pools       │    │  - Register      │
│  - House Bets  │    │  - Deposits      │    │  - Resolve       │
│  - AI Validate │    │  - Withdrawals   │    │  - Query         │
└────────┬───────┘    └─────────┬────────┘    └──────────────────┘
         │                      │
         │          ┌───────────▼──────────┐
         │          │   BetYieldVault      │
         │          │   - Yield Generation │
         │          │   - Strategy Mgmt    │
         │          └──────────────────────┘
         │
┌────────▼───────────────────────────────────────┐
│              Individual Bet Contract            │
│  ┌──────────────┐  ┌───────────────────────┐  │
│  │ Bet Details  │  │  Resolution System    │  │
│  │ - Stakes     │  │  - Declare Outcome    │  │
│  │ - Parties    │  │  - Dispute Window     │  │
│  │ - Expiry     │  │  - Finalize          │  │
│  └──────────────┘  └──────────┬────────────┘  │
└──────────────────────────────┼────────────────┘
                               │
                    ┌──────────▼──────────┐
                    │  DisputeManager     │
                    │  - Assign Judges    │
                    │  - Vote Tracking    │
                    │  - Final Resolution │
                    └─────────────────────┘
```

---

## ✨ Key Features

### 1. **Dual Betting Modes**
- **P2P Bets**: Create custom bets with any opponent
- **House Bets**: Bet against the platform with AI-validated odds and liquidity from CDO pools

### 2. **Category-Specific Liquidity Pools**
Four specialized CDO (Collateralized Debt Obligation) pools:
- **Sports** (NBA focus)
- **Crypto** (BTC focus)
- **Politics**
- **General**

Each pool offers:
- 4 lock-up tiers (Flexible, 30d, 90d, 365d)
- APY boosts for longer locks
- Automated yield generation
- Tradeable CDO tokens

### 3. **AI-Powered Risk Validation**
- Real-time odds calculation for house bets
- Risk assessment based on bet category, amount, and pool liquidity
- Automatic bet approval/rejection based on risk thresholds

### 4. **Decentralized Dispute Resolution**
- **Judge System**: Community-elected judges with voting power
- **24-Hour Dispute Window**: Time for parties to challenge outcomes
- **Multi-Judge Voting**: Requires consensus for final resolution
- **Transparent Process**: All dispute reasons and votes on-chain

### 5. **Username Registry**
- On-chain username registration (3-32 characters)
- Unique, transferable identities
- Username resolution for addresses
- Profile metadata support

### 6. **Bet Resolution Flow**
```
Active Bet
    │
    ├──> Expires
    │      │
    │      ├──> Party A Declares Outcome
    │      │       │
    │      │       ├──> 24h Dispute Window
    │      │       │      │
    │      │       │      ├──> No Dispute → Finalize → Resolved
    │      │       │      │
    │      │       │      └──> Dispute Raised → Judge Vote → Resolved
    │      │       │
    │      │       └──> Winner Claims Funds
    │      │
    └──> Cancelled (if unfunded)
```

---

## 📝 Smart Contract System

### Core Contracts

#### **BetFactory** (`0x07ecE77248D4E3f295fdFaeC1C86e257098A434a`)
Main factory for creating bets.

**Key Functions:**
```solidity
// Create P2P bet
function createBet(
    address opponent,
    string description,
    uint256 stakeAmount,
    uint256 duration,
    string[] tags
) external returns (address betAddress)

// Create house bet (validated by AI)
function createHouseBet(
    string description,
    uint256 userStake,
    uint256 houseStake,
    uint256 duration,
    string[] tags,
    uint8 category
) external returns (address betAddress)

// Query bets
function getAllBets() external view returns (address[])
function getBetsForUser(address user) external view returns (address[])
```

**Events:**
```solidity
event BetCreated(address indexed betAddress, address indexed creator, BetType betType)
event HouseBetCreated(address indexed betAddress, uint8 indexed category, uint256 userStake, uint256 houseStake)
```

---

#### **Bet Contract** (Clone, deployed per bet)
Individual bet contract managing lifecycle and resolution.

**States:**
```solidity
enum BetState {
    Created,              // 0: Just created
    Active,               // 1: Both parties funded
    AwaitingResolution,   // 2: Outcome declared, in dispute window
    Disputed,             // 3: Dispute raised
    Resolved,             // 4: Finalized, winner can claim
    Cancelled             // 5: Cancelled before funding
}
```

**Key Functions:**
```solidity
// Bet lifecycle
function acceptBet() external          // Opponent accepts P2P bet
function fundCreator() external        // Creator funds their stake
function fundOpponent() external       // Opponent funds their stake
function cancelBet() external          // Cancel unfunded bet

// Resolution
function declareOutcome(Outcome _outcome) external  // Declare winner after expiry
function raiseDispute() external                    // Challenge declared outcome
function finalizeResolution() external              // Finalize after dispute window
function claimWinnings() external                   // Winner claims funds

// Views
function getBetDetails() external view returns (...)
function resolution() external view returns (...)
```

**Resolution Flow:**
1. Bet expires → Party declares outcome (CreatorWins/OpponentWins/Draw)
2. Other party has 24 hours to:
   - **Do nothing** → Implicit agreement, either party finalizes after 24h
   - **Raise dispute** → Sends to DisputeManager for judge voting
3. After finalization → Winner claims funds (loser's stake + their own)

---

#### **CDOPoolFactory** (`0xc616918154D7a9dB5D78480d1d53820d4423b298`)
Factory for creating and managing category-specific liquidity pools.

**Key Functions:**
```solidity
// Create new pool
function createPool(
    string poolName,
    uint8 categoryId,
    address cdoToken
) external returns (address poolAddress)

// Query pools
function getPoolByCategory(uint8 categoryId) external view returns (address)
function getAllPools() external view returns (address[])
```

---

#### **CDOPool** (4 instances)
Individual liquidity pool for a category.

**Lock Tiers:**
| Tier | Name      | Lock Period | APY Boost |
|------|-----------|-------------|-----------|
| 0    | Flexible  | 0 days      | 0%        |
| 1    | 30 Days   | 30 days     | +20%      |
| 2    | 90 Days   | 90 days     | +50%      |
| 3    | 365 Days  | 365 days    | +100%     |

**Key Functions:**
```solidity
// Liquidity provision
function deposit(uint256 amount, uint8 tier) external
function withdraw(uint256 positionId) external
function getUserPositions(address user) external view returns (Position[])

// House betting (called by BetFactory)
function matchHouseBet(uint256 amount) external returns (bool)
function returnHouseStake(uint256 amount) external

// Stats
function stats() external view returns (
    uint256 totalDeposits,
    uint256 totalBetsMatched,
    uint256 totalVolumeMatched,
    uint256 totalYieldDistributed,
    uint256 poolBalance,
    uint256 activeMatchedAmount,
    uint256 totalShares
)
```

**Position Structure:**
```solidity
struct Position {
    uint256 depositAmount;  // Amount deposited in USDC
    uint256 shares;         // Pool shares received
    uint256 depositedAt;    // Timestamp
    uint256 lockUntil;      // Unlock timestamp (0 for flexible)
    uint256 tier;           // Lock tier (0-3)
}
```

---

#### **BetRiskValidator** (`0x4d0884D03f2fA409370D0F97c6AbC4dA4A8F03d6`)
AI-powered risk assessment for house bets.

**Key Functions:**
```solidity
function validateHouseBet(
    uint256 userStake,
    uint256 houseStake,
    string description,
    uint8 categoryId,
    address poolAddress
) external view returns (bool approved, string reason)
```

**Validation Criteria:**
- Pool has sufficient liquidity (userStake + houseStake ≤ available)
- Odds are within acceptable range (1.1x to 10x)
- Bet amount meets minimum/maximum thresholds
- Pool utilization rate is healthy

---

#### **DisputeManager** (`0x3335BaEEDdD1Cc77B8Ab9acBF862764812337a3F`)
Manages disputed bets through judge voting.

**Key Functions:**
```solidity
// Called by Bet contract when dispute raised
function initiateDispute(
    address betAddress,
    address creator,
    address opponent,
    Outcome declaredOutcome
) external returns (uint256 disputeId)

// Judge voting
function submitVote(
    uint256 disputeId,
    Outcome vote
) external

// Finalize after voting period
function finalizeDispute(uint256 disputeId) external
```

**Voting Process:**
1. Dispute raised → 3 judges randomly assigned
2. 48-hour voting window
3. Majority vote wins (2/3 required)
4. If no consensus → Escalates or refunds stakes

---

#### **JudgeRegistry** (`0x9f3eB17a20a4E57Ed126F34061b0E40dF3a4f5C2`)
Registry of community judges.

**Key Functions:**
```solidity
// Judge management
function registerJudge() external
function activateJudge(address judge) external onlyOwner
function deactivateJudge(address judge) external onlyOwner

// Query
function getActiveJudges() external view returns (address[])
function isActiveJudge(address judge) external view returns (bool)
function getJudgeStats(address judge) external view returns (...)
```

**Judge Requirements:**
- Manual activation by admin (for MVP)
- Good voting history
- Minimum reputation threshold

---

#### **UsernameRegistry** (`0x2C0457F82B57148e8363b4589bb3294b23AE7625`)
On-chain username system.

**Key Functions:**
```solidity
// Registration
function registerUsername(string username) external payable

// Resolution
function getProfile(address user) external view returns (string username, ...)
function resolveUsername(string username) external view returns (address)
function resolveIdentifier(string identifier) external view returns (address)

// Validation
function isUsernameAvailable(string username) external view returns (bool)
```

**Username Rules:**
- 3-32 characters
- Alphanumeric + underscore only
- Case-insensitive uniqueness
- One username per address

---

#### **BetYieldVault** (`0x12ccF0F4A22454d53aBdA56a796a08e93E947256`)
Yield generation for liquidity pools.

**Key Functions:**
```solidity
function depositToStrategy(uint256 amount) external
function withdrawFromStrategy(uint256 amount) external
function harvestYield() external returns (uint256 yield)
```

Currently using `MockYieldStrategy` for testing (generates ~10% APY).

---

## 📍 Deployed Contracts

### Mantle Sepolia Testnet (ChainID: 5003)

#### Core System
| Contract | Address | Purpose |
|----------|---------|---------|
| **MockUSDC** | `0xA1103E6490ab174036392EbF5c798C9DaBAb24EE` | Stablecoin for bets |
| **BetFactory** | `0x07ecE77248D4E3f295fdFaeC1C86e257098A434a` | Bet creation |
| **UsernameRegistry** | `0x2C0457F82B57148e8363b4589bb3294b23AE7625` | On-chain usernames |

#### Liquidity System
| Contract | Address | Purpose |
|----------|---------|---------|
| **CDOPoolFactory** | `0xc616918154D7a9dB5D78480d1d53820d4423b298` | Pool factory |
| **BetYieldVault** | `0x12ccF0F4A22454d53aBdA56a796a08e93E947256` | Yield generation |
| **BetRiskValidator** | `0x4d0884D03f2fA409370D0F97c6AbC4dA4A8F03d6` | AI risk validation |
| **MockYieldStrategy** | `0xE9b224bE25B2823250f4545709A11e8ebAC18b34` | Yield strategy |

#### CDO Pools
| Pool | Address | CDO Token | Category |
|------|---------|-----------|----------|
| **Sports (NBA)** | `0x2b2E21596A22f6Ab273E41F4BB28Dcc1D0be6D85` | `0xDb02a4d36c750FE94986ac4E9B736EA31ac9B32e` | Sports |
| **Crypto (BTC)** | `0xd0B0aF8488D7000c6658a0E7A50566dAa6B6E631` | `0xEb3aE9248B253e4dEbfd2A1A822cCB129D618bF5` | Crypto |
| **Politics** | `0xb8886E5638d17Fe6161976FD4Ca27d2DaAC9029f` | `0xA8586243CBf327B4c8Fd061B2a1F2B0CCD495297` | Politics |
| **General** | `0x8Ea7a72e5deF4323e6DF86c668F88e4aBc5E2f92` | `0x330cF1F85e0c97A5FA06BF49Eaf24947beE1a799` | General |

#### Dispute System
| Contract | Address | Purpose |
|----------|---------|---------|
| **JudgeRegistry** | `0x9f3eB17a20a4E57Ed126F34061b0E40dF3a4f5C2` | Judge management |
| **DisputeManager** | `0x3335BaEEDdD1Cc77B8Ab9acBF862764812337a3F` | Dispute resolution |

---

## 👤 User Flows

### 1. Create P2P Bet

```
User A (Creator)
    │
    ├──> Connect Wallet
    │
    ├──> Navigate to "Create Bet"
    │
    ├──> Enter Bet Details:
    │     ├─ Description: "Lakers will win next game"
    │     ├─ Stake: 100 USDC
    │     ├─ Duration: 7 days
    │     ├─ Opponent: 0x... (or leave empty for public)
    │     └─ Category: Sports
    │
    ├──> Approve USDC (if first time)
    │
    ├──> Fund Creator Stake (100 USDC)
    │
    ├──> Bet Created → Status: "Pending"
    │
    └──> Share bet link with opponent

User B (Opponent)
    │
    ├──> Receive bet link
    │
    ├──> View bet details
    │
    ├──> Click "Accept Bet"
    │
    ├──> Approve USDC
    │
    ├──> Fund Opponent Stake (100 USDC)
    │
    └──> Bet Active → Status: "Active"
         ├─ Total pot: 200 USDC
         └─ Expires in 7 days

After 7 days:
    │
    ├──> Bet expires
    │
    ├──> User A declares: "I Won"
    │     └─> 24-hour dispute window starts
    │
    ├──> User B has two options:
    │     │
    │     ├─ Option 1: Do Nothing
    │     │     └─> After 24h, either party clicks "Finalize"
    │     │           └─> Bet Resolved → Winner claims 200 USDC
    │     │
    │     └─ Option 2: Click "Raise Dispute"
    │           └─> Dispute sent to judges
    │                 └─> 3 judges vote over 48h
    │                       └─> Majority wins → Bet Resolved
```

---

### 2. Create House Bet

```
User
    │
    ├──> Navigate to "Create Bet" → "House Bet"
    │
    ├──> Enter Bet Details:
    │     ├─ Description: "Bitcoin will hit $100k by EOY"
    │     ├─ Your Stake: 50 USDC
    │     ├─ Category: Crypto
    │     └─ Duration: 30 days
    │
    ├──> AI Risk Validator analyzes:
    │     ├─ Category: Crypto
    │     ├─ Crypto Pool Liquidity: 10,000 USDC available
    │     ├─ Calculated Odds: 2.5x (house stakes 125 USDC)
    │     └─ Risk Assessment: ✅ APPROVED
    │
    ├──> Display Odds: "Win 125 USDC (2.5x return)"
    │
    ├──> User confirms
    │
    ├──> Approve USDC
    │
    ├──> Fund Stake (50 USDC)
    │
    ├──> Bet Created & Auto-Matched:
    │     ├─ User Stake: 50 USDC
    │     ├─ House Stake: 125 USDC (from Crypto Pool)
    │     └─ Total Pot: 175 USDC
    │
    └──> Bet Active → Expires in 30 days

After 30 days:
    │
    ├──> User declares outcome
    │     │
    │     ├─ If User Wins:
    │     │     └─> Claims 175 USDC (3.5x profit)
    │     │           └─> Pool loses 125 USDC
    │     │
    │     └─ If House Wins:
    │           └─> Pool gains 50 USDC
    │                 └─> Distributed to liquidity providers
```

---

### 3. Provide Liquidity

```
Liquidity Provider
    │
    ├──> Navigate to "Pools"
    │
    ├──> View 4 Pools:
    │     ├─ Sports (NBA): $25,000 TVL, 85% utilization
    │     ├─ Crypto (BTC): $18,000 TVL, 60% utilization
    │     ├─ Politics: $12,000 TVL, 40% utilization
    │     └─ General: $30,000 TVL, 70% utilization
    │
    ├──> Select "Crypto Pool"
    │
    ├──> Choose Lock Tier:
    │     ├─ Flexible: No lock, 10% APY
    │     ├─ 30 Days: +20% boost → 12% APY
    │     ├─ 90 Days: +50% boost → 15% APY
    │     └─ 365 Days: +100% boost → 20% APY ⭐
    │
    ├──> Enter Amount: 1,000 USDC
    │
    ├──> Approve USDC
    │
    ├──> Deposit
    │
    └──> Receive:
          ├─ Pool Shares (proportional to deposit)
          ├─ CDO Tokens (tradeable, represents position)
          └─ Position locked until: [Date] (if tier > 0)

Earning Yield:
    │
    ├──> Yield Sources:
    │     ├─ House bet fees (2% of losing stakes)
    │     ├─ Bet creation fees
    │     └─ Yield farming via BetYieldVault
    │
    └──> Yield auto-compounds to your shares

Withdrawal:
    │
    ├──> Navigate to "Pools" → "My Positions"
    │
    ├──> Select position
    │     │
    │     ├─ If Locked: Shows countdown timer
    │     │     └─> "Unlocks in 25 days"
    │     │
    │     └─ If Unlocked: Can withdraw
    │
    ├──> Click "Withdraw"
    │
    └──> Receive: Principal + Accumulated Yield
```

---

### 4. Dispute Resolution

```
Bet in Dispute
    │
    ├──> Party raises dispute within 24h window
    │
    ├──> DisputeManager assigns 3 random judges
    │
    ├──> Judges notified via:
    │     ├─ On-chain event
    │     └─ Platform notification
    │
    ├──> Each Judge Reviews:
    │     ├─ Bet description
    │     ├─ Declared outcome
    │     ├─ Dispute reason
    │     └─ Bet category/tags
    │
    ├──> Voting Period: 48 hours
    │     │
    │     ├─ Judge 1 votes: "CreatorWins"
    │     ├─ Judge 2 votes: "CreatorWins"
    │     └─ Judge 3 votes: "OpponentWins"
    │
    ├──> After 48h:
    │     └─> Tally votes: 2-1 in favor of "CreatorWins"
    │
    ├──> DisputeManager resolves bet
    │     └─> Calls bet.resolveByJudges(CreatorWins)
    │
    └──> Bet Resolved
          └─> Winner claims funds
```

---

### 5. Register Username

```
User
    │
    ├──> Navigate to "Profile"
    │
    ├──> Click "Register Username"
    │
    ├──> Enter username: "cryptoking"
    │     │
    │     ├──> Real-time validation:
    │     │     ├─ Length: 3-32 chars ✅
    │     │     ├─ Characters: alphanumeric + _ ✅
    │     │     └─ Available: ✅ (checks on-chain)
    │     │
    │     └──> Shows: "✅ cryptoking is available"
    │
    ├──> Pay registration fee (0.001 USDC)
    │
    ├──> Confirm transaction
    │
    └──> Username registered!
          ├─ Displayed in profile
          ├─ Used in bet cards
          └─ Searchable by other users
```

---

## 🛠 Tech Stack

### Frontend
- **Framework**: Next.js 15 (App Router)
- **Language**: TypeScript
- **Styling**: Tailwind CSS
- **UI Components**: Radix UI + shadcn/ui
- **Web3**: Thirdweb SDK
- **State Management**: React Query (@tanstack/react-query)
- **Forms**: React Hook Form + Zod validation
- **Notifications**: Sonner (toast)

### Smart Contracts
- **Language**: Solidity 0.8.24
- **Framework**: Foundry
- **Testing**: Forge (unit & integration tests)
- **Standards**: ERC20, ERC1167 (clones), Ownable, ReentrancyGuard

### Blockchain
- **Network**: Mantle Sepolia Testnet
- **RPC**: https://rpc.sepolia.mantle.xyz
- **Explorer**: https://explorer.sepolia.mantle.xyz

---

## 🚀 Getting Started

### Prerequisites
- Node.js 18+
- npm or yarn
- Foundry (for smart contracts)
- Wallet with Mantle Sepolia testnet MNT (for gas)

### Frontend Setup

```bash
# Navigate to client directory
cd client

# Install dependencies
npm install

# Set up environment variables
cp .env.example .env.local

# Add your Thirdweb client ID
echo "NEXT_PUBLIC_THIRDWEB_CLIENT_ID=your_client_id" >> .env.local

# Run development server
npm run dev
```

Frontend will be available at `http://localhost:3000`

### Smart Contract Setup

```bash
# Navigate to contracts directory
cd contracts

# Install dependencies
forge install

# Compile contracts
forge build

# Run tests
forge test

# Run tests with gas reporting
forge test --gas-report

# Deploy to Mantle Sepolia (requires PRIVATE_KEY in .env)
forge script script/DeployMultiPool.s.sol:DeployMultiPool \
  --rpc-url https://rpc.sepolia.mantle.xyz \
  --broadcast \
  --legacy
```

### Get Test Tokens

1. **MNT (for gas)**:
   - Use Mantle Sepolia faucet: https://faucet.sepolia.mantle.xyz

2. **MockUSDC**:
   - Contract: `0xA1103E6490ab174036392EbF5c798C9DaBAb24EE`
   - Call `mint(address to, uint256 amount)` function
   - Or use frontend "Get Test USDC" button

---

## 📁 Project Structure

```
Just-a-Bet/
├── client/                          # Next.js frontend
│   ├── app/                         # App router pages
│   │   ├── page.tsx                 # Home/explore page
│   │   ├── create/                  # Bet creation
│   │   ├── my-bets/                 # User's bets dashboard
│   │   ├── bets/[id]/               # Individual bet details
│   │   ├── pools/                   # Liquidity pools
│   │   ├── judges/                  # Judge dashboard
│   │   └── profile/                 # User profile
│   ├── components/                  # React components
│   │   ├── bets/                    # Bet-related components
│   │   │   ├── bet-card.tsx         # Bet display card
│   │   │   ├── outcome-declaration-card.tsx
│   │   │   ├── outcome-waiting-card.tsx
│   │   │   ├── dispute-response-card.tsx
│   │   │   ├── claim-winnings-card.tsx
│   │   │   └── dispute-status-card.tsx
│   │   ├── pools/                   # Pool components
│   │   ├── judges/                  # Judge components
│   │   ├── layout/                  # Layout components (navbar, etc.)
│   │   └── ui/                      # shadcn/ui components
│   ├── lib/                         # Utilities & hooks
│   │   ├── hooks/                   # Custom React hooks
│   │   │   ├── useBets.ts           # Bet data fetching
│   │   │   ├── useBetActions.ts     # Bet actions (accept, fund, etc.)
│   │   │   ├── useBetCreation.ts    # Bet creation logic
│   │   │   ├── usePools.ts          # Pool data & actions
│   │   │   ├── useJudgeRegistry.ts  # Judge system
│   │   │   └── useUsernameRegistry.ts
│   │   ├── contracts/               # Contract ABIs & addresses
│   │   │   ├── abis/                # Contract ABIs
│   │   │   └── addresses.ts         # Deployed addresses
│   │   ├── utils/                   # Helper functions
│   │   │   └── bet-helpers.ts       # Bet data transformations
│   │   ├── thirdweb.ts              # Thirdweb client config
│   │   └── wagmi.ts                 # Legacy Wagmi config
│   └── package.json
│
├── contracts/                       # Foundry project
│   ├── src/                         # Smart contracts
│   │   ├── core/                    # Core betting contracts
│   │   │   ├── Bet.sol              # Individual bet contract
│   │   │   ├── BetFactory.sol       # Bet factory
│   │   │   └── BetYieldVault.sol    # Yield management
│   │   ├── liquidity/               # Liquidity system
│   │   │   ├── CDOPool.sol          # Liquidity pool
│   │   │   ├── CDOPoolFactory.sol   # Pool factory
│   │   │   ├── CDOToken.sol         # Pool share tokens
│   │   │   └── BetRiskValidator.sol # AI risk validator
│   │   ├── judges/                  # Dispute resolution
│   │   │   ├── JudgeRegistry.sol    # Judge management
│   │   │   └── DisputeManager.sol   # Dispute handler
│   │   ├── identity/                # Identity system
│   │   │   └── UsernameRegistry.sol # Username registry
│   │   ├── strategies/              # Yield strategies
│   │   │   └── MockYieldStrategy.sol
│   │   └── test/                    # Test contracts
│   │       └── MockUSDC.sol         # Test USDC token
│   ├── test/                        # Contract tests
│   │   ├── BetFactory.t.sol
│   │   ├── BetFactoryMultiPool.t.sol
│   │   ├── CDOPoolFactory.t.sol
│   │   ├── DisputeIntegration.t.sol
│   │   └── DisputeManager.t.sol
│   ├── script/                      # Deployment scripts
│   │   └── DeployMultiPool.s.sol
│   ├── foundry.toml                 # Foundry config
│   └── deployed-addresses.m         # Deployed addresses log
│
└── README.md                        # This file
```

---

## 🧪 Testing

### Smart Contract Tests

```bash
cd contracts

# Run all tests
forge test

# Run specific test file
forge test --match-path test/BetFactory.t.sol

# Run tests with verbosity
forge test -vvv

# Run tests with gas reporting
forge test --gas-report

# Run tests with coverage
forge coverage
```

### Test Coverage

Key test files:
- `BetFactory.t.sol`: P2P bet creation, lifecycle
- `BetFactoryMultiPool.t.sol`: House bets, multi-pool integration
- `CDOPoolFactory.t.sol`: Pool creation, deposits, withdrawals
- `DisputeIntegration.t.sol`: End-to-end dispute resolution
- `DisputeManager.t.sol`: Judge voting, dispute finalization

### Frontend Testing

```bash
cd client

# Run development server for manual testing
npm run dev

# Build for production (checks for errors)
npm run build

# Lint code
npm run lint
```

---

## 📊 Key Metrics & Limits

### Bet Limits
- **Minimum Stake**: 1 USDC
- **Maximum Stake**: No hard limit (subject to pool liquidity for house bets)
- **Minimum Duration**: 1 hour
- **Maximum Duration**: 365 days
- **Dispute Window**: 24 hours
- **Judge Voting Period**: 48 hours

### Pool Limits
- **Minimum Deposit**: 10 USDC
- **Maximum Utilization**: 85% (house bets)
- **Lock Tiers**: 4 (Flexible, 30d, 90d, 365d)
- **Maximum Odds**: 10x
- **Minimum Odds**: 1.1x

### Fees
- **Bet Creation**: 0% (free)
- **House Bet Matching**: 2% of losing stake
- **Username Registration**: 0.001 USDC
- **Dispute Filing**: 0 (free, to encourage fairness)

---

## 🔐 Security Considerations

### Smart Contracts
- ✅ **ReentrancyGuard**: All state-changing functions protected
- ✅ **Access Control**: Ownable pattern for admin functions
- ✅ **Minimal Clones**: Gas-efficient bet deployment (ERC1167)
- ✅ **Checks-Effects-Interactions**: Following CEI pattern
- ✅ **SafeERC20**: Safe token transfers
- ⚠️ **Not Audited**: Testnet only, no security audit yet

### Known Limitations (MVP)
1. **Judge Centralization**: Manual judge activation by admin
2. **No Slashing**: Judges not penalized for incorrect votes
3. **Simple Yield**: MockYieldStrategy, not production-ready
4. **No Oracle Integration**: Outcomes must be manually declared
5. **Limited Dispute Evidence**: No file/image upload for disputes

---

## 🛣 Roadmap

### Phase 1: MVP ✅ (Current)
- [x] P2P betting
- [x] House betting with multi-pool system
- [x] Dispute resolution with judges
- [x] Username registry
- [x] Basic UI/UX

### Phase 2: Mainnet Launch
- [ ] Security audit
- [ ] Deploy to Mantle mainnet
- [ ] Migrate to real USDC
- [ ] Production yield strategies (Aave, Compound)
- [ ] Improved AI risk model

### Phase 3: Decentralization
- [ ] Judge staking & slashing
- [ ] Community governance (DAO)
- [ ] Protocol fee distribution
- [ ] Judge reputation system

### Phase 4: Advanced Features
- [ ] Oracle integration (Chainlink, API3)
- [ ] Automated outcome resolution
- [ ] Multi-party bets (3+ participants)
- [ ] Bet templates & marketplace
- [ ] Mobile app (React Native)
- [ ] Social features (friends, leaderboards)

### Phase 5: Cross-Chain
- [ ] Bridge to other L2s (Arbitrum, Optimism)
- [ ] Cross-chain liquidity
- [ ] Unified CDO tokens

---

## 🤝 Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines
- Follow existing code style
- Write tests for new features
- Update documentation
- Keep commits atomic and descriptive

---

## 📄 License

This project is licensed under the MIT License.

---

## 🔗 Links

- **Frontend**: [Deployed on Vercel] (Coming soon)
- **Contracts**: Mantle Sepolia Explorer
  - [BetFactory](https://explorer.sepolia.mantle.xyz/address/0x07ecE77248D4E3f295fdFaeC1C86e257098A434a)
  - [CDOPoolFactory](https://explorer.sepolia.mantle.xyz/address/0xc616918154D7a9dB5D78480d1d53820d4423b298)
- **Documentation**: This README
- **Support**: [GitHub Issues](https://github.com/yourusername/just-a-bet/issues)

---

## 📞 Support

For questions, issues, or feature requests:
- Open an issue on GitHub
- Contact: [Your contact info]

---

## 🎉 Acknowledgments

- Built with [Foundry](https://book.getfoundry.sh/)
- UI powered by [shadcn/ui](https://ui.shadcn.com/)
- Web3 integration via [Thirdweb](https://thirdweb.com/)
- Deployed on [Mantle Network](https://mantle.xyz/)

---

**Built with ❤️ by the Just-a-Bet team**
