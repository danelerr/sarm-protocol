"use client"

import { motion } from "framer-motion"

export function AreaChart({ data }: { data: { time: string; value: number }[] }) {
  const maxValue = Math.max(...data.map((d) => d.value))
  const points = data.map((d, i) => {
    const x = (i / (data.length - 1)) * 100
    const y = 100 - (d.value / maxValue) * 80
    return { x, y }
  })

  const pathData = points.map((p, i) => `${i === 0 ? "M" : "L"} ${p.x} ${p.y}`).join(" ")

  const areaPath = `${pathData} L 100 100 L 0 100 Z`

  return (
    <div className="relative h-48 w-full">
      <svg viewBox="0 0 100 100" className="w-full h-full" preserveAspectRatio="none">
        <defs>
          <linearGradient id="areaGradient" x1="0%" y1="0%" x2="0%" y2="100%">
            <stop offset="0%" stopColor="#ff1f48" stopOpacity="0.4" />
            <stop offset="100%" stopColor="#ff1f48" stopOpacity="0.05" />
          </linearGradient>
        </defs>

        <motion.path
          d={areaPath}
          fill="url(#areaGradient)"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ duration: 1 }}
        />

        <motion.path
          d={pathData}
          fill="none"
          stroke="#ff1f48"
          strokeWidth="0.5"
          initial={{ pathLength: 0 }}
          animate={{ pathLength: 1 }}
          transition={{ duration: 1.5, ease: "easeInOut" }}
        />

        {points.map((point, i) => (
          <motion.circle
            key={i}
            cx={point.x}
            cy={point.y}
            r="1"
            fill="#ff1f48"
            initial={{ scale: 0 }}
            animate={{ scale: 1 }}
            transition={{ delay: i * 0.1, duration: 0.3 }}
          />
        ))}
      </svg>

      <div className="flex justify-between mt-2 text-xs text-muted-foreground">
        {data.map((d, i) => (
          <span key={i}>{d.time}</span>
        ))}
      </div>
    </div>
  )
}

export function BarChart({ data }: { data: { category: string; amount: number }[] }) {
  const maxAmount = Math.max(...data.map((d) => d.amount))

  return (
    <div className="space-y-4">
      {data.map((item, i) => {
        const percentage = (item.amount / maxAmount) * 100
        const gradients = ["from-[#4a0e0e] to-[#c90000]", "from-[#c90000] to-[#ff1f48]", "from-green-600 to-green-400"]

        return (
          <div key={i} className="space-y-2">
            <div className="flex justify-between text-sm">
              <span className="text-muted-foreground">{item.category}</span>
              <span className="font-bold text-foreground">${(item.amount / 1000).toFixed(1)}K</span>
            </div>
            <div className="h-3 bg-secondary/30 rounded-full overflow-hidden">
              <motion.div
                className={`h-full bg-gradient-to-r ${gradients[i]} rounded-full`}
                initial={{ width: 0 }}
                animate={{ width: `${percentage}%` }}
                transition={{ duration: 1, delay: i * 0.2, ease: "easeOut" }}
              />
            </div>
          </div>
        )
      })}
    </div>
  )
}
