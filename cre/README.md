# SARM Protocol - Chainlink Runtime Environment (CRE) Integration

This directory contains the Chainlink Runtime Environment workflow for automated SSA rating updates.

## Overview

The CRE workflow (`ssa-refresh.ts`) automatically:
1. **Triggers** every 10 minutes via cron
2. **Fetches** signed SSA rating reports from Chainlink DataLink for USDC, USDT, and DAI
3. **Submits** reports to the `SSAOracleAdapter` contract on Base Sepolia
4. **Updates** on-chain ratings that power the SARM Hook's dynamic fees and circuit breaker

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Chainlink Runtime Environment             │
│                                                               │
│  ┌──────────────┐                                            │
│  │ Cron Trigger │ Every 10 minutes                           │
│  └──────┬───────┘                                            │
│         │                                                     │
│         ▼                                                     │
│  ┌─────────────────────────────────────────┐                │
│  │ Step 1: HTTP Capability                 │                │
│  │ POST /api/v1/reports/bulk               │                │
│  │ • Fetch USDC, USDT, DAI reports         │                │
│  │ • Basic Auth with DataLink credentials  │                │
│  └─────────────┬───────────────────────────┘                │
│                │                                              │
│                ▼                                              │
│  ┌─────────────────────────────────────────┐                │
│  │ Steps 2-4: EVM Write Capability         │                │
│  │ refreshRatingWithReport(token, report)  │                │
│  │ • USDC rating update                    │                │
│  │ • USDT rating update                    │                │
│  │ • DAI rating update                     │                │
│  └─────────────┬───────────────────────────┘                │
└────────────────┼─────────────────────────────────────────────┘
                 │
                 ▼
        ┌────────────────────┐
        │  Base Sepolia       │
        │  SSAOracleAdapter   │
        │  • Verifies report  │
        │  • Updates rating   │
        │  • Emits event      │
        └─────────┬──────────┘
                  │
                  ▼
        ┌────────────────────┐
        │  SARMHook           │
        │  • Reads rating     │
        │  • Applies fees     │
        │  • Circuit breaker  │
        └────────────────────┘
```

## Current Status (ETHGlobal Buenos Aires 2025)

⚠️ **Important Note for Judges**: This CRE integration demonstrates the architecture and workflow logic for automated SSA rating updates. Full deployment to Chainlink DON requires **Early Access** approval, which is pending.

**What's Implemented:**
- ✅ Complete workflow logic (`workflows/ssa-refresh.ts`)
- ✅ Configuration structure (`cre.toml`)
- ✅ Integration design with SSAOracleAdapter contract
- ✅ DataLink API flow architecture
- ✅ TypeScript compilation and validation

**Production Alternative:**
- The manual scripts (`scripts/refresh-rating.ts`) provide identical functionality
- Can be automated via cron jobs or Chainlink Automation
- CRE provides superior architecture with BFT consensus and decentralization

## Prerequisites

1. **CRE CLI**: Compiled from Chainlink source (binary in `$PATH`)
2. **DataLink Credentials**: Get API credentials from Chainlink DataLink
3. **Deployed Contracts**: Deploy `SSAOracleAdapter` and `SARMHook` to Base Sepolia
4. **Early Access** (for production deployment): Apply at [cre.chain.link](https://cre.chain.link)

## Setup

### 1. Install Dependencies

```bash
cd cre
npm install
```

### 2. Configure Secrets

Set your DataLink credentials as CRE secrets (never commit these):

```bash
cre secrets set DATALINK_USER "your-datalink-username"
cre secrets set DATALINK_SECRET "your-datalink-password"
cre secrets set PRIVATE_KEY "0x..." # Wallet private key for signing transactions
```

### 3. Configure Environment Variables

Edit `cre.toml` and set:

```toml
[env]
SSA_ORACLE_ADDRESS = "0x..." # Your deployed SSAOracleAdapter address
USDC_ADDRESS = "0x..."       # USDC on Base Sepolia
USDT_ADDRESS = "0x..."       # USDT on Base Sepolia
DAI_ADDRESS = "0x..."        # DAI on Base Sepolia
FEED_ID_USDC = "0x..."       # DataLink feed ID for USDC SSA
FEED_ID_USDT = "0x..."       # DataLink feed ID for USDT SSA
FEED_ID_DAI = "0x..."        # DataLink feed ID for DAI SSA
```

### 4. Get DataLink Feed IDs

1. Go to Chainlink DataLink dashboard
2. Find SSA rating feeds for USDC, USDT, DAI
3. Copy the feed IDs (they look like `0x...`)
4. Add them to `cre.toml`

## Usage

### Simulate Locally

⚠️ **Note**: Full simulation requires CRE Early Access. The workflow demonstrates the intended logic and architecture.

Test the workflow compilation:

```bash
npm run build
# or
npx tsc --noEmit
```

View the workflow logic:

```bash
cat workflows/ssa-refresh.ts
```

The workflow demonstrates:
- HTTP fetch from DataLink bulk API
- Parsing signed SSA rating reports
- EVM transaction construction for `refreshRatingWithReport()`
- Parallel updates for USDC, USDT, DAI
- Error handling and logging strategy

**For actual rating updates during the hackathon**, use the manual scripts:

```bash
cd ..  # back to project root
pnpm refresh:usdc
pnpm refresh:usdt
pnpm refresh:dai
```

### Deploy to Production

⚠️ **Requires Early Access**: Deployment to Chainlink DON requires approval.

Once approved:

```bash
npm run deploy
# or
cre deploy workflows/ssa-refresh.ts
```

After deployment, the workflow will:
- Run automatically every 10 minutes
- Execute across multiple DON nodes
- Use BFT consensus for all operations
- Be monitored via CRE UI at [cre.chain.link](https://cre.chain.link)

**For ETHGlobal Demo**: Use manual scripts as demonstrated in the project README.

### Manage Workflow

```bash
# Check workflow status
cre status sarm-ssa-refresh

