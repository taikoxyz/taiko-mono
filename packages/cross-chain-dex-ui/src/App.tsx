import { useState, useEffect } from 'react';
import { WagmiProvider } from 'wagmi';
import { useAccount } from 'wagmi';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { Toaster } from 'react-hot-toast';

import { config, surgeL1Chain } from './lib/config';
import { Header } from './components/Header';
import { SwapCard } from './components/SwapCard';
import { SmartWalletSetup } from './components/SmartWalletSetup';
import { NetworkSetup } from './components/NetworkSetup';
import { FundWallet } from './components/FundWallet';
import { useSmartWallet } from './hooks/useSmartWallet';
import { useTokenBalances } from './hooks/useTokenBalances';

const queryClient = new QueryClient();

function AppContent() {
  const { smartWallet, isConnected, isLoading } = useSmartWallet();
  const { chainId } = useAccount();
  const { ethBalance, usdcBalance, ethFormatted, usdcFormatted } = useTokenBalances(smartWallet);

  const [showWalletSetup, setShowWalletSetup] = useState(false);
  const [showNetworkSetup, setShowNetworkSetup] = useState(false);
  const [showFundWallet, setShowFundWallet] = useState(false);
  const [hasShownFundModal, setHasShownFundModal] = useState(false);

  const isWrongNetwork = isConnected && chainId !== surgeL1Chain.id;
  const hasInsufficientFunds = smartWallet && ethBalance === 0n && usdcBalance === 0n;

  // Auto-show network setup if on wrong network
  useEffect(() => {
    if (isWrongNetwork) {
      setShowNetworkSetup(true);
    } else {
      setShowNetworkSetup(false);
    }
  }, [isWrongNetwork]);

  // Auto-show wallet setup if connected, on correct network, but no smart wallet
  useEffect(() => {
    if (isConnected && !isWrongNetwork && !smartWallet && !isLoading) {
      setShowWalletSetup(true);
    }
  }, [isConnected, isWrongNetwork, smartWallet, isLoading]);

  // Auto-show fund wallet modal if smart wallet has no funds (only once per session)
  useEffect(() => {
    if (smartWallet && hasInsufficientFunds && !hasShownFundModal && !isLoading) {
      setShowFundWallet(true);
      setHasShownFundModal(true);
    }
  }, [smartWallet, hasInsufficientFunds, hasShownFundModal, isLoading]);

  return (
    <div className="min-h-screen bg-surge-dark flex flex-col">
      <Header onSetupWallet={() => setShowWalletSetup(true)} />

      <main className="flex-1 flex flex-col items-center justify-center px-4 py-8">
        <div className="text-center mb-8">
          <h2 className="text-3xl font-bold text-white mb-2">Cross-Chain Swap</h2>
          <p className="text-gray-400">
            L1 swaps powered by L2 liquidity. Instant same slot settlement.
          </p>
        </div>

        <SwapCard
          onSetupWallet={() => setShowWalletSetup(true)}
          onFundWallet={() => setShowFundWallet(true)}
        />

        {/* Pool Info */}
        <div className="mt-8 text-center text-sm text-gray-500">
          <p>Powered by Surge Protocol</p>
          <p className="mt-1">0.3% swap fee • Instant cross-chain settlement</p>
        </div>
      </main>

      <NetworkSetup
        isOpen={showNetworkSetup}
        onClose={() => setShowNetworkSetup(false)}
      />

      <SmartWalletSetup
        isOpen={showWalletSetup && !isWrongNetwork}
        onClose={() => setShowWalletSetup(false)}
      />

      {smartWallet && (
        <FundWallet
          isOpen={showFundWallet}
          onClose={() => setShowFundWallet(false)}
          smartWallet={smartWallet}
          ethBalance={ethFormatted}
          usdcBalance={usdcFormatted}
        />
      )}

      <Toaster
        position="bottom-right"
        toastOptions={{
          style: {
            background: '#0f2847',
            color: '#e2e8f0',
            border: '1px solid #1e4976',
          },
          success: {
            iconTheme: {
              primary: '#10b981',
              secondary: '#fff',
            },
          },
          error: {
            iconTheme: {
              primary: '#ef4444',
              secondary: '#fff',
            },
          },
        }}
      />
    </div>
  );
}

function App() {
  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <AppContent />
      </QueryClientProvider>
    </WagmiProvider>
  );
}

export default App;
