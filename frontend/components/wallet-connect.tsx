"use client"

import { useEffect, useState } from "react"
import { motion } from "framer-motion"
import { Wallet, CheckCircle } from "lucide-react"
import { useAccount, useConnect, useDisconnect } from "wagmi"
import { Button } from "@/components/ui/button"
import { Card } from "@/components/ui/card"

export function WalletConnect() {
  const { address, isConnected } = useAccount()
  const { connect, connectors } = useConnect()
  const { disconnect } = useDisconnect()
  const [mounted, setMounted] = useState(false)

  useEffect(() => {
    setMounted(true)
  }, [])

  const handleConnect = () => {
    // Use the first available connector (usually MetaMask)
    const connector = connectors[0]
    if (connector) {
      connect({ connector })
    }
  }

  if (!mounted) {
    return (
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5, delay: 0.2 }}
        className="w-full max-w-md"
      >
        <Card className="sage-glass p-6">
          <div className="flex items-center gap-3 mb-4">
            <Wallet className="w-6 h-6 text-primary" />
            <h2 className="text-xl font-bold text-foreground">Wallet</h2>
          </div>
          <div className="space-y-4">
            <p className="text-sm text-muted-foreground">Loading...</p>
          </div>
        </Card>
      </motion.div>
    )
  }

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.5, delay: 0.2 }}
      className="w-full max-w-md"
    >
      <Card className="sage-glass p-6">
        <div className="flex items-center gap-3 mb-4">
          <Wallet className="w-6 h-6 text-primary" />
          <h2 className="text-xl font-bold text-foreground">Wallet</h2>
        </div>

        {!isConnected ? (
          <div className="space-y-4">
            <p className="text-sm text-muted-foreground">Connect your wallet to start trading on SAGE Protocol</p>
            <motion.div whileHover={{ scale: 1.02 }} whileTap={{ scale: 0.98 }}>
              <Button
                onClick={handleConnect}
                size="lg"
                className="w-full text-lg font-bold sage-gradient hover:opacity-90 transition-opacity"
              >
                <Wallet className="w-5 h-5 mr-2" />
                Connect Wallet
              </Button>
            </motion.div>
          </div>
        ) : (
          <div className="space-y-4">
            <div className="flex items-center gap-2 p-3 rounded-lg bg-green-500/10 border border-green-500/30">
              <CheckCircle className="w-5 h-5 text-green-500" />
              <span className="text-sm font-medium text-green-500">Wallet Connected</span>
            </div>

            <div className="sage-glass rounded-lg p-3">
              <p className="text-xs text-muted-foreground mb-1">Connected Address</p>
              <p className="font-mono text-sm text-foreground">
                {address?.slice(0, 6)}...{address?.slice(-4)}
              </p>
            </div>

            <motion.div whileHover={{ scale: 1.02 }} whileTap={{ scale: 0.98 }}>
              <Button
                onClick={() => disconnect()}
                variant="outline"
                size="lg"
                className="w-full text-lg font-bold border-primary/30 hover:bg-primary/10 bg-transparent"
              >
                Disconnect
              </Button>
            </motion.div>
          </div>
        )}
      </Card>
    </motion.div>
  )
}
