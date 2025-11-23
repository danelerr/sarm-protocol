"use client"

import { Card } from "@/components/ui/card"
import { useAccount } from "wagmi"
import { useDynamicFees, useAllTokenRatings } from "@/hooks/use-sage"
import { TOKENS } from "@/lib/contracts"

export function DebugPanel() {
  const { address, isConnected, chain } = useAccount()
  const ratings = useAllTokenRatings()
  
  const usdcUsdtFees = useDynamicFees(
    TOKENS.USDC as `0x${string}`,
    TOKENS.USDT as `0x${string}`
  )
  
  const usdcDaiFees = useDynamicFees(
    TOKENS.USDC as `0x${string}`,
    TOKENS.DAI as `0x${string}`
  )
  
  const daiUsdtFees = useDynamicFees(
    TOKENS.DAI as `0x${string}`,
    TOKENS.USDT as `0x${string}`
  )

  return (
    <Card className="sage-glass p-6 mt-8" suppressHydrationWarning>
      <h3 className="text-lg font-bold mb-4 text-foreground">🔧 Debug Panel</h3>
      
      <div className="space-y-4 text-sm font-mono" suppressHydrationWarning>
        <div suppressHydrationWarning>
          <strong>Wallet:</strong> {isConnected ? "✅ Connected" : "❌ Not Connected"}
        </div>
        
        {isConnected && (
          <>
            <div>
              <strong>Address:</strong> {address?.slice(0, 6)}...{address?.slice(-4)}
            </div>
            <div>
              <strong>Chain:</strong> {chain?.name} (ID: {chain?.id})
            </div>
          </>
        )}
        
        <div className="border-t border-border pt-4">
          <strong>Token Ratings (from Oracle):</strong>
          <div className="ml-4 mt-2 space-y-1">
            <div>USDC: Rating {ratings.USDC.rating} {ratings.USDC.isLoading && "(loading...)"}</div>
            <div>USDT: Rating {ratings.USDT.rating} {ratings.USDT.isLoading && "(loading...)"}</div>
            <div>DAI: Rating {ratings.DAI.rating} {ratings.DAI.isLoading && "(loading...)"}</div>
          </div>
        </div>
        
        <div className="border-t border-border pt-4">
          <strong>Dynamic Fees:</strong>
          <div className="ml-4 mt-2 space-y-2">
            <div>
              <div className="text-green-400">USDC/USDT Pool:</div>
              <div className="ml-4">
                • SAGE Fee: {usdcUsdtFees.sageFee?.toFixed(2)}%<br/>
                • Standard Uni v3: {usdcUsdtFees.standardFee}%<br/>
                • Fee Premium: {usdcUsdtFees.savingsAmount}<br/>
                • Best Rating: {usdcUsdtFees.bestRating}
              </div>
            </div>
            
            <div>
              <div className="text-yellow-400">USDC/DAI Pool:</div>
              <div className="ml-4">
                • SAGE Fee: {usdcDaiFees.sageFee?.toFixed(2)}%<br/>
                • Standard Uni v3: {usdcDaiFees.standardFee}%<br/>
                • Fee Premium: {usdcDaiFees.savingsAmount}<br/>
                • Best Rating: {usdcDaiFees.bestRating}
              </div>
            </div>
            
            <div>
              <div className="text-yellow-400">DAI/USDT Pool:</div>
              <div className="ml-4">
                • SAGE Fee: {daiUsdtFees.sageFee?.toFixed(2)}%<br/>
                • Standard Uni v3: {daiUsdtFees.standardFee}%<br/>
                • Fee Premium: {daiUsdtFees.savingsAmount}<br/>
                • Best Rating: {daiUsdtFees.bestRating}
              </div>
            </div>
          </div>
        </div>
        
        <div className="border-t border-border pt-4 text-xs text-muted-foreground">
          <strong>Contract Addresses:</strong>
          <div className="ml-4 mt-2 space-y-1">
            <div>Oracle: 0x444a...6866</div>
            <div>Hook: 0x828e...E080</div>
            <div>PoolManager: 0x05E7...3408</div>
          </div>
        </div>
      </div>
    </Card>
  )
}
