"use client"

import { useState, useEffect } from "react"
import { motion, AnimatePresence } from "framer-motion"
import { ArrowDownUp, ChevronDown, Info, Zap } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Card } from "@/components/ui/card"
import { cn } from "@/lib/utils"
import { useDynamicFees } from "@/hooks/use-sage"
import { TOKENS as TOKEN_ADDRESSES } from "@/lib/contracts"

const TOKENS = [
  { symbol: "USDC", name: "USD Coin", icon: "💵", isStable: true, address: TOKEN_ADDRESSES.USDC },
  { symbol: "USDT", name: "Tether", icon: "₮", isStable: true, address: TOKEN_ADDRESSES.USDT },
  { symbol: "DAI", name: "Dai", icon: "◈", isStable: true, address: TOKEN_ADDRESSES.DAI },
]

export function SmartSwap() {
  const [fromToken, setFromToken] = useState(TOKENS[0])
  const [toToken, setToToken] = useState<(typeof TOKENS)[0] | null>(null)
  const [fromAmount, setFromAmount] = useState("")
  const [showFromDropdown, setShowFromDropdown] = useState(false)
  const [showToDropdown, setShowToDropdown] = useState(false)

  // Get dynamic fees from the oracle
  const { 
    sageFee, 
    standardFee, 
    savings, 
    savingsAmount,
    isLoading: feesLoading,
    bestRating 
  } = useDynamicFees(
    fromToken?.address as `0x${string}` | undefined,
    toToken?.address as `0x${string}` | undefined
  )

  const isSmartRouting = toToken !== null && sageFee !== null && sageFee < standardFee

  const handleToTokenSelect = (token: (typeof TOKENS)[0]) => {
    setToToken(token)
    setShowToDropdown(false)
  }

  const flipTokens = () => {
    if (toToken) {
      const temp = fromToken
      setFromToken(toToken)
      setToToken(temp)
    }
  }

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.5 }}
      className="w-full max-w-md"
    >
      <Card className={cn("sage-glass p-6 transition-all duration-500", isSmartRouting && "sage-glow-active")}>
        {/* Header */}
        <div className="flex items-center justify-between mb-6">
          <h2 className="text-2xl font-bold text-foreground">Swap</h2>
          <motion.button
            whileHover={{ scale: 1.05 }}
            whileTap={{ scale: 0.95 }}
            className="p-2 rounded-lg bg-secondary/50 hover:bg-secondary"
          >
            <Info className="w-5 h-5 text-muted-foreground" />
          </motion.button>
        </div>

        {/* From Token Input */}
        <div className="space-y-4">
          <div className="relative z-30">
            <div className="sage-glass rounded-xl p-4">
              <div className="flex justify-between mb-2">
                <span className="text-sm text-muted-foreground">You pay</span>
                <span className="text-sm text-muted-foreground">Balance: 0.00</span>
              </div>
              <div className="flex items-center gap-3">
                <input
                  type="text"
                  value={fromAmount}
                  onChange={(e) => setFromAmount(e.target.value)}
                  placeholder="0.0"
                  className="flex-1 bg-transparent text-3xl font-bold outline-none text-foreground"
                />
                <motion.button
                  whileHover={{ scale: 1.02 }}
                  whileTap={{ scale: 0.98 }}
                  onClick={() => setShowFromDropdown(!showFromDropdown)}
                  className="flex items-center gap-2 px-4 py-2 rounded-xl bg-secondary hover:bg-secondary/80 transition-colors shrink-0 min-w-[120px]"
                >
                  <span className="text-2xl">{fromToken.icon}</span>
                  <span className="font-bold text-foreground">{fromToken.symbol}</span>
                  <ChevronDown className="w-4 h-4 text-foreground" />
                </motion.button>
              </div>
            </div>

            <AnimatePresence>
              {showFromDropdown && (
                <TokenDropdown
                  tokens={TOKENS}
                  onSelect={(token) => {
                    setFromToken(token)
                    setShowFromDropdown(false)
                  }}
                  onClose={() => setShowFromDropdown(false)}
                />
              )}
            </AnimatePresence>
          </div>

          {/* Flip Button */}
          <div className="flex justify-center -my-2 relative z-20">
            <motion.button
              whileHover={{ scale: 1.1, rotate: 180 }}
              whileTap={{ scale: 0.9 }}
              onClick={flipTokens}
              className="p-3 rounded-xl sage-glass border-2 border-border hover:border-primary transition-colors"
            >
              <ArrowDownUp className="w-5 h-5 text-foreground" />
            </motion.button>
          </div>

          {/* To Token Input */}
          <div className="relative z-10">
            <div className="sage-glass rounded-xl p-4">
              <div className="flex justify-between mb-2">
                <span className="text-sm text-muted-foreground">You receive</span>
                <span className="text-sm text-muted-foreground">Balance: 0.00</span>
              </div>
              <div className="flex items-center gap-3">
                <input
                  type="text"
                  value={fromAmount && toToken ? (parseFloat(fromAmount) * 0.997).toFixed(6) : "0.0"}
                  placeholder="0.0"
                  disabled
                  className="flex-1 bg-transparent text-3xl font-bold outline-none text-foreground"
                />
                <motion.button
                  whileHover={{ scale: 1.02 }}
                  whileTap={{ scale: 0.98 }}
                  onClick={() => setShowToDropdown(!showToDropdown)}
                  className="flex items-center gap-2 px-4 py-2 rounded-xl bg-secondary hover:bg-secondary/80 transition-colors shrink-0 min-w-[120px] justify-between"
                >
                  {toToken ? (
                    <>
                      <span className="text-2xl">{toToken.icon}</span>
                      <span className="font-bold text-foreground">{toToken.symbol}</span>
                    </>
                  ) : (
                    <span className="font-bold text-foreground">Select</span>
                  )}
                  <ChevronDown className="w-4 h-4 text-foreground" />
                </motion.button>
              </div>
            </div>

            <AnimatePresence>
              {showToDropdown && (
                <TokenDropdown
                  tokens={TOKENS.filter((t) => t.symbol !== fromToken.symbol)}
                  onSelect={handleToTokenSelect}
                  onClose={() => setShowToDropdown(false)}
                />
              )}
            </AnimatePresence>
          </div>
        </div>

        {/* Dynamic Fee Display */}
        <motion.div className="mt-6 sage-glass rounded-xl p-4" layout>
          <div className="flex items-center justify-between mb-3">
            <span className="text-sm font-medium text-muted-foreground">Pool Fee</span>
            {feesLoading ? (
              <div className="text-sm text-muted-foreground animate-pulse">Loading...</div>
            ) : toToken ? (
              <div className="text-right">
                <motion.div
                  key={sageFee}
                  initial={{ scale: 1.2, color: "#ff1f48" }}
                  animate={{
                    scale: 1,
                    color: "#3b82f6",
                  }}
                  transition={{ duration: 0.3 }}
                  className="text-2xl font-bold text-blue-400"
                >
                  {sageFee?.toFixed(2)}%
                </motion.div>
                {bestRating && (
                  <div className="text-xs text-blue-300 mt-1">
                    Risk Rating: {bestRating}/5 ⭐
                  </div>
                )}
              </div>
            ) : (
              <div className="text-sm text-muted-foreground">Select tokens</div>
            )}
          </div>

          <AnimatePresence>
            {isSmartRouting && bestRating && (
              <motion.div
                initial={{ opacity: 0, height: 0 }}
                animate={{ opacity: 1, height: "auto" }}
                exit={{ opacity: 0, height: 0 }}
                className="space-y-2"
              >
                <div className="flex justify-between text-xs text-muted-foreground border-t border-border pt-3">
                  <span>Risk-Based Premium</span>
                  <span className="text-blue-400">{savingsAmount}</span>
                </div>
                
                <div className="p-3 rounded-lg bg-blue-500/10 border border-blue-500/20">
                  <div className="flex items-start gap-2">
                    <Zap className="w-4 h-4 text-blue-400 mt-0.5 shrink-0" />
                    <div className="text-xs text-blue-300">
                      <div className="font-medium mb-1">Dynamic Risk-Based Fee</div>
                      <div className="text-blue-200/70">
                        Better rated tokens pay lower fees. Rating {bestRating} = {sageFee?.toFixed(2)}% fee
                      </div>
                    </div>
                  </div>
                </div>

                <div className="text-xs text-muted-foreground/60 italic pt-1">
                  Note: Standard Uniswap v3 pools charge 0.30%
                </div>
              </motion.div>
            )}
          </AnimatePresence>
        </motion.div>

        {/* Swap Button */}
        <motion.div whileHover={{ scale: 1.02 }} whileTap={{ scale: 0.98 }} className="mt-6">
          <Button
            size="lg"
            className="w-full text-lg font-bold sage-gradient hover:opacity-90 transition-opacity"
            disabled={!toToken || !fromAmount}
          >
            {!toToken ? "Select a token" : !fromAmount ? "Enter amount" : "Swap"}
          </Button>
        </motion.div>
      </Card>
    </motion.div>
  )
}

