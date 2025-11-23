"use client"

import type React from "react"

import { motion } from "framer-motion"
import { Award } from "lucide-react"
import { Card } from "@/components/ui/card"
import { useAllTokenRatings } from "@/hooks/use-sage"

export function AnalyticsDashboard() {
  // Get real ratings from the oracle
  const { USDC, USDT, DAI, isLoading } = useAllTokenRatings()

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.5, delay: 0.2 }}
      className="w-full max-w-md space-y-6"
    >

      {/* Token Ratings */}
      <Card className="sage-glass p-6">
        <h3 className="text-lg font-bold mb-4 text-foreground">Live Token Ratings</h3>
        {isLoading ? (
          <div className="text-sm text-muted-foreground animate-pulse">Loading ratings...</div>
        ) : (
          <div className="space-y-3">
            <TokenRating symbol="USDC" rating={USDC.rating} />
            <TokenRating symbol="USDT" rating={USDT.rating} />
            <TokenRating symbol="DAI" rating={DAI.rating} />
          </div>
        )}
      </Card>
    </motion.div>
  )
}

function TokenRating({ symbol, rating }: { symbol: string; rating: number | undefined }) {
  const getRatingColor = (rating?: number) => {
    if (!rating) return "text-muted-foreground"
    if (rating <= 2) return "text-green-500"
    if (rating <= 3) return "text-yellow-500"
    return "text-red-500"
  }

  const getRatingText = (rating?: number) => {
    if (!rating) return "N/A"
    if (rating <= 2) return "Premium (70bps fee)"
    if (rating <= 3) return "Standard (100bps fee)"
    return "High Risk"
  }

  return (
    <div className="flex items-center justify-between p-3 sage-glass rounded-lg">
      <div className="flex items-center gap-2">
        <Award className={`w-5 h-5 ${getRatingColor(rating)}`} />
        <span className="font-bold">{symbol}</span>
      </div>
      <div className="text-right">
        <div className={`font-bold ${getRatingColor(rating)}`}>
          {rating ? `Rating ${rating}` : "Loading..."}
        </div>
        <div className="text-xs text-muted-foreground">{getRatingText(rating)}</div>
      </div>
    </div>
  )
}
