import {
  cre,
  Runner,
  getNetwork,
  encodeCallMsg,
  type Runtime,
  type CronPayload,
  bytesToHex,
  LAST_FINALIZED_BLOCK_NUMBER,
} from '@chainlink/cre-sdk'
import { z } from 'zod'
import { encodeFunctionData, type Address, zeroAddress, decodeFunctionResult } from 'viem'

// ABI completo de AggregatorV3Interface de Chainlink
const SSAFeedABI = [
  {
    inputs: [],
    name: 'decimals',
    outputs: [{ internalType: 'uint8', name: '', type: 'uint8' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'description',
    outputs: [{ internalType: 'string', name: '', type: 'string' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'version',
    outputs: [{ internalType: 'uint256', name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [{ internalType: 'uint80', name: '_roundId', type: 'uint80' }],
    name: 'getRoundData',
    outputs: [
      { internalType: 'uint80', name: 'roundId', type: 'uint80' },
      { internalType: 'int256', name: 'answer', type: 'int256' },
      { internalType: 'uint256', name: 'startedAt', type: 'uint256' },
      { internalType: 'uint256', name: 'updatedAt', type: 'uint256' },
      { internalType: 'uint80', name: 'answeredInRound', type: 'uint80' },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'latestRoundData',
    outputs: [
      { internalType: 'uint80', name: 'roundId', type: 'uint80' },
      { internalType: 'int256', name: 'answer', type: 'int256' },
      { internalType: 'uint256', name: 'startedAt', type: 'uint256' },
      { internalType: 'uint256', name: 'updatedAt', type: 'uint256' },
      { internalType: 'uint80', name: 'answeredInRound', type: 'uint80' },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'latestAnswer',
    outputs: [{ internalType: 'int256', name: '', type: 'int256' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'latestRound',
    outputs: [{ internalType: 'uint256', name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [{ internalType: 'uint256', name: 'roundId', type: 'uint256' }],
    name: 'getAnswer',
    outputs: [{ internalType: 'int256', name: '', type: 'int256' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [{ internalType: 'uint256', name: 'roundId', type: 'uint256' }],
    name: 'getTimestamp',
    outputs: [{ internalType: 'uint256', name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
] as const

// Configuration schema for S&P SSA feeds
const configSchema = z.object({
  schedule: z.string(),
  chainSelectorName: z.string(),
  ssaFeeds: z.array(
    z.object({
      name: z.string(),
      feedContract: z.string(),
    })
  ),
})

type Config = z.infer<typeof configSchema>

// Result type
type SSAResult = {
  name: string
  address: string
  rating: number | null
  error?: string
}

// Utility function to safely stringify objects with bigints
const safeJsonStringify = (obj: any): string =>
  JSON.stringify(obj, (_, value) => (typeof value === 'bigint' ? value.toString() : value), 2)

// Read a single S&P SSA feed
function readSSAFeed(
  runtime: Runtime<Config>,
  evmClient: InstanceType<typeof cre.capabilities.EVMClient>,
  name: string,
  address: string,
): SSAResult {
  try {
    runtime.log(`Reading S&P SSA feed: ${name} at ${address}`)

    // Call latestAnswer() - simplest method
    const calldata = encodeFunctionData({
      abi: SSAFeedABI,
      functionName: 'latestAnswer',
    })

    const response = evmClient
      .callContract(runtime, {
        call: encodeCallMsg({
          from: zeroAddress,
          to: address as Address,
          data: calldata,
        }),
        // Don't specify blockNumber - use latest
      })
      .result()

    // Decode result
    const answer = decodeFunctionResult({
      abi: SSAFeedABI,
      functionName: 'latestAnswer',
      data: bytesToHex(response.data),
    }) as bigint

    const rating = Number(answer)
    
    runtime.log(`✓ ${name}: SSA Rating = ${rating}`)

    return {
      name,
      address,
      rating,
    }
  } catch (error) {
    runtime.log(`✗ ${name}: Failed - ${error}`)
    return {
      name,
      address,
      rating: null,
      error: String(error),
    }
  }
}

const onCronTrigger = (runtime: Runtime<Config>, payload: CronPayload): string => {
  if (!payload.scheduledExecutionTime) {
    throw new Error('Scheduled execution time is required')
  }

  runtime.log('=== S&P SSA Rating Refresh Workflow ===')
  runtime.log(`Chain: ${runtime.config.chainSelectorName}`)
  runtime.log(`Feeds to read: ${runtime.config.ssaFeeds.length}`)

  // Get network
  const network = getNetwork({
    chainFamily: 'evm',
    chainSelectorName: runtime.config.chainSelectorName,
    isTestnet: false,
  })

  if (!network) {
    throw new Error(`Network not found: ${runtime.config.chainSelectorName}`)
  }

  const evmClient = new cre.capabilities.EVMClient(network.chainSelector.selector)

  // Read all feeds
  const results: SSAResult[] = runtime.config.ssaFeeds.map((feed) =>
    readSSAFeed(runtime, evmClient, feed.name, feed.feedContract)
  )

  runtime.log('=== Workflow Complete ===')
  
  return safeJsonStringify(results)
}

const initWorkflow = (config: Config) => {
  const cronTrigger = new cre.capabilities.CronCapability()

  return [
    cre.handler(
      cronTrigger.trigger({
        schedule: config.schedule,
      }),
      onCronTrigger,
    ),
  ]
}

export async function main() {
  const runner = await Runner.newRunner<Config>({
    configSchema,
  })
  await runner.run(initWorkflow)
}

main()

main()
