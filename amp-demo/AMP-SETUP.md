# SAGE Protocol - Amp Integration Guide

## ✅ Lo que ya está configurado

### 1. **Dataset Definition** (`amp.config.ts`)
- Namespace: `eth_global`
- Name: `sarm`
- Network: `base_sepolia`
- Contratos:
  - SAGEHook: `0x828e95D79fC2fD10882C13042edDe1071BB2E080`
  - SSAOracleAdapter: `0x444a4967487B655675c7F3EF0Ec68f93ae9f6866`

### 2. **ABIs** (`app/src/lib/abi.ts`)
Eventos configurados:
- ✅ `RatingUpdated` - Cambios de ratings de tokens
- ✅ `FeedIdSet` - Configuración de feeds Chainlink
- ✅ `RiskCheck` - Revisiones de riesgo en swaps
- ✅ `RiskModeChanged` - Cambios de modo de riesgo en pools
- ✅ `FeeOverrideApplied` - Aplicación de fees dinámicos

### 3. **Dashboard** (`app/src/components/SAGEDashboard.tsx`)
Queries SQL ya implementados:
```sql
-- Stats globales
SELECT COUNT(*) FROM "eth_global/sarm@dev".risk_check
SELECT COUNT(*) FROM "eth_global/sarm@dev".fee_override_applied
SELECT COUNT(*) FROM "eth_global/sarm@dev".rating_updated

-- Risk checks recientes
SELECT * FROM "eth_global/sarm@dev".risk_check 
ORDER BY block_num DESC LIMIT 10

-- Rating updates
SELECT * FROM "eth_global/sarm@dev".rating_updated 
ORDER BY block_num DESC LIMIT 10

-- Fee overrides
SELECT * FROM "eth_global/sarm@dev".fee_override_applied 
ORDER BY block_num DESC LIMIT 15
```

### 4. **Environment** (`.env`)
```bash
VITE_AMP_NETWORK=base_sepolia
VITE_AMP_RPC_DATASET=_/base_sepolia@0.0.1
VITE_SAGE_HOOK=0x828e95D79fC2fD10882C13042edDe1071BB2E080
VITE_ORACLE=0x444a4967487B655675c7F3EF0Ec68f93ae9f6866
VITE_RPC_URL=https://sepolia.base.org
```

## 🚀 Cómo completar el setup

### Paso 1: Inicializar Amp
```bash
cd amp-demo

# Crear configuración base (sigue el wizard)
ampctl init

# Esto crea ~/.amp/config.toml con settings del daemon
```

### Paso 2: Iniciar servidor Amp
```bash
# En una terminal separada
ampd dev --config ~/.amp/config.toml
```

### Paso 3: Desplegar dataset
```bash
# En otra terminal
pnpm amp deploy --reference "eth_global/sarm@dev"
```

### Paso 4: Verificar deployment
```bash
# Query de test
pnpm amp query 'SELECT COUNT(*) as total FROM "eth_global/sarm@dev".risk_check'
```

### Paso 5: Iniciar frontend
```bash
pnpm dev
```

Abre http://localhost:5173 para ver el dashboard.

## 📊 Qué mostrará el dashboard

### Stats Cards
- Total Risk Checks realizados
- Total Swaps con fees dinámicos
- Total Rating Updates del oracle

### Recent Risk Checks Table
- Pool ID
- Ratings (token0/token1 → effective)
- Block number

### Rating Updates Table
- Token (USDC/USDT/DAI)
- Rating change (old → new)
- Block number

### Dynamic Fee Applications Table
- Pool ID
- Effective rating usado
- Fee aplicado (en bps y %)
- Block number

## 🎯 Para el hackathon

Este dashboard demuestra:
1. ✅ **Indexing on-chain events** - Todos los eventos de SAGE
2. ✅ **SQL queries** - Queries simples y agregaciones
3. ✅ **Real-time updates** - Refetch cada 10 segundos
4. ✅ **Cross-contract data** - Oracle + Hook combinados
5. ✅ **Risk analytics** - Visualización de fees dinámicos

## 📝 Queries de ejemplo adicionales

```sql
-- Fee distribution por rating
SELECT 
  effective_rating,
  COUNT(*) as swap_count,
  AVG(fee) as avg_fee
FROM "eth_global/sarm@dev".fee_override_applied
GROUP BY effective_rating
ORDER BY effective_rating

-- Tokens más volátiles (más cambios de rating)
SELECT 
  token,
  COUNT(*) as changes,
  MIN(new_rating) as min_rating,
  MAX(new_rating) as max_rating
FROM "eth_global/sarm@dev".rating_updated
GROUP BY token
ORDER BY changes DESC

-- Pools con más actividad de risk checks
SELECT 
  pool_id,
  COUNT(*) as checks,
  AVG(effective_rating) as avg_rating
FROM "eth_global/sarm@dev".risk_check
GROUP BY pool_id
ORDER BY checks DESC
```

## 🏆 Amp Prize Requirements

**Califica para "Best Use of Amp Datasets" ($3k 1st place)**

✅ Compelling end-to-end product
✅ Real-world DeFi insights (risk-based fee analytics)
✅ Protocol monitoring (rating changes, risk transitions)
✅ User experience (simple SQL → React dashboard)

## 🔗 Links útiles

- Dataset config: `amp.config.ts`
- Dashboard component: `app/src/components/SAGEDashboard.tsx`
- ABI events: `app/src/lib/abi.ts`
- Amp queries helper: `app/src/lib/amp.ts`
