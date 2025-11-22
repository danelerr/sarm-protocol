#!/usr/bin/env tsx

/**
 * @title Refresh Rating Script
 * @notice Fetches SSA rating from Chainlink DataLink and submits to on-chain oracle.
 * @dev Usage: pnpm refresh:usdc
 * 
 * Flow:
 * 1. Fetch signed report from DataLink pull endpoint (HTTP + auth)
 * 2. Extract report payload
 * 3. Submit via refreshRatingWithReport() to SSAOracleAdapter
 * 4. DataLink verifier validates signature on-chain
 * 5. Oracle updates rating in storage
 */

import { createWalletClient, createPublicClient, http, decodeEventLog, type Address, type Hex } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { baseSepolia } from 'viem/chains';
import * as dotenv from 'dotenv';

dotenv.config();

// Token symbol types
const TOKEN_SYMBOLS = ['USDC', 'USDT', 'DAI'] as const;
type TokenSymbol = (typeof TOKEN_SYMBOLS)[number];

// Configuration
const config = {
  rpcUrl: process.env.RPC_URL || 'https://sepolia.base.org',
  privateKey: process.env.PRIVATE_KEY as Hex,
  oracleAddress: process.env.SSA_ORACLE_ADDRESS as Address,
  datalinkUser: process.env.DATALINK_USER || '',
  datalinkSecret: process.env.DATALINK_SECRET || '',
  datalinkApiUrl: process.env.DATALINK_API_URL || 'https://api.datalink.chainlink.com/api/v1/reports/bulk',
  tokens: {
    USDC: {
      address: process.env.USDC_ADDRESS as Address,
      feedId: process.env.FEED_ID_USDC as Hex,
    },
    USDT: {
      address: process.env.USDT_ADDRESS as Address,
      feedId: process.env.FEED_ID_USDT as Hex,
    },
    DAI: {
      address: process.env.DAI_ADDRESS as Address,
      feedId: process.env.FEED_ID_DAI as Hex,
    },
  },
};

// Validate configuration
if (!config.privateKey) {
  throw new Error('PRIVATE_KEY is required in .env file');
}
if (!config.oracleAddress) {
  throw new Error('SSA_ORACLE_ADDRESS is required in .env file');
}
if (!config.datalinkUser || !config.datalinkSecret) {
  throw new Error('DATALINK_USER and DATALINK_SECRET are required in .env file');
}

// Validate token configurations
for (const [symbol, tokenConfig] of Object.entries(config.tokens)) {
  if (!tokenConfig.address) {
    throw new Error(`${symbol}_ADDRESS is required in .env file`);
  }
  if (!tokenConfig.feedId || tokenConfig.feedId === '0x0000000000000000000000000000000000000000000000000000000000000000') {
    throw new Error(`FEED_ID_${symbol} is required in .env file`);
  }
}

