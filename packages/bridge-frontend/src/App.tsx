import React from "react";
import { Link, BrowserRouter as Router, Routes, Route } from "react-router-dom";
import "@rainbow-me/rainbowkit/styles.css";
import { getDefaultWallets, RainbowKitProvider } from "@rainbow-me/rainbowkit";
import { configureChains, createClient, WagmiConfig } from "wagmi";
// import { alchemyProvider } from "wagmi/providers/alchemy";
import { publicProvider } from "wagmi/providers/public";
import { ConnectButton } from "@rainbow-me/rainbowkit";

import { mainnet, taiko } from "./config/chains";

import Home from "./pages/Home";

const { chains, provider } = configureChains(
  [mainnet, taiko],
  [publicProvider()]
);

const { connectors } = getDefaultWallets({
  appName: "My RainbowKit App",
  chains,
});

const wagmiClient = createClient({
  autoConnect: true,
  connectors,
  provider,
});

function App() {
  return (
    <WagmiConfig client={wagmiClient}>
      <RainbowKitProvider chains={chains}>
        <Router>
          <header className="bg-white h-12 p-2 flex items-center justify-between text-taiko-blue">
            <Link to="/" className="flex items-center text-taiko-blue">
              <img src="/taikologo.png" alt="" height={48} width={48} />
              <span className="text-xl">Taiko</span>
            </Link>

            <ConnectButton />
          </header>

          <main className="bg-taiko-blue h-[calc(100vh-48px)] text-taiko-blue">
            <Routes>
              <Route path="/" element={<Home />} />
            </Routes>
          </main>
        </Router>
      </RainbowKitProvider>
    </WagmiConfig>
  );
}

export default App;
