import { useState, useEffect } from 'react';
import { WagmiProvider } from 'wagmi';
import { useAccount, useSwitchChain } from 'wagmi';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { RainbowKitProvider, darkTheme } from '@rainbow-me/rainbowkit';
import '@rainbow-me/rainbowkit/styles.css';
import { Toaster } from 'react-hot-toast';

import { config, surgeL1Chain, surgeL2Chain } from './lib/config';
import { Header } from './components/Header';
import { SwapCard } from './components/SwapCard';
import { BridgeCard } from './components/BridgeCard';
import { LiquidityCard } from './components/LiquidityCard';
import { SmartWalletSetup } from './components/SmartWalletSetup';
import { NetworkSetup } from './components/NetworkSetup';
import { FundWallet } from './components/FundWallet';
import { TxStatusOverlay } from './components/TxStatusOverlay';
import { TxStatusProvider, useTxStatus } from './context/TxStatusContext';
import { useSmartWallet, SmartWalletProvider } from './context/SmartWalletContext';
import { useSharedTokenBalances } from './context/SmartWalletContext';
import { AccountModeSelector } from './components/AccountModeSelector';
import { ActiveTab } from './types';

const queryClient = new QueryClient();

function AppContent() {
  const { txStatus, setTxStatus } = useTxStatus();
  const {
  smartWallet, isConnected, isLoading, ownerAddress,
  createSmartWallet, isCreating,
  l2WalletExists, createL2Wallet, isCreatingL2Wallet,
  accountMode, has7702Delegation, showModeSelector, selectAccountMode, setShowModeSelector,
} = useSmartWallet();
  const { chainId } = useAccount();
  const { switchChainAsync } = useSwitchChain();
  const { ethBalance, usdcBalance, ethFormatted, usdcFormatted, isLoading: balancesLoading } = useSharedTokenBalances();

  const [activeTab, setActiveTab] = useState<ActiveTab>('swap');
  const [showWalletSetup, setShowWalletSetup] = useState(false);
  const [dismissedWalletSetup, setDismissedWalletSetup] = useState(false);
  const [showNetworkSetup, setShowNetworkSetup] = useState(false);
  const [showFundWallet, setShowFundWallet] = useState(false);
  const [hasShownFundModal, setHasShownFundModal] = useState(false);
  // Accept both L1 and L2 as valid networks
  const isWrongNetwork = isConnected && chainId !== surgeL1Chain.id && chainId !== surgeL2Chain.id;

  // Auto-switch to L1 if on wrong network (no modal prompt)
  useEffect(() => {
    if (isWrongNetwork) {
      switchChainAsync({ chainId: surgeL1Chain.id }).catch(() => {
        // If auto-switch fails, show manual network setup
        setShowNetworkSetup(true);
      });
    } else {
      setShowNetworkSetup(false);
    }
  }, [isWrongNetwork, switchChainAsync]);

  // Auto-switch to L1 when on swap/liquidity tabs
  useEffect(() => {
    if ((activeTab === 'swap' || activeTab === 'liquidity') && chainId === surgeL2Chain.id && isConnected) {
      switchChainAsync({ chainId: surgeL1Chain.id }).catch(() => {});
    }
  }, [activeTab, chainId, isConnected, switchChainAsync]);

  // Reset dismissed flag when wallet connects/disconnects
  useEffect(() => {
    setDismissedWalletSetup(false);
  }, [isConnected, ownerAddress]);

  // Auto-show wallet setup if connected, on correct network, but no smart wallet
  // Auto-close when wallet is created
  useEffect(() => {
    if (isConnected && !isWrongNetwork && !smartWallet && !isLoading && !dismissedWalletSetup && accountMode === 'safe' && !showModeSelector) {
      setShowWalletSetup(true);
    } else if (smartWallet && showWalletSetup) {
      setShowWalletSetup(false);
    }
  }, [isConnected, isWrongNetwork, smartWallet, isLoading, showWalletSetup, dismissedWalletSetup, accountMode, showModeSelector]);

  // Auto-show fund wallet modal when:
  // 1. Wallet has no funds (needs funding), OR
  // 2. Wallet has funds but L2 wallet doesn't exist (needs L2 creation)
  // Only once per session
  useEffect(() => {
    // Skip fund wallet modal entirely in ambire mode — the EOA already has funds
    if (accountMode === 'ambire') return;
    if (!smartWallet || hasShownFundModal || balancesLoading || isLoading || showNetworkSetup || showWalletSetup) return;
    const needsFunding = ethBalance === 0n && usdcBalance === 0n;
    const needsL2 = accountMode === 'safe' && !l2WalletExists;
    if (needsFunding || needsL2) {
      setShowFundWallet(true);
      setHasShownFundModal(true);
    }
  }, [smartWallet, ethBalance, usdcBalance, balancesLoading, hasShownFundModal, isLoading, l2WalletExists, showNetworkSetup, showWalletSetup, accountMode]);

  return (
    <div className="h-screen overflow-hidden bg-surge-dark flex flex-col">
      <Header onSetupWallet={() => has7702Delegation ? setShowModeSelector(true) : setShowWalletSetup(true)} />

      <main className="flex-1 min-h-0 relative flex items-center justify-center px-4">
        {/* Tab Navigation — absolutely positioned near header, independent of card */}
        <div className="absolute top-8 left-1/2 -translate-x-1/2 flex gap-1 bg-surge-card/50 rounded-xl p-1 border border-surge-border/30 z-10">
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

        {/* Footer tagline — absolutely positioned at bottom */}
        <div className="absolute bottom-5 left-1/2 -translate-x-1/2 text-center whitespace-nowrap">
          <p className="text-sm text-gray-400">Powered by Surge Protocol</p>
          <p className="text-sm text-gray-500 mt-1">L1 swaps through L2 liquidity • Real time cross chain settlement</p>
        </div>

        {/* Active Panel — centered in full main area */}
        <div className="w-full flex items-center justify-center">
          {activeTab === 'swap' && (
            <SwapCard
              onSetupWallet={() => setShowWalletSetup(true)}
              onFundWallet={() => setShowFundWallet(true)}
            />
          )}
          {activeTab === 'bridge' && (
            <BridgeCard
              onSetupWallet={() => setShowWalletSetup(true)}
              onFundWallet={() => setShowFundWallet(true)}
            />
          )}
          {activeTab === 'liquidity' && (
            <LiquidityCard
              onSetupWallet={() => setShowWalletSetup(true)}
            />
          )}
        </div>
      </main>

      <NetworkSetup
        isOpen={showNetworkSetup}
        onClose={() => setShowNetworkSetup(false)}
      />

      <AccountModeSelector
        isOpen={showModeSelector}
        onSelect={selectAccountMode}
        onClose={() => setShowModeSelector(false)}
      />

      <SmartWalletSetup
        isOpen={showWalletSetup && !isWrongNetwork && !showModeSelector}
        onClose={() => {
          setShowWalletSetup(false);
          setDismissedWalletSetup(true);
        }}
        ownerAddress={ownerAddress}
        isCreating={isCreating}
        createSmartWallet={createSmartWallet}
      />

      {smartWallet && (
        <FundWallet
          isOpen={showFundWallet}
          onClose={() => setShowFundWallet(false)}
          smartWallet={smartWallet}
          ethBalance={ethFormatted}
          usdcBalance={usdcFormatted}
          l2WalletExists={accountMode === 'ambire' ? true : l2WalletExists}
          onCreateL2Wallet={accountMode === 'ambire' ? undefined : createL2Wallet}
          isCreatingL2Wallet={isCreatingL2Wallet}
        />
      )}

      {/* Full-screen transaction status overlay */}
      <TxStatusOverlay
        state={txStatus}
        onClose={() => setTxStatus({ phase: 'idle' })}
      />

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
        <RainbowKitProvider theme={darkTheme({ accentColor: '#10b981' })}>
          <TxStatusProvider>
            <SmartWalletProvider>
              <AppContent />
            </SmartWalletProvider>
          </TxStatusProvider>
        </RainbowKitProvider>
      </QueryClientProvider>
    </WagmiProvider>
  );
}

export default App;