# View logs
cre logs sarm-ssa-refresh

# Pause workflow
cre pause sarm-ssa-refresh

# Resume workflow
cre activate sarm-ssa-refresh

# Update workflow
npm run deploy

# Delete workflow
cre delete sarm-ssa-refresh
```

## Workflow Details

### Trigger

- **Type**: Cron
- **Schedule**: `0 */10 * * * *` (every 10 minutes)
- **Configurable**: Edit `CRON_SCHEDULE` in `cre.toml`

### Step 1: Fetch DataLink Reports

- **Capability**: HTTP POST
- **Endpoint**: `https://api.datalink.chainlink.com/api/v1/reports/bulk`
- **Auth**: Basic Auth with `DATALINK_USER` and `DATALINK_SECRET`
- **Request**: Array of feed IDs for USDC, USDT, DAI
- **Response**: Array of signed reports with `fullReport` field

### Steps 2-4: Update On-Chain Ratings

- **Capability**: EVM Write
- **Network**: Base Sepolia (chain ID: 84532)
- **Contract**: `SSAOracleAdapter`
- **Function**: `refreshRatingWithReport(address token, bytes report)`
- **Execution**: Parallel for all three tokens
- **Consensus**: BFT consensus across DON nodes

### Error Handling

- If a token's report is missing, it's skipped (others continue)
- Failed transactions are logged but don't stop the workflow
- Each execution is independent (no state between runs)

## Security

### Secrets Management

- **Never commit secrets** to the repository
- Use `cre secrets set` to store credentials
- Secrets are encrypted and managed by CRE

### Consensus

- Every operation (HTTP call, EVM write) runs on multiple nodes
- Results are verified via Byzantine Fault Tolerant consensus
- Single points of failure are eliminated

### Report Verification

- DataLink reports are cryptographically signed
- `SSAOracleAdapter` verifies signatures on-chain via DataLink verifier
- Invalid reports are rejected

## Monitoring

### CRE UI

Access your workflow dashboard at [cre.chain.link](https://cre.chain.link):
- View execution history
- Check logs and events
- Monitor performance metrics
- Get alerts for failures

### On-Chain Events

Monitor `RatingUpdated` events from `SSAOracleAdapter`:

```solidity
event RatingUpdated(
    address indexed token,
    uint8 oldRating,
    uint8 newRating
);
```

## Troubleshooting

### Workflow won't compile

```bash
# Check TypeScript errors
npx tsc --noEmit

# Verify CRE SDK version
npm list @chainlink/cre-sdk
```

### Simulation fails

```bash
# Check secrets are set
cre secrets list

# Verify contract addresses in cre.toml
# Test DataLink API manually with curl
```

### Deployment fails

- Ensure you have CRE Early Access
- Check network connectivity
- Verify all secrets are configured
- Review logs: `cre logs sarm-ssa-refresh`

## Integration with SARM Protocol

### SSAOracleAdapter

The workflow calls this contract's function:

```solidity
function refreshRatingWithReport(
    address token,
    bytes calldata report
) external;
```

This function:
1. Verifies the DataLink report signature
2. Decodes the SSA rating from the report
3. Updates the rating in storage
4. Emits `RatingUpdated` event

### SARMHook

The hook reads ratings from `SSAOracleAdapter`:

```solidity
function getRating(address token) external view returns (uint8 rating, uint256 lastUpdated);
```

And applies:
- **Dynamic fees**: 0.005% - 0.04% based on rating
- **Circuit breaker**: Blocks swaps when rating ≥ 5

## Development

### Project Structure

```
cre/
├── cre.toml                    # Workflow configuration
├── package.json                # Node.js dependencies
├── tsconfig.json              # TypeScript config
├── README.md                   # This file
└── workflows/
    └── ssa-refresh.ts         # Main workflow implementation
```

### Adding New Tokens

1. Add token address to `cre.toml`:
   ```toml
   NEW_TOKEN_ADDRESS = "0x..."
   FEED_ID_NEW_TOKEN = "0x..."
   ```

2. Update workflow to include new token:
   ```typescript
   await Promise.all([
     updateToken('USDC', config.USDC_ADDRESS, config.FEED_ID_USDC),
     updateToken('USDT', config.USDT_ADDRESS, config.FEED_ID_USDT),
     updateToken('DAI', config.DAI_ADDRESS, config.FEED_ID_DAI),
     updateToken('NEW_TOKEN', config.NEW_TOKEN_ADDRESS, config.FEED_ID_NEW_TOKEN), // Add this
   ]);
   ```

3. Redeploy: `npm run deploy`

### Changing Schedule

Edit `CRON_SCHEDULE` in `cre.toml`:

```toml
# Every 5 minutes
CRON_SCHEDULE = "0 */5 * * * *"

# Every hour at minute 0
CRON_SCHEDULE = "0 0 * * * *"

# Daily at midnight UTC
CRON_SCHEDULE = "0 0 0 * * *"
```

## Resources

- [CRE Documentation](https://docs.chain.link/cre)
- [CRE SDK Reference](https://docs.chain.link/cre/reference/sdk)
- [DataLink Documentation](https://docs.chain.link/datalink)
- [SARM Protocol Repository](https://github.com/danelerr/sarm-protocol)

## Support

- **CRE Issues**: [Discord](https://discord.gg/aSK4zew)
- **SARM Protocol**: Create issue in this repository
- **DataLink**: Contact Chainlink support

## License

MIT - Part of SARM Protocol for ETHGlobal Buenos Aires 2025
