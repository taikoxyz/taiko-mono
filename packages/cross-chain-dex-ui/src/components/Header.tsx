import { useAccount, useConnect, useDisconnect, useBalance } from 'wagmi';
import { formatEther } from 'viem';
import toast from 'react-hot-toast';
import { useSmartWallet } from '../hooks/useSmartWallet';
import { useTokenBalances } from '../hooks/useTokenBalances';
import { surgeL1Chain } from '../lib/config';

interface HeaderProps {
  onSetupWallet: () => void;
}

export function Header({ onSetupWallet }: HeaderProps) {
  const { smartWallet, isConnected } = useSmartWallet();
  const { address, chainId } = useAccount();
  const { connect, connectors } = useConnect();
  const { disconnect } = useDisconnect();

  // EOA balance (refresh every 3 seconds)
  const { data: eoaBalance } = useBalance({
    address,
    query: { refetchInterval: 3000 },
  });

  // Smart wallet balances
  const { ethFormatted, usdcFormatted } = useTokenBalances(smartWallet);

  const isWrongNetwork = isConnected && chainId !== surgeL1Chain.id;

  const handleConnect = () => {
    const injectedConnector = connectors.find((c) => c.id === 'injected');
    if (injectedConnector) {
      connect({ connector: injectedConnector });
    }
  };

  return (
    <header className="w-full px-6 py-4 flex items-center justify-between border-b border-surge-border/30 bg-surge-dark/50 backdrop-blur-sm relative z-10">
      <div className="flex items-center gap-3">
        <div className="w-8 h-8 bg-gradient-to-br from-surge-primary to-surge-secondary rounded-lg shadow-lg shadow-surge-primary/20" />
        <h1 className="text-xl font-bold text-white">Surge DEX</h1>
      </div>

      <div className="flex items-center gap-4">
        {/* Smart Wallet with balances */}
        {isConnected && !isWrongNetwork && smartWallet && (
          <div className="hidden md:flex items-center gap-2 px-3 py-2 bg-surge-card rounded-lg border border-surge-border/50">
            <div className="w-2 h-2 bg-green-500 rounded-full" />
            <button
              onClick={() => {
                navigator.clipboard.writeText(smartWallet);
                toast.success('Smart wallet address copied!');
              }}
              className="text-sm text-gray-300 hover:text-white transition-colors flex items-center gap-1"
              title="Click to copy address"
            >
              Smart Wallet: {smartWallet.slice(0, 6)}...{smartWallet.slice(-4)}
              <svg className="w-3 h-3 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
              </svg>
            </button>
            <span className="text-xs text-gray-500">|</span>
            <span className="text-xs text-gray-400">
              {parseFloat(ethFormatted).toFixed(4)} xDAI
            </span>
            <span className="text-xs text-gray-400">
              {parseFloat(usdcFormatted).toFixed(2)} USDC
            </span>
          </div>
        )}

        {isConnected && !smartWallet && !isWrongNetwork && (
          <button
            onClick={onSetupWallet}
            className="px-4 py-2 bg-surge-primary hover:bg-surge-secondary text-white rounded-lg text-sm font-medium transition-colors"
          >
            Setup Smart Wallet
          </button>
        )}

        {/* EOA Wallet with balance */}
        {isConnected ? (
          <button
            onClick={() => disconnect()}
            className="px-4 py-2 bg-surge-card hover:bg-surge-border text-white rounded-lg text-sm font-medium transition-colors border border-surge-border flex items-center gap-2"
          >
            <span>{address?.slice(0, 6)}...{address?.slice(-4)}</span>
            {eoaBalance && (
              <span className="text-xs text-gray-400">
                ({parseFloat(formatEther(eoaBalance.value)).toFixed(4)} xDAI)
              </span>
            )}
          </button>
        ) : (
          <button
            onClick={handleConnect}
            className="px-4 py-2 bg-surge-primary hover:bg-surge-secondary text-white rounded-lg text-sm font-medium transition-colors"
          >
            Connect Wallet
          </button>
        )}
      </div>
    </header>
  );
}
