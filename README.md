# SARM Protocol

**Stablecoin Automated Risk Management Protocol**

A Uniswap v4 Hook that makes stablecoin liquidity "risk-aware" using institutional-grade ratings.

## Overview

SARM Protocol integrates S&P Global Stablecoin Stability Assessment (SSA) ratings into Uniswap v4 pools to:
- Adjust pool fees dynamically based on stablecoin risk
- Enforce risk modes and circuit breakers when ratings degrade
- Provide LPs with protection against depeg events

## Built For

- **ETHGlobal Buenos Aires 2025**
- **Uniswap v4 Stable-Asset Hooks Track**
- **Chainlink Bounty** (S&P Global SSA feeds)
- **The Graph Bounty** (Risk analytics & dashboards)

## Architecture

### Core Contracts

1. **SSAOracleAdapter** (`src/oracles/SSAOracleAdapter.sol`)
   - Single source of truth for stablecoin ratings on-chain
   - Caches S&P Global SSA ratings (currently manual, Chainlink integration coming)
   - Emits `RatingUpdated` events for indexing

2. **SARMHook** (`src/hooks/SARMHook.sol`)
   - Uniswap v4 Hook implementing risk-aware swap logic
   - Reads ratings from SSAOracleAdapter
   - Applies dynamic fees and circuit breakers based on risk
   - Emits `RiskCheck` events for analytics

3. **MockERC20** (`src/mocks/MockERC20.sol`)
   - Test stablecoin tokens for development

## Development Setup

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)

### Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/sarm-protocol.git
cd sarm-protocol

# Install dependencies
forge install OpenZeppelin/openzeppelin-contracts
forge install Uniswap/v4-core
forge install Uniswap/v4-periphery
forge install foundry-rs/forge-std

# Build contracts
forge build

# Run tests
forge test

# Run tests with verbosity
forge test -vvv
```

## Project Structure

```
sarm-protocol/
├── src/
│   ├── hooks/
│   │   └── SARMHook.sol           # Main Uniswap v4 Hook
│   ├── oracles/
│   │   └── SSAOracleAdapter.sol   # Rating oracle adapter
│   └── mocks/
│       └── MockERC20.sol          # Test tokens
├── test/
│   └── SARMHook.t.sol             # Forge tests
├── script/
│   └── Deploy.s.sol               # Deployment scripts
├── lib/                           # Dependencies (gitignored)
├── foundry.toml                   # Foundry configuration
└── README.md
```

## Testing

```bash
# Run all tests
forge test

# Run specific test
forge test --match-test testSwapWithLowRisk

# Run with gas reporting
forge test --gas-report

# Run with coverage
forge coverage
```

## Implementation Status

### ✅ Core Features (Complete)
- [x] SSAOracleAdapter with manual rating setter
- [x] SARMHook with beforeSwap logic
- [x] Circuit breaker for high-risk ratings (FROZEN mode)
- [x] Risk mode transitions (NORMAL → ELEVATED_RISK → FROZEN)
- [x] Dynamic risk-adjusted fees with override mechanism
- [x] Event emission for analytics (RiskCheck, RiskModeChanged, FeeOverrideApplied)
- [x] Comprehensive Forge tests (17/17 passing)

### 🚧 Future Enhancements
- [ ] Chainlink SSA feed integration for automated rating updates
- [ ] The Graph subgraph for event indexing and analytics
- [ ] Risk dashboard UI showing ratings and fee history
- [ ] LP analytics dashboard (fees earned by risk level)

**Dynamic Risk-Adjusted Fees:**

SARM Protocol implements dynamic LP fees that adjust automatically based on the credit risk of the stablecoins in a pool. This ensures LPs are compensated appropriately for the risk they bear, while maintaining competitive fees for high-quality stablecoins.

**Fee Structure:**

| Credit Rating | Risk Level | LP Fee | Basis Points | Use Case |
|--------------|------------|--------|--------------|----------|
| 1-2 | NORMAL | 500 | 0.05% (5 bps) | High-quality stablecoins (USDC, USDT) |
| 3 | ELEVATED_RISK | 1000 | 0.10% (10 bps) | Stablecoins showing stress signals |
| 4-5 | FROZEN | 3000* | 0.30% (30 bps) | Depeg risk/Circuit breaker active |

*Note: Rating 4+ typically triggers the circuit breaker, blocking swaps entirely. The 0.30% fee would only apply if special exceptions are implemented.

**How It Works:**

1. **Before every swap**, the hook queries both token ratings from the oracle
2. The **effective rating** is calculated as `max(rating0, rating1)` (worst-case)
3. The hook maps the effective rating to the appropriate fee using `_feeForRating()`
4. The fee is returned with `LPFeeLibrary.OVERRIDE_FEE_FLAG` to apply for that specific swap
5. A `FeeOverrideApplied` event is emitted for analytics and indexing

**Benefits:**

- **Risk Compensation**: LPs earn higher fees when holding riskier assets
- **Market Signals**: Fee changes provide real-time risk signals to traders
- **Capital Efficiency**: Low fees on safe pairs maximize trading volume
- **Circuit Breaker Integration**: Seamlessly works with risk gating system

## Risk Rating Scale

S&P Global SSA ratings map to SARM risk modes:

| Rating | S&P Assessment | SARM Mode | Action |
|--------|---------------|-----------|--------|
| **1** | Excellent stability | NORMAL | 0.05% fee |
| **2** | Good stability | NORMAL | 0.05% fee |
| **3** | Moderate stability | ELEVATED_RISK | 0.10% fee |
| **4** | High depeg risk | FROZEN | Swaps blocked |
| **5** | Critical/Imminent depeg | FROZEN | Swaps blocked |

**Risk Modes:**

- **NORMAL**: Ratings 1-2, normal operation with competitive fees
- **ELEVATED_RISK**: Rating 3, higher fees to compensate for increased risk
- **FROZEN**: Ratings 4-5, circuit breaker activated, all swaps blocked

## Key Features

### 🛡️ Circuit Breaker Protection
Automatically blocks swaps when stablecoin ratings indicate high depeg risk, protecting LPs from toxic flow.

### 💰 Dynamic Risk-Adjusted Fees
LP fees adjust in real-time based on S&P Global credit ratings, ensuring proper risk compensation.

### 📊 Full Transparency
All risk assessments and fee changes emit events for on-chain analytics and The Graph indexing.

### 🔗 Institutional Data
Integrates S&P Global SSA ratings via Chainlink feeds (planned), bringing institutional-grade risk assessment to DeFi.

## License

MIT

## Contact

For ETHGlobal Buenos Aires 2025 judging and questions:
- [Add your contact info]
