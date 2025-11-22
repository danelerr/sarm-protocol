#!/usr/bin/env tsx

/**
 * @title Refresh All Ratings Script
 * @notice Refreshes SSA ratings for all configured stablecoins.
 * @dev Usage: pnpm refresh:all
 */

import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

const tokens = ['USDC', 'USDT', 'DAI'];

async function refreshAll() {
  console.log('🔄 Refreshing all stablecoin ratings...\n');

  for (const token of tokens) {
    console.log(`\n${'='.repeat(50)}`);
    console.log(`Refreshing ${token}`);
    console.log('='.repeat(50));

    try {
      const { stdout, stderr } = await execAsync(`pnpm refresh:${token.toLowerCase()}`);
      console.log(stdout);
      if (stderr) console.error(stderr);
    } catch (error: any) {
      console.error(`❌ Failed to refresh ${token}:`, error.message);
    }
  }

  console.log('\n✨ All ratings refreshed!');
}

refreshAll()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('❌ Error:', error.message);
    process.exit(1);
  });
