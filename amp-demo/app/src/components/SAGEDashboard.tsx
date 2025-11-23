"use client";

import { useQuery } from "@tanstack/react-query";
import { sql } from "../lib/amp.ts";

interface RiskCheck {
  pool_id: string;
  rating0: number;
  rating1: number;
  effective_rating: number;
  block_num: number;
  timestamp: string;
}

interface RatingUpdate {
  token: string;
  old_rating: number;
  new_rating: number;
  block_num: number;
  timestamp: string;
}

interface FeeOverride {
  pool_id: string;
  effective_rating: number;
  fee: number;
  block_num: number;
  timestamp: string;
}

export function SAGEDashboard() {
  return (
    <div className="min-h-full">
      <div className="border-b border-gray-200 bg-white dark:border-white/10 dark:bg-gray-900">
        <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
          <div className="flex h-16 justify-between items-center">
            <div className="flex shrink-0 items-center font-bold text-xl">
              🛡️ SAGE Protocol Dashboard
            </div>
            <div className="text-sm text-gray-500">Base Sepolia</div>
          </div>
        </div>
      </div>

      <main className="w-full flex flex-col gap-y-6 mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-6">
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <StatsCard />
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <RiskChecksTable />
          <RatingUpdatesTable />
        </div>

        <FeeOverridesTable />
      </main>
    </div>
  );
}

function StatsCard() {
  const { data: stats } = useQuery({
    queryKey: ["SAGE", "Stats"],
    queryFn: async () => {
      const result = await sql<{
        total_risk_checks: number;
        total_swaps: number;
        total_rating_updates: number;
      }>(`
        SELECT 
          (SELECT COUNT(*) FROM "eth_global/sarm@dev".risk_check) as total_risk_checks,
          (SELECT COUNT(*) FROM "eth_global/sarm@dev".fee_override_applied) as total_swaps,
          (SELECT COUNT(*) FROM "eth_global/sarm@dev".rating_updated) as total_rating_updates
      `);
      return result[0];
    },
    refetchInterval: 10000,
  });

  return (
    <>
      <div className="bg-white dark:bg-gray-800 p-6 rounded-lg shadow">
        <div className="text-sm text-gray-500 dark:text-gray-400">Total Risk Checks</div>
        <div className="text-3xl font-bold text-gray-900 dark:text-white mt-2">
          {stats?.total_risk_checks || 0}
        </div>
      </div>

      <div className="bg-white dark:bg-gray-800 p-6 rounded-lg shadow">
        <div className="text-sm text-gray-500 dark:text-gray-400">Total Swaps</div>
        <div className="text-3xl font-bold text-gray-900 dark:text-white mt-2">
          {stats?.total_swaps || 0}
        </div>
      </div>

      <div className="bg-white dark:bg-gray-800 p-6 rounded-lg shadow">
        <div className="text-sm text-gray-500 dark:text-gray-400">Rating Updates</div>
        <div className="text-3xl font-bold text-gray-900 dark:text-white mt-2">
          {stats?.total_rating_updates || 0}
        </div>
      </div>
    </>
  );
}

