/**
 * @title SARM Protocol SSA Rating Refresh Workflow
 * @notice Chainlink Runtime Environment workflow for automated SSA rating updates
 * @dev This workflow:
 *      1. Triggers every 10 minutes via cron
 *      2. Fetches signed SSA rating reports from Chainlink DataLink
 *      3. Submits reports to SSAOracleAdapter on-chain via refreshRatingWithReport()
 * 
 * Architecture:
 * - Trigger: Cron (every 10 minutes)
 * - Step 1: HTTP POST to DataLink bulk reports API with Basic Auth
 * - Step 2-4: EVM write transactions for USDC, USDT, DAI ratings
 * 
 * Security:
 * - DataLink credentials stored as CRE secrets
 * - Each operation runs across multiple DON nodes with BFT consensus
 * - DataLink reports are cryptographically signed and verified on-chain
 * 
 * Part of SARM Protocol for ETHGlobal Buenos Aires 2025
 */

import * as cre from '@chainlink/cre-sdk';

/**
 * Configuration interface matching cre.toml env vars
 */
interface Config {
  // DataLink API
  DATALINK_API_URL: string;
  DATALINK_USER: string;
  DATALINK_SECRET: string;

  // Contract addresses
  SSA_ORACLE_ADDRESS: string;
  USDC_ADDRESS: string;
  USDT_ADDRESS: string;
  DAI_ADDRESS: string;

  // DataLink feed IDs
  FEED_ID_USDC: string;
  FEED_ID_USDT: string;
  FEED_ID_DAI: string;

  // Cron schedule
  CRON_SCHEDULE: string;
}

/**
 * DataLink API response structure
 */
interface DataLinkReport {
  feedId: string;
  validFromTimestamp: number;
  observationsTimestamp: number;
  fullReport: string; // Hex-encoded signed report
}

interface DataLinkBulkResponse {
  reports: DataLinkReport[];
}

/**
 * SSAOracleAdapter ABI - only the function we need
 */
const SSA_ORACLE_ABI = [
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
] as const;

/**
 * Main workflow callback - triggered by cron
 * 
 * Flow:
 * 1. Fetch all SSA reports from DataLink in one bulk request
 * 2. For each stablecoin (USDC, USDT, DAI):
 *    - Find its report by feedId
 *    - Submit to oracle contract via EVM write
 * 
 * @param config - Environment variables from cre.toml
 * @param runtime - CRE runtime for invoking capabilities
 * @param trigger - Cron trigger payload (timestamp, etc.)
 */
async function onCronTrigger(
  config: Config,
  runtime: cre.Runtime,
  trigger: cre.CronPayload
): Promise<{ success: boolean; message: string }> {
  console.log(`[SARM] Workflow triggered at ${new Date(trigger.timestamp).toISOString()}`);

  try {
    // Step 1: Fetch all SSA reports from DataLink
    console.log('[STEP 1] Fetching SSA reports from DataLink...');

    const auth = Buffer.from(`${config.DATALINK_USER}:${config.DATALINK_SECRET}`).toString('base64');

    const httpClient = runtime.http();
    const reportsResponse = await httpClient.post<DataLinkBulkResponse>({
      url: config.DATALINK_API_URL,
      headers: {
        'Authorization': `Basic ${auth}`,
        'Content-Type': 'application/json',
      },
      body: {
        feedIds: [
          config.FEED_ID_USDC,
          config.FEED_ID_USDT,
          config.FEED_ID_DAI,
        ],
      },
    });

    const reports = reportsResponse.data.reports;
    console.log(`[STEP 1] ✓ Fetched ${reports.length} reports from DataLink`);

    // Step 2-4: Update each token's rating on-chain
    const evmClient = runtime.evm();

    // Helper function to update one token
    async function updateToken(
      tokenName: string,
      tokenAddress: string,
      feedId: string
    ): Promise<void> {
      console.log(`[${tokenName}] Finding report for feedId: ${feedId}`);

      const report = reports.find(
        (r) => r.feedId.toLowerCase() === feedId.toLowerCase()
      );

      if (!report || !report.fullReport) {
        console.warn(`[${tokenName}] ⚠ No report found, skipping`);
        return;
      }

      console.log(`[${tokenName}] Report found, submitting to oracle...`);
      console.log(`[${tokenName}]   validFrom: ${new Date(report.validFromTimestamp * 1000).toISOString()}`);
      console.log(`[${tokenName}]   observations: ${new Date(report.observationsTimestamp * 1000).toISOString()}`);

      // Submit to oracle contract
      const txHash = await evmClient.write({
        chain: 'base-sepolia',
        to: config.SSA_ORACLE_ADDRESS,
        abi: SSA_ORACLE_ABI,
        functionName: 'refreshRatingWithReport',
        args: [tokenAddress, report.fullReport as `0x${string}`],
      });

      console.log(`[${tokenName}] ✓ Rating updated! Tx: ${txHash}`);
    }

    // Execute updates in parallel for all three tokens
    await Promise.all([
      updateToken('USDC', config.USDC_ADDRESS, config.FEED_ID_USDC),
      updateToken('USDT', config.USDT_ADDRESS, config.FEED_ID_USDT),
      updateToken('DAI', config.DAI_ADDRESS, config.FEED_ID_DAI),
    ]);

    console.log('[SARM] ✓ Workflow completed successfully');
    return {
      success: true,
      message: 'All SSA ratings updated successfully',
    };

  } catch (error) {
    console.error('[SARM] ✗ Workflow failed:', error);
    return {
      success: false,
      message: error instanceof Error ? error.message : 'Unknown error',
    };
  }
}

/**
 * Workflow entry point
 * Connects the cron trigger to the callback function
 */
export default cre.defineWorkflow('sarm-ssa-refresh', (config: Config) => {
  // Create cron trigger from config
  const cronTrigger = cre.triggers.cron({
    schedule: config.CRON_SCHEDULE || '0 */10 * * * *', // Every 10 minutes by default
  });

  // Register the trigger-callback handler
  cre.handler(cronTrigger, onCronTrigger);

  console.log('[SARM] Workflow registered with cron schedule:', config.CRON_SCHEDULE);
});
