import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { createRoot } from "react-dom/client";
import { WagmiProvider } from "wagmi";

import "./index.css";

import { SAGEDashboard } from "./components/SAGEDashboard.tsx";
import { wagmiConfig } from "./lib/config.ts";

createRoot(document.getElementById("root")!).render(
  <QueryClientProvider client={new QueryClient()}>
    <WagmiProvider config={wagmiConfig}>
      <SAGEDashboard />
    </WagmiProvider>
  </QueryClientProvider>
);