function RiskChecksTable() {
  const { data: checks, isLoading } = useQuery({
    queryKey: ["SAGE", "RiskChecks"],
    queryFn: async () => {
      const result = await sql<RiskCheck>(`
        SELECT 
          pool_id,
          rating0,
          rating1,
          effective_rating,
          block_num,
          timestamp
        FROM "eth_global/sarm@dev".risk_check
        ORDER BY block_num DESC
        LIMIT 10
      `);
      return result;
    },
    refetchInterval: 10000,
  });

  return (
    <div className="bg-white dark:bg-gray-800 rounded-lg shadow overflow-hidden">
      <div className="px-6 py-4 border-b border-gray-200 dark:border-gray-700">
        <h3 className="text-lg font-semibold text-gray-900 dark:text-white">
          Recent Risk Checks
        </h3>
      </div>
      <div className="overflow-x-auto">
        <table className="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
          <thead className="bg-gray-50 dark:bg-gray-900">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                Pool
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                Ratings
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                Block
              </th>
            </tr>
          </thead>
          <tbody className="bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700">
            {isLoading ? (
              <tr>
                <td colSpan={3} className="px-6 py-4 text-center text-sm text-gray-500">
                  Loading...
                </td>
              </tr>
            ) : checks && checks.length > 0 ? (
              checks.map((check, idx) => (
                <tr key={idx}>
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-mono text-gray-900 dark:text-gray-300">
                    {check.pool_id.substring(0, 10)}...
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500 dark:text-gray-400">
                    {check.rating0}/{check.rating1} → {check.effective_rating}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500 dark:text-gray-400">
                    {check.block_num}
                  </td>
                </tr>
              ))
            ) : (
              <tr>
                <td colSpan={3} className="px-6 py-4 text-center text-sm text-gray-500">
                  No risk checks yet
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}

function RatingUpdatesTable() {
  const { data: updates, isLoading } = useQuery({
    queryKey: ["SAGE", "RatingUpdates"],
    queryFn: async () => {
      const result = await sql<RatingUpdate>(`
        SELECT 
          token,
          old_rating,
          new_rating,
          block_num,
          timestamp
        FROM "eth_global/sarm@dev".rating_updated
        ORDER BY block_num DESC
        LIMIT 10
      `);
      return result;
    },
    refetchInterval: 10000,
  });

  const TOKEN_NAMES: Record<string, string> = {
    "0x036cbd53842c5426634e7929541ec2318f3dcf7e": "USDC",
    "0x7169d38820dfd117c3fa1f22a697dba58d90ba06": "USDT",
    "0x174499ede5e22a4a729e34e99fab4ec0bc7fa45e": "DAI",
  };

  return (
    <div className="bg-white dark:bg-gray-800 rounded-lg shadow overflow-hidden">
      <div className="px-6 py-4 border-b border-gray-200 dark:border-gray-700">
        <h3 className="text-lg font-semibold text-gray-900 dark:text-white">
          Rating Updates
        </h3>
      </div>
      <div className="overflow-x-auto">
        <table className="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
          <thead className="bg-gray-50 dark:bg-gray-900">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                Token
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                Change
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                Block
              </th>
            </tr>
          </thead>
          <tbody className="bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700">
            {isLoading ? (
              <tr>
                <td colSpan={3} className="px-6 py-4 text-center text-sm text-gray-500">
                  Loading...
                </td>
              </tr>
            ) : updates && updates.length > 0 ? (
              updates.map((update, idx) => (
                <tr key={idx}>
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900 dark:text-gray-300">
                    {TOKEN_NAMES[update.token.toLowerCase()] || update.token.substring(0, 8)}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500 dark:text-gray-400">
                    {update.old_rating} → {update.new_rating}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500 dark:text-gray-400">
                    {update.block_num}
                  </td>
                </tr>
              ))
            ) : (
              <tr>
                <td colSpan={3} className="px-6 py-4 text-center text-sm text-gray-500">
                  No rating updates yet
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}

function FeeOverridesTable() {
  const { data: fees, isLoading } = useQuery({
    queryKey: ["SAGE", "FeeOverrides"],
    queryFn: async () => {
      const result = await sql<FeeOverride>(`
        SELECT 
          pool_id,
          effective_rating,
          fee,
          block_num,
          timestamp
        FROM "eth_global/sarm@dev".fee_override_applied
        ORDER BY block_num DESC
        LIMIT 15
      `);
      return result;
    },
    refetchInterval: 10000,
  });

  return (
    <div className="bg-white dark:bg-gray-800 rounded-lg shadow overflow-hidden">
      <div className="px-6 py-4 border-b border-gray-200 dark:border-gray-700">
        <h3 className="text-lg font-semibold text-gray-900 dark:text-white">
          Dynamic Fee Applications
        </h3>
      </div>
      <div className="overflow-x-auto">
        <table className="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
          <thead className="bg-gray-50 dark:bg-gray-900">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                Pool
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                Rating
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                Fee (bps)
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                Block
              </th>
            </tr>
          </thead>
          <tbody className="bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700">
            {isLoading ? (
              <tr>
                <td colSpan={4} className="px-6 py-4 text-center text-sm text-gray-500">
                  Loading...
                </td>
              </tr>
            ) : fees && fees.length > 0 ? (
              fees.map((fee, idx) => (
                <tr key={idx}>
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-mono text-gray-900 dark:text-gray-300">
                    {fee.pool_id.substring(0, 10)}...
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500 dark:text-gray-400">
                    {fee.effective_rating}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500 dark:text-gray-400">
                    {fee.fee} ({(fee.fee / 100).toFixed(2)}%)
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500 dark:text-gray-400">
                    {fee.block_num}
                  </td>
                </tr>
              ))
            ) : (
              <tr>
                <td colSpan={4} className="px-6 py-4 text-center text-sm text-gray-500">
                  No fee overrides yet. Perform a swap to see dynamic fees in action!
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