// SSAOracleAdapter ABI (minimal - only what we need)
const oracleAbi = [
  {
    type: 'function',
    name: 'refreshRatingWithReport',
    inputs: [
      { name: 'token', type: 'address' },
      { name: 'report', type: 'bytes' },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'event',
    name: 'RatingUpdated',
    inputs: [
      { name: 'token', type: 'address', indexed: true },
      { name: 'oldRating', type: 'uint8', indexed: false },
      { name: 'newRating', type: 'uint8', indexed: false },
    ],
  },
] as const;

/**
 * Fetch signed report from Chainlink DataLink
 */
async function fetchDatalinkReport(feedId: Hex): Promise<Hex> {
  console.log(`[FETCH] Fetching report from DataLink for feed: ${feedId}`);

  const auth = Buffer.from(`${config.datalinkUser}:${config.datalinkSecret}`).toString('base64');

  // DataLink pull-based delivery uses POST with feedIds array in body
  const response = await fetch(config.datalinkApiUrl, {
    method: 'POST',
    headers: {
      Authorization: `Basic ${auth}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      feedIds: [feedId],
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`DataLink API error: ${response.status} ${response.statusText}\n${errorText}`);
  }

  const data = await response.json() as any;

  // DataLink response structure for bulk endpoint:
  // {
  //   reports: [{
  //     feedId: "0x...",
  //     validFromTimestamp: 123456789,
  //     observationsTimestamp: 123456789,
  //     fullReport: "0x..." // <-- This is what we need
  //   }]
  // }
  
  if (!data.reports || !Array.isArray(data.reports) || data.reports.length === 0) {
    throw new Error('No reports in DataLink response');
  }

  const reportData = data.reports[0];
  const fullReport = reportData.fullReport as Hex;

  if (!fullReport) {
    throw new Error('No fullReport in DataLink response');
  }

  console.log(`[OK] Report fetched successfully`);
  console.log(`   Valid from: ${new Date(reportData.validFromTimestamp * 1000).toISOString()}`);
  console.log(`   Observations: ${new Date(reportData.observationsTimestamp * 1000).toISOString()}`);
  
  return fullReport;
}

/**
 * Submit report to on-chain oracle
 */
async function refreshRating(tokenSymbol: TokenSymbol) {
  console.log(`\n[REFRESH] Refreshing ${tokenSymbol} rating via DataLink\n`);

  const tokenConfig = config.tokens[tokenSymbol];
  
  if (!tokenConfig.feedId || tokenConfig.feedId === '0x0000000000000000000000000000000000000000000000000000000000000000') {
    throw new Error(`Feed ID not configured for ${tokenSymbol}`);
  }

  // 1. Fetch report from DataLink
  const report = await fetchDatalinkReport(tokenConfig.feedId);

  // 2. Setup wallet client
  const account = privateKeyToAccount(config.privateKey);
  const walletClient = createWalletClient({
    account,
    chain: baseSepolia,
    transport: http(config.rpcUrl),
  });

  const publicClient = createPublicClient({
    chain: baseSepolia,
    transport: http(config.rpcUrl),
  });

  console.log(`[SUBMIT] Submitting report to oracle at ${config.oracleAddress}`);
  console.log(`   Token: ${tokenConfig.address}`);
  console.log(`   From: ${account.address}`);

  // 3. Submit transaction
  const hash = await walletClient.writeContract({
    address: config.oracleAddress,
    abi: oracleAbi,
    functionName: 'refreshRatingWithReport',
    args: [tokenConfig.address, report],
  });

  console.log(`[WAIT] Transaction submitted: ${hash}`);
  console.log(`   Waiting for confirmation...`);

  // 4. Wait for confirmation
  const receipt = await publicClient.waitForTransactionReceipt({ hash });

  if (receipt.status === 'success') {
    console.log(`[OK] Rating updated successfully!`);
    console.log(`   Block: ${receipt.blockNumber}`);
    console.log(`   Gas used: ${receipt.gasUsed}`);

    // Parse logs to see the new rating
    const logs = receipt.logs;
    for (const log of logs) {
      // Filter by oracle address to avoid decoding unrelated events
      if (log.address.toLowerCase() !== config.oracleAddress.toLowerCase()) continue;

      try {
        const decoded = decodeEventLog({
          abi: oracleAbi,
          data: log.data,
          topics: log.topics,
        });

        if (decoded.eventName === 'RatingUpdated') {
          console.log(`\n[UPDATE] Rating Update:`);
          console.log(`   Old Rating: ${decoded.args.oldRating}`);
          console.log(`   New Rating: ${decoded.args.newRating}`);
        }
      } catch {
        // Not our event, skip
      }
    }
  } else {
    console.log(`[ERROR] Transaction failed`);
  }
}

// Main execution
const tokenSymbol = process.argv[2]?.toUpperCase() as TokenSymbol;

if (!tokenSymbol || !TOKEN_SYMBOLS.includes(tokenSymbol)) {
  console.error('Usage: pnpm refresh:usdc | pnpm refresh:usdt | pnpm refresh:dai');
  process.exit(1);
}

refreshRating(tokenSymbol)
  .then(() => {
    console.log('\n[DONE] Done!');
    process.exit(0);
  })
  .catch((error: any) => {
    console.error('\n[ERROR] Error:', error?.message ?? error);
    process.exit(1);
  });
