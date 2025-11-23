import { SmartSwap } from "@/components/smart-swap"
import { AnalyticsDashboard } from "@/components/analytics-dashboard"
import { WalletConnect } from "@/components/wallet-connect"
import { DebugPanel } from "@/components/debug-panel"
import { Footer } from "@/components/footer"
import Image from "next/image"

export default function Home() {
  return (
    <>
      <main className="min-h-screen bg-[#0f0f11] py-8 px-4 relative overflow-hidden">
        {/* Gradient orb 1 - top left */}
        <div className="absolute top-0 left-0 w-96 h-96 bg-gradient-to-br from-sage-vibrant-red/30 via-sage-crimson/20 to-transparent rounded-full blur-3xl animate-pulse-slow opacity-50" />

        {/* Gradient orb 2 - top right */}
        <div className="absolute top-20 right-0 w-[32rem] h-[32rem] bg-gradient-to-bl from-sage-crimson/40 via-sage-deep-wine/30 to-transparent rounded-full blur-3xl animate-float opacity-40" />

        {/* Gradient orb 3 - bottom left */}
        <div className="absolute bottom-0 left-1/4 w-[28rem] h-[28rem] bg-gradient-to-tr from-sage-vibrant-red/25 via-sage-crimson/15 to-transparent rounded-full blur-3xl animate-float-delayed opacity-60" />

        {/* Gradient orb 4 - center right */}
        <div className="absolute top-1/2 right-1/4 w-80 h-80 bg-gradient-to-l from-sage-deep-wine/30 via-sage-vibrant-red/20 to-transparent rounded-full blur-2xl animate-pulse opacity-50" />

        {/* Diagonal gradient sweep */}
        <div className="absolute inset-0 bg-gradient-to-br from-sage-deep-wine/10 via-transparent to-sage-vibrant-red/10 animate-gradient-shift opacity-70" />

        <div className="relative z-10">
          {/* Header */}
          <header className="max-w-7xl mx-auto mb-12">
            <div className="flex items-center gap-3 justify-center mb-4">
              <Image src="/sage-logo.svg" alt="SAGE Protocol" width={50} height={45} className="animate-pulse-slow" />
              <h1 className="text-4xl md:text-5xl font-bold sage-gradient-text">SAGE Protocol</h1>
            </div>
            <p className="text-center text-muted-foreground text-lg">
              Next-generation DeFi with intelligent fee optimization
            </p>
          </header>

          {/* Main Content */}
          <div className="max-w-7xl mx-auto space-y-8">
            {/* Wallet Section */}
            <div className="flex justify-center">
              <WalletConnect />
            </div>

            {/* Swap and Analytics Grid */}
            <div className="grid lg:grid-cols-2 gap-8 items-start">
              {/* Smart Swap Component */}
              <div className="flex justify-center lg:justify-end">
                <SmartSwap />
              </div>

              {/* Analytics Dashboard */}
              <div className="flex justify-center lg:justify-start">
                <AnalyticsDashboard />
              </div>
            </div>

            {/* Debug Panel */}
            <div className="max-w-4xl mx-auto">
              <DebugPanel />
            </div>
          </div>
        </div>
      </main>

      {/* Footer Component */}
      <Footer />
    </>
  )
}
