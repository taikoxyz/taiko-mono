import { useState, useEffect } from 'react';
import { WagmiProvider } from 'wagmi';
import { useAccount } from 'wagmi';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { Toaster } from 'react-hot-toast';

import { config, surgeL1Chain } from './lib/config';
import { Header } from './components/Header';
import { SwapCard } from './components/SwapCard';
import { BridgeCard } from './components/BridgeCard';
import { LiquidityCard } from './components/LiquidityCard';
import { SmartWalletSetup } from './components/SmartWalletSetup';
import { NetworkSetup } from './components/NetworkSetup';
import { FundWallet } from './components/FundWallet';
import { useSmartWallet } from './hooks/useSmartWallet';
import { useTokenBalances } from './hooks/useTokenBalances';
import { ActiveTab } from './types';

const queryClient = new QueryClient();

function AppContent() {
  const { smartWallet, isConnected, isLoading } = useSmartWallet();
  const { chainId } = useAccount();
  const { ethBalance, usdcBalance, ethFormatted, usdcFormatted } = useTokenBalances(smartWallet);

  const [activeTab, setActiveTab] = useState<ActiveTab>('swap');
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
        <div className="text-center mb-6">
          <h2 className="text-3xl font-bold text-white mb-2">Cross-Chain DEX</h2>
          <p className="text-gray-400">
            L1 swaps powered by L2 liquidity. Real bridging, no mock minting.
          </p>
        </div>

        {/* Tab Navigation */}
        <div className="flex gap-1 mb-6 bg-surge-card/50 rounded-xl p-1 border border-surge-border/30">
          {(['swap', 'liquidity', 'bridge'] as ActiveTab[]).map((tab) => (
            <button
              key={tab}
              onClick={() => setActiveTab(tab)}
              className={`px-5 py-2 rounded-lg text-sm font-medium transition-all duration-200 ${
                activeTab === tab
                  ? 'bg-gradient-to-r from-surge-primary to-surge-secondary text-white shadow-md'
                  : 'text-gray-400 hover:text-white hover:bg-surge-dark/50'
              }`}
            >
              {tab === 'swap' ? 'Swap' : tab === 'bridge' ? 'Bridge' : 'Liquidity'}
            </button>
          ))}
        </div>

        {/* Active Panel */}
        {activeTab === 'swap' && (
          <SwapCard
            onSetupWallet={() => setShowWalletSetup(true)}
            onFundWallet={() => setShowFundWallet(true)}
          />
        )}
        {activeTab === 'bridge' && (
          <BridgeCard
            onSetupWallet={() => setShowWalletSetup(true)}
          />
        )}
        {activeTab === 'liquidity' && (
          <LiquidityCard
            onSetupWallet={() => setShowWalletSetup(true)}
          />
        )}

        {/* Pool Info */}
        <div className="mt-8 text-center text-sm text-gray-500">
          <p>Powered by Surge Protocol</p>
          <p className="mt-1">0.3% swap fee • Real token bridging • Cross-chain settlement</p>
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
