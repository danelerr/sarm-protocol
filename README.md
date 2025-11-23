# 🛡️ SAGE Protocol

**Stablecoin Automated Governance & Economics**

A Uniswap v4 Hook that makes stablecoin liquidity "risk-aware" using S&P Global SSA ratings with dynamic fee rewards.

## 🎯 Overview

SAGE Protocol integrates S&P Global Stablecoin Stability Assessment (SSA) ratings into Uniswap v4 to create a **reward-based, non-punitive risk model**:

- ✅ **Reward premium stablecoins** with 30% fee discounts (ratings 1-2 → 0.70% vs 1.00%)
- ✅ **Standard fees** for normal stablecoins (ratings 3-5 → 1.00%)
- ✅ **No swap blocking** - all transactions allowed, only fee adjustments
- ✅ **Transparent risk signals** for LPs and traders

## 🏆 Built For ETHGlobal Buenos Aires 2025

**Competing in:**
- 🦄 **Uniswap v4 Stable-Asset Hooks Track**
- 🔗 **Chainlink** - S&P Global SSA integration (simulated)
- 📊 **The Graph Amp** - Risk analytics & SQL dashboards

**Live Deployment:** [Base Sepolia](https://sepolia.basescan.org)
- Oracle: `0x444a4967487B655675c7F3EF0Ec68f93ae9f6866`
- Hook: `0x828e95D79fC2fD10882C13042edDe1071BB2E080`

**Live Demo:** https://sage-r7emdhhbb-danelerrs-projects.vercel.app

## 🏗️ Architecture

### Core Contracts

#### 1. **SSAOracleAdapter** (`src/oracles/SSAOracleAdapter.sol`)
Single source of truth for S&P Global SSA ratings on-chain.

**Features:**
- Stores token ratings (1-5 scale)
- Chainlink DataLink integration ready (simulated for hackathon)
- Emits `RatingUpdated` events for off-chain indexing
- Owner-controlled rating updates

**Deployed:** `0x444a4967487B655675c7F3EF0Ec68f93ae9f6866`

#### 2. **SAGEHook** (`src/hooks/SAGEHook.sol`)
Uniswap v4 Hook implementing reward-based risk model.

**Features:**
- Reads ratings from SSAOracleAdapter before each swap
- Dynamic fee calculation: Rating 1-2 → 70 bps, Rating 3-5 → 100 bps
- No swap blocking - always allows transactions
- Emits `RiskCheck` and `FeeOverrideApplied` for analytics

**Deployed:** `0x828e95D79fC2fD10882C13042edDe1071BB2E080`

#### 3. **Pools Initialized**
- **USDC/USDT** - Both rating 1 → 0.70% fee (30% discount)
- **USDC/DAI** - Max rating 3 → 1.00% fee (standard)
- **DAI/USDT** - Max rating 3 → 1.00% fee (standard)

### Frontend Stack

#### Web3 Swap Interface (`frontend/`)
Built with **Next.js 16** + **wagmi** + **viem**

**Features:**
- Real-time token rating display from on-chain oracle
- Dynamic fee calculator showing risk premium
- MetaMask wallet integration
- Responsive UI with Tailwind CSS + shadcn/ui

**Live:** https://sage-r7emdhhbb-danelerrs-projects.vercel.app

#### Amp Analytics Dashboard (`amp-demo/`)
SQL-powered analytics with **The Graph Amp**

**Features:**
- Real-time event indexing (RiskCheck, RatingUpdated, FeeOverrideApplied)
- SQL queries for risk analytics
- Historical rating change tracking
- Fee distribution by risk rating

**Queries Available:**
```sql
-- Recent risk checks
SELECT * FROM "eth_global/sarm@dev".risk_check 
ORDER BY block_num DESC LIMIT 10

-- Rating update history
SELECT * FROM "eth_global/sarm@dev".rating_updated
WHERE token = '0x036CbD...' ORDER BY block_num DESC

-- Fee distribution by rating
SELECT effective_rating, AVG(fee) as avg_fee
FROM "eth_global/sarm@dev".fee_override_applied
GROUP BY effective_rating
```

## 🚀 Quick Start

### Prerequisites

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Install Node.js dependencies (for frontend)
npm install -g pnpm
```

### 1. Clone & Setup

```bash
git clone https://github.com/danelerr/sarm-protocol.git
cd sarm-protocol

# Install Solidity dependencies
forge install

# Copy environment
cp .env.example .env
```

### 2. Deploy Contracts (Already Deployed on Base Sepolia)

```bash
# Set your private key in .env
echo "PRIVATE_KEY=0x..." >> .env

# Deploy everything
forge script script/DeploySAGE.s.sol \
  --rpc-url https://sepolia.base.org \
  --broadcast \
  --verify
```

**What it deploys:**
1. ✅ SSAOracleAdapter with initial ratings (USDC=1, USDT=1, DAI=3)
2. ✅ SAGEHook with CREATE2 address validation
3. ✅ 3 Uniswap v4 pools with dynamic fees

### 3. Run Frontend

```bash
cd frontend

# Install dependencies
npm install

# Start dev server
npm run dev

# Open http://localhost:3000
```

### 4. Run Amp Analytics (Optional)

```bash
cd amp-demo

# Install dependencies
pnpm install

# Initialize Amp
ampctl init

# Start Amp server (separate terminal)
ampd dev --config ~/.amp/config.toml

# Deploy dataset (separate terminal)
pnpm amp deploy --reference "eth_global/sarm@dev"

# Start dashboard
pnpm dev

# Open http://localhost:5173
```
## 📊 How It Works

### Rating System (S&P Global SSA Scale)

| Rating | Risk Level | Fee Applied | Description |
|--------|-----------|-------------|-------------|
| 1 | Minimal | 0.70% | Well-collateralized, audited (30% discount) |
| 2 | Low | 0.70% | Strong fundamentals (30% discount) |
| 3 | Medium | 1.00% | Standard risk (normal fee) |
| 4 | Elevated | 1.00% | Higher risk (normal fee) |
| 5 | High | 1.00% | Significant concerns (normal fee) |

### Dynamic Fee Logic

```solidity
function beforeSwap(PoolKey calldata key, ...) {
    // Read ratings from oracle
    uint8 rating0 = oracle.getRating(token0);
    uint8 rating1 = oracle.getRating(token1);
    
    // Take best (lowest) rating for fee calculation
    uint8 effectiveRating = min(rating0, rating1);
    
    // Apply fee: 70 bps for ratings 1-2, 100 bps for 3-5
    uint24 fee = (effectiveRating <= 2) ? 70 : 100;
    
    // Override pool fee for this swap
    poolManager.updateDynamicLPFee(key, fee);
    
    // Emit for analytics
    emit FeeOverrideApplied(poolId, effectiveRating, fee);
}
```

### Example: USDC/DAI Swap

1. User initiates swap USDC → DAI
2. Hook reads ratings: USDC=1 (minimal risk), DAI=3 (medium risk)
3. Effective rating = min(1, 3) = 1
4. Fee applied = 0.70% (30% discount from standard 1.00%)
5. Swap executes with reduced fee
6. Event emitted for off-chain indexing

## 🧪 Testing

```bash
# Run all tests (26/26 passing)
forge test

# Run with verbosity
forge test -vvv

# Test specific functionality
forge test --match-test testDynamicFeeApplication
forge test --match-test testRatingUpdate
forge test --match-test testRiskCheck
```

**Test Coverage:**
- ✅ Dynamic fee calculation (ratings 1-5)
- ✅ Pool initialization with hook
- ✅ Rating updates and event emissions
- ✅ Risk mode transitions
- ✅ Swap execution with fee overrides
- ✅ Edge cases and error conditions

# Run with gas reporting
forge test --gas-report

# Run with coverage
forge coverage
```
## 📁 Project Structure

```
sarm-protocol/
├── src/
│   ├── hooks/
│   │   └── SAGEHook.sol              # Main Uniswap v4 Hook
│   ├── oracles/
│   │   └── SSAOracleAdapter.sol      # S&P SSA rating oracle
│   ├── interfaces/
│   │   └── IDataLinkVerifier.sol     # Chainlink DataLink interface
│   └── mocks/
│       └── MockERC20.sol             # Test tokens
├── test/
│   └── SAGEHook.t.sol                # Forge tests (26/26 ✅)
├── script/
│   └── DeploySAGE.s.sol              # Deployment with CREATE2
├── frontend/                          # Next.js swap interface
│   ├── app/                          # App router pages
│   ├── components/                   # React components
│   ├── hooks/                        # Custom React hooks
│   └── lib/                          # Contracts & Web3 config
├── amp-demo/                         # The Graph Amp analytics
│   ├── amp.config.ts                 # Dataset configuration
│   └── app/src/components/           # SQL dashboard
├── DEPLOYMENT.md                     # Deployment details
└── foundry.toml                      # Foundry config
```

## 🎯 Key Features

### ✅ Reward-Based Risk Model
- **No punitive measures** - swaps never blocked
- **30% fee discount** for premium stablecoins (ratings 1-2)
- **Standard pricing** for normal stablecoins (ratings 3-5)
- **Transparent signals** - users see ratings before swapping

### ✅ Production-Ready Architecture
- CREATE2 deployment for deterministic hook addresses
- Uniswap v4 address validation (required permission bits)
- Event-driven analytics (The Graph Amp integration)
- Comprehensive test coverage (26/26 tests passing)

### ✅ Real On-Chain Deployment
- Deployed on Base Sepolia testnet
- 3 pools initialized with real tokens
- Frontend reading live on-chain data
- Verified contracts on Basescan

## 🔗 Links

- **Live Demo:** https://sage-r7emdhhbb-danelerrs-projects.vercel.app
- **Contracts (Base Sepolia):**
  - Oracle: [`0x444a4967487B655675c7F3EF0Ec68f93ae9f6866`](https://sepolia.basescan.org/address/0x444a4967487B655675c7F3EF0Ec68f93ae9f6866)
  - Hook: [`0x828e95D79fC2fD10882C13042edDe1071BB2E080`](https://sepolia.basescan.org/address/0x828e95D79fC2fD10882C13042edDe1071BB2E080)
- **GitHub:** https://github.com/danelerr/sarm-protocol

## 🏆 Bounties & Prizes

### Uniswap v4 Hooks
**✅ Qualified:** Stable-Asset Hooks Track
- Dynamic fee adjustment based on risk ratings
- Reward mechanism for quality stablecoins
- Non-punitive model (no circuit breakers)
- Production deployment on testnet

### Chainlink
**✅ Qualified:** S&P Global SSA Integration
- DataLink interface implementation
- Pull-based verification architecture
- On-chain signature validation
- Automated rating refresh workflow designed

### The Graph Amp
**✅ Qualified:** Best Use of Amp Datasets
- SQL-queryable event indexing
- Risk analytics dashboard
- Historical rating tracking
- Fee distribution analysis

## 💡 Why SAGE?

Traditional DeFi treats all stablecoins equally, but not all stablecoins are created equal:

❌ **Problem:** USDC (rated 1) and risky stablecoin (rated 5) pay same fees
✅ **Solution:** SAGE rewards quality with 30% lower fees

**Benefits:**
- **For Users:** Lower fees when trading premium stablecoins
- **For LPs:** Risk transparency and fair pricing
- **For Protocols:** Prevent contagion without blocking trades
- **For Market:** Incentivize quality and best practices

## 📜 License

MIT License - see [LICENSE](LICENSE)

## 👥 Team

Built for ETHGlobal Buenos Aires 2025

- **Developer:** Daniel E.
- **GitHub:** [@danelerr](https://github.com/danelerr)

## 🙏 Acknowledgments

- Uniswap Foundation for v4 architecture
- Chainlink Labs for DataLink integration support
- S&P Global for SSA rating framework
- The Graph for Amp indexing tools
- ETHGlobal for the amazing hackathon
pnpm refresh:usdc
```

### DataLink Credentials

Get your DataLink API credentials:
1. Visit [data.chain.link](https://data.chain.link)
2. Sign up / log in
3. Navigate to your dashboard
4. Copy your `username` and `secret`
5. Add to `.env`:
```bash
DATALINK_USER=your_username
DATALINK_SECRET=your_secret
```

### Usage

**Option 1: Chainlink Runtime Environment (CRE) - Recommended**

SAGE Protocol includes a CRE workflow for automated, decentralized rating updates:

```bash
cd cre

# Setup secrets
cre secrets set DATALINK_USER "your-username"
cre secrets set DATALINK_SECRET "your-secret"
cre secrets set PRIVATE_KEY "0x..."

# Configure cre.toml with contract addresses and feed IDs

# Test locally
npm run dev

# Deploy to production DON
npm run deploy
```

**Benefits:**
- Automated execution every 10 minutes via cron trigger
- Byzantine Fault Tolerant consensus across DON nodes
- No single point of failure
- Monitoring via CRE UI at [cre.chain.link](https://cre.chain.link)

See [`cre/README.md`](cre/README.md) for complete setup instructions.

**Option 2: Manual Scripts (Local/Testing)**

For local development and testing:

```bash
pnpm install

# Configure environment
cp .env.example .env
# Edit .env with your DataLink credentials

# Manual refresh
pnpm refresh:usdc  # Refresh USDC rating
pnpm refresh:usdt  # Refresh USDT rating
pnpm refresh:all   # Refresh all tokens
```

For detailed script setup, see [`scripts/README.md`](scripts/README.md).

**Dynamic Risk-Adjusted Fees:**

SAGE Protocol implements dynamic LP fees that **reward high-quality stablecoins** with discounts, while maintaining standard pricing for normal stablecoins. This incentivizes liquidity provision for safe assets without punitive measures for standard ones.

**Fee Structure (Reward-Based Model):**

| Credit Rating | Risk Level | LP Fee | Basis Points | Discount | Description |
|--------------|------------|--------|--------------|----------|-------------|
| 1-2 | NORMAL | 70 | 0.007% (0.7 bps) | **30% OFF** 🎁 | Premium stablecoins rewarded |
| 3-5 | ELEVATED_RISK | 100 | 0.01% (1 bps) | Standard | Normal pricing, no penalties |

**Philosophy:**
- ✅ **Reward quality** - Premium tokens get 30% fee discount
- ✅ **No punishment** - All ratings allow swaps with fair pricing
- ✅ **Simplicity** - Only 2 fee tiers, easy to understand
- ✅ **Predictability** - No surprises, no circuit breakers

**How It Works:**

1. **Before every swap**, the hook queries both token ratings from the oracle
2. The **effective rating** is calculated as `max(rating0, rating1)` (worst-case)
3. The hook maps the effective rating to the appropriate fee:
   - Ratings 1-2 → 70 bps (30% discount)
   - Ratings 3-5 → 100 bps (standard)
4. The fee is returned with `LPFeeLibrary.OVERRIDE_FEE_FLAG` to apply for that specific swap
5. A `FeeOverrideApplied` event is emitted for analytics and indexing

**Benefits:**

- **Incentivizes Quality**: LPs earn more competitive fees with premium stablecoins
- **Market Signals**: Fee differences provide transparent risk signals
- **Capital Efficiency**: Discounts maximize trading volume on safe pairs
- **No Disruption**: Trading always available, no sudden blocks

## Risk Rating Scale

S&P Global SSA ratings map to SARM risk modes:

| Rating | S&P Assessment | SARM Mode | Fee | Action |
|--------|---------------|-----------|-----|--------|
| **1** | Excellent stability | NORMAL | 0.007% (30% discount) | ✅ Reward |
| **2** | Good stability | NORMAL | 0.007% (30% discount) | ✅ Reward |
| **3** | Moderate stability | ELEVATED_RISK | 0.01% (standard) | ✅ Standard |
| **4** | Higher risk | ELEVATED_RISK | 0.01% (standard) | ✅ Standard |
| **5** | High risk | ELEVATED_RISK | 0.01% (standard) | ✅ Standard |

**Risk Modes:**

- **NORMAL**: Ratings 1-2, premium tokens with 30% fee discount
- **ELEVATED_RISK**: Ratings 3-5, standard tokens with normal pricing
- ~~**FROZEN**~~: Removed - no circuit breakers or swap blocking

## Key Features

### [REWARDS] Discount for Quality
Automatically rewards high-quality stablecoins (ratings 1-2) with 30% fee discount, incentivizing liquidity for safe assets.

### [FEES] Two-Tier Pricing
Simple fee structure: discount (70 bps) for premium, standard (100 bps) for normal. No punitive measures.

### [ANALYTICS] Full Transparency
All risk assessments and fee changes emit events for on-chain analytics and The Graph indexing.

### [INTEGRATION] Institutional Data
Integrates **S&P Global SSA ratings** via **Chainlink DataLink** with on-chain cryptographic verification, bringing institutional-grade risk assessment to DeFi.

## Chainlink Bounty Highlights

SAGE Protocol demonstrates advanced Chainlink integration:

[x] **DataLink Pull-Based Architecture**: Fetches signed reports off-chain, verifies on-chain  
[x] **On-Chain Verification**: Uses DataLink verifier proxy for DON signature validation  
[x] **Smart Contract State Changes**: Ratings directly control Uniswap v4 Hook behavior  
[x] **S&P Global SSA Feeds**: Real institutional-grade credit ratings for stablecoins  
[x] **Chainlink Runtime Environment (CRE)**: Decentralized automated execution  
  - Cron-triggered workflows (every 10 minutes)
  - Byzantine Fault Tolerant consensus across DON nodes
  - HTTP capability for DataLink API integration
  - EVM write capability for on-chain oracle updates
  - Eliminates single points of failure
[x] **Production-Ready**: Complete CRE workflow + manual scripts + staleness checks + error handling  
[x] **Fully Tested**: 26 comprehensive tests including DataLink integration + beforeInitialize validation  

**Key Innovation**: Hook logic (fees + circuit breaker) is **entirely driven by Chainlink-fed SSA ratings**. No external dependencies. True decentralized risk management with automated updates via CRE.

## License

MIT

## Contact

For ETHGlobal Buenos Aires 2025 judging and questions:
- [Add your contact info]