function TokenDropdown({
  tokens,
  onSelect,
  onClose,
}: {
  tokens: typeof TOKENS
  onSelect: (token: (typeof TOKENS)[0]) => void
  onClose: () => void
}) {
  return (
    <>
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        exit={{ opacity: 0 }}
        className="fixed inset-0 z-40 bg-black/20 backdrop-blur-sm"
        onClick={onClose}
      />
      <motion.div
        initial={{ opacity: 0, y: -10, scale: 0.95 }}
        animate={{ opacity: 1, y: 0, scale: 1 }}
        exit={{ opacity: 0, y: -10, scale: 0.95 }}
        transition={{ duration: 0.2 }}
        className="absolute top-full mt-2 left-0 right-0 sage-glass rounded-xl p-2 z-50 border border-border/50 shadow-2xl"
      >
        {tokens.map((token) => (
          <motion.button
            key={token.symbol}
            whileHover={{ scale: 1.02, backgroundColor: "rgba(255, 31, 72, 0.1)" }}
            whileTap={{ scale: 0.98 }}
            onClick={() => onSelect(token)}
            className="w-full flex items-center gap-3 p-3 rounded-lg hover:bg-secondary/50 transition-colors"
          >
            <span className="text-3xl">{token.icon}</span>
            <div className="flex-1 text-left">
              <div className="font-bold text-foreground">{token.symbol}</div>
              <div className="text-sm text-muted-foreground">{token.name}</div>
            </div>
            {token.isStable && (
              <span className="text-xs px-2 py-1 rounded-full bg-green-500/20 text-green-500 font-medium">Stable</span>
            )}
          </motion.button>
        ))}
      </motion.div>
    </>
  )
}
