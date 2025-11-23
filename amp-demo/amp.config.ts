import { defineDataset, eventTables } from "@edgeandnode/amp"
// @ts-ignore
import { abi } from "./app/src/lib/abi.ts"

export default defineDataset(() => {
  const baseTables = eventTables(abi, "rpc")

  return {
    namespace: "eth_global",
    name: "sarm",
    description: "SARM Protocol dataset tracking risk-aware stablecoin liquidity on Uniswap v4. Indexes S&P Global SSA ratings, dynamic fees, and circuit breakers.",
    readme: `# SARM Protocol Dataset

Stablecoin Automated Risk Management (SARM) Protocol dataset for Uniswap v4.

## Overview

This dataset indexes events from the SARM Protocol, which makes stablecoin liquidity "risk-aware" by integrating S&P Global Stablecoin Stability Assessment (SSA) ratings into Uniswap v4 pools.

## Tables

### SARMHook Events
- \`risk_check\` - Risk assessments for each swap (poolId, rating0, rating1, effectiveRating)
- \`risk_mode_changed\` - Pool risk mode transitions (NORMAL, ELEVATED_RISK, FROZEN)
- \`fee_override_applied\` - Dynamic LP fee applications based on risk ratings

### SSAOracleAdapter Events
- \`rating_updated\` - Stablecoin SSA rating updates from Chainlink DataLink
- \`feed_id_set\` - Chainlink DataLink feed ID configurations

## Usage Examples

\`\`\`sql
-- Get recent risk checks
SELECT * FROM "eth_global/sarm@dev".risk_check 
ORDER BY block_num DESC LIMIT 10

-- Track rating updates for a specific token
SELECT * FROM "eth_global/sarm@dev".rating_updated 
WHERE token = '0x...' 
ORDER BY block_num DESC

-- Monitor fee overrides by rating
SELECT effective_rating, fee, COUNT(*) as count
FROM "eth_global/sarm@dev".fee_override_applied
GROUP BY effective_rating, fee
ORDER BY effective_rating

-- Find pools that transitioned to FROZEN mode
SELECT * FROM "eth_global/sarm@dev".risk_mode_changed
WHERE new_mode = 2  -- FROZEN = 2
ORDER BY block_num DESC
\`\`\`

## Risk Modes

- **NORMAL (0)**: Ratings 1-2, 0.005% fee
- **ELEVATED_RISK (1)**: Ratings 3-4, 0.01%-0.02% fees
- **FROZEN (2)**: Rating 5, swaps blocked

## Part of

ETHGlobal Buenos Aires 2025 - Uniswap v4 Stable-Asset Hooks Track
`,
    keywords: [
      "SARM",
      "SARM Protocol",
      "Uniswap v4",
      "Stablecoins",
      "Risk Management",
      "SSA Ratings",
      "S&P Global",
      "Chainlink",
      "DataLink",
      "Dynamic Fees",
      "Circuit Breakers",
      "DeFi",
      "ETHGlobal",
    ],
    // Add contract addresses once deployed
    // sources: [
    //   "0x...", // SARMHook address
    //   "0x...", // SSAOracleAdapter address
    // ],
    network: process.env.VITE_AMP_NETWORK || "anvil",
    dependencies: {
      rpc: process.env.VITE_AMP_RPC_DATASET || "_/anvil@0.0.1",
    },
    tables: {
      ...baseTables,
      // Note: Derived tables that reference event tables from this dataset are not supported
      // (self-referencing is not allowed). Use the event tables directly in queries instead.
      // For example, filter high-risk swaps at query time:
      // SELECT * FROM "eth_global/sarm@dev".risk_check WHERE effective_rating >= 4
    },
  }
})
