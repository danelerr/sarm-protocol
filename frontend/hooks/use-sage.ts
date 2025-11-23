"use client"

import { useReadContract } from "wagmi"
import { CONTRACTS, TOKENS, ORACLE_ABI, calculateDynamicFee } from "@/lib/contracts"

// Hook para leer rating de un token desde el oracle
export function useTokenRating(tokenAddress: `0x${string}` | undefined) {
  const { data: rating, isLoading, error } = useReadContract({
    address: CONTRACTS.oracle as `0x${string}`,
    abi: ORACLE_ABI,
    functionName: "getRating",
    args: tokenAddress ? [tokenAddress] : undefined,
    query: {
      enabled: !!tokenAddress,
      refetchInterval: 10000, // Refetch cada 10 segundos
    },
  })

  return {
    rating: rating as number | undefined,
    isLoading,
    error,
  }
}

// Hook para calcular fees dinámicos de un par de tokens
export function useDynamicFees(token0Address: `0x${string}` | undefined, token1Address: `0x${string}` | undefined) {
  const { rating: rating0, isLoading: loading0 } = useTokenRating(token0Address)
  const { rating: rating1, isLoading: loading1 } = useTokenRating(token1Address)

  const isLoading = loading0 || loading1

  // Hardcoded ratings como fallback (coinciden con deployment)
  const FALLBACK_RATINGS: Record<string, number> = {
    [TOKENS.USDC.toLowerCase()]: 1,
    [TOKENS.USDT.toLowerCase()]: 1,
    [TOKENS.DAI.toLowerCase()]: 3,
  }

  const finalRating0 = rating0 ?? (token0Address ? FALLBACK_RATINGS[token0Address.toLowerCase()] : undefined)
  const finalRating1 = rating1 ?? (token1Address ? FALLBACK_RATINGS[token1Address.toLowerCase()] : undefined)

  if (!finalRating0 || !finalRating1) {
    return {
      sageFee: null,
      standardFee: 0.30,
      savings: null,
      isLoading,
    }
  }

  // Tomar el mejor rating (más bajo = mejor)
  const bestRating = Math.min(finalRating0, finalRating1)
  const sageFee = calculateDynamicFee(bestRating) // 70 o 100 bps
  const standardFee = 0.30 // 0.30% standard Uniswap (30 bps)
  const sageFeePercent = sageFee / 100 // Convertir a porcentaje (70 -> 0.70%)
  
  // SAGE cobra MÁS que standard (0.70% vs 0.30%), mostrar diferencia
  const feeDifference = ((sageFeePercent - standardFee) / standardFee * 100).toFixed(1)
  const bpsDifference = sageFee - 30 // 70 - 30 = 40 bps más caro

  return {
    sageFee: sageFeePercent,
    standardFee,
    savings: feeDifference, // Será positivo (más caro)
    savingsAmount: `+${bpsDifference} bps (risk premium)`,
    isLoading: false,
    rating0: finalRating0,
    rating1: finalRating1,
    bestRating,
  }
}

// Hook helper para obtener ratings de todos los tokens
export function useAllTokenRatings() {
  const usdcRating = useTokenRating(TOKENS.USDC as `0x${string}`)
  const usdtRating = useTokenRating(TOKENS.USDT as `0x${string}`)
  const daiRating = useTokenRating(TOKENS.DAI as `0x${string}`)

  return {
    USDC: { ...usdcRating, rating: usdcRating.rating ?? 1 },
    USDT: { ...usdtRating, rating: usdtRating.rating ?? 1 },
    DAI: { ...daiRating, rating: daiRating.rating ?? 3 },
    isLoading: usdcRating.isLoading || usdtRating.isLoading || daiRating.isLoading,
  }
}
