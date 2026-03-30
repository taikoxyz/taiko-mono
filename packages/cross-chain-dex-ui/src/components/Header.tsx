import { useState, useRef, useEffect, useCallback } from 'react';
import { useAccount, useConnect, useDisconnect, useBalance } from 'wagmi';
import { formatEther } from 'viem';
import toast from 'react-hot-toast';
import { useSmartWallet } from '../hooks/useSmartWallet';
import { useTokenBalances } from '../hooks/useTokenBalances';
import { useUserOp } from '../hooks/useUserOp';
import { surgeL1Chain } from '../lib/config';
import { ETH_TOKEN } from '../lib/constants';
import { DisclaimerModal } from './DisclaimerModal';
import { useDisclaimer } from '../hooks/useDisclaimer';

interface HeaderProps {
  onSetupWallet: () => void;
}

export function Header({ onSetupWallet }: HeaderProps) {
  const { smartWallet, isConnected, ownerAddress } = useSmartWallet();
  const { address, chainId } = useAccount();
  const { connect, connectors } = useConnect();
  const { disconnect } = useDisconnect();
  const { executeWithdraw, isPending } = useUserOp();
  const { isDisclaimerOpen, requireDisclaimer, onAccept, onCancel } = useDisclaimer();

  // EOA balance (refresh every 3 seconds)
  const { data: eoaBalance } = useBalance({
    address,
    query: { refetchInterval: 3000 },
  });

  // Smart wallet balances
  const { ethBalance, usdcBalance, ethFormatted, usdcFormatted } = useTokenBalances(smartWallet);

  const isWrongNetwork = isConnected && chainId !== surgeL1Chain.id;

  const [dropdownOpen, setDropdownOpen] = useState(false);
  const dropdownRef = useRef<HTMLDivElement>(null);

  // Close dropdown on outside click
  useEffect(() => {
    function handleClick(e: MouseEvent) {
      if (dropdownRef.current && !dropdownRef.current.contains(e.target as Node)) {
        setDropdownOpen(false);
      }
    }
    document.addEventListener('mousedown', handleClick);
    return () => document.removeEventListener('mousedown', handleClick);
  }, []);

  const handleConnect = () => {
    const injectedConnector = connectors.find((c) => c.id === 'injected');
    if (injectedConnector) {
      connect({ connector: injectedConnector });
    }
  };

  const handleWithdraw = useCallback(async () => {
    if (!smartWallet || !ownerAddress) return;
    if (ethBalance === 0n && usdcBalance === 0n) {
      toast.error('No funds to withdraw');
      return;
    }
    setDropdownOpen(false);
    const success = await executeWithdraw({ owner: ownerAddress, smartWallet, ethBalance, usdcBalance });
    if (success) {
      toast.success('Withdrawal submitted');
    }
  }, [smartWallet, ownerAddress, ethBalance, usdcBalance, executeWithdraw]);

  return (
    <header className="w-full px-6 py-3 flex items-center justify-between border-b border-surge-border/30 bg-surge-dark/50 backdrop-blur-sm relative z-10">
      <div className="flex items-center gap-3">
        <div className="w-8 h-8 bg-gradient-to-br from-surge-primary to-surge-secondary rounded-lg shadow-lg shadow-surge-primary/20" />
        <h1 className="text-xl font-bold text-white">Surge DEX</h1>
      </div>

      <div className="flex items-center gap-4">
        {/* Smart Wallet with balances + dropdown */}
        {isConnected && !isWrongNetwork && smartWallet && (
          <div className="hidden md:flex items-center relative" ref={dropdownRef}>
            <div className="flex items-center gap-2 px-3 py-2 bg-surge-card rounded-lg border border-surge-border/50">
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
                {parseFloat(ethFormatted).toFixed(4)} {ETH_TOKEN.symbol}
              </span>
              <span className="text-xs text-gray-400">
                {parseFloat(usdcFormatted).toFixed(2)} USDC
              </span>
              <span className="text-xs text-gray-500">|</span>
              <button
                onClick={() => setDropdownOpen((prev) => !prev)}
                className="text-gray-400 hover:text-white transition-colors p-0.5"
                title="Wallet actions"
              >
                <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                </svg>
              </button>
            </div>

            {/* Dropdown */}
            {dropdownOpen && (
              <div className="absolute right-0 top-full mt-1 bg-surge-card border border-surge-border/50 rounded-lg shadow-xl shadow-black/30 overflow-hidden min-w-[240px] z-50">
                <button
                  onClick={() => requireDisclaimer(handleWithdraw)}
                  disabled={isPending || (ethBalance === 0n && usdcBalance === 0n)}
                  className="w-full px-4 py-3 text-left text-sm text-gray-300 hover:bg-surge-dark/50 hover:text-white transition-colors disabled:opacity-40 disabled:cursor-not-allowed flex items-center gap-2"
                >
                  <svg className="w-4 h-4 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" />
                  </svg>
                  {isPending ? 'Withdrawing...' : 'Withdraw all funds to owner'}
                </button>
              </div>
            )}
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
                ({parseFloat(formatEther(eoaBalance.value)).toFixed(4)} {ETH_TOKEN.symbol})
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

      <DisclaimerModal isOpen={isDisclaimerOpen} onAccept={onAccept} onCancel={onCancel} />
    </header>
  );
}
