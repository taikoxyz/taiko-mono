import { useState, useCallback, useMemo } from 'react';
import { parseEther, formatEther, Address } from 'viem';
import { TokenInput } from './TokenInput';
import { useSmartWallet } from '../hooks/useSmartWallet';
import { useTokenBalances } from '../hooks/useTokenBalances';
import { useUserOp } from '../hooks/useUserOp';
import { USDC_TOKEN } from '../lib/constants';

interface BridgeCardProps {
  onSetupWallet: () => void;
}

export function BridgeCard({ onSetupWallet }: BridgeCardProps) {
  const { smartWallet, isConnected } = useSmartWallet();
  const { usdcBalance } = useTokenBalances(smartWallet);
  const { executeBridge, isPending } = useUserOp();

  const [inputAmount, setInputAmount] = useState('');
  const [recipient, setRecipient] = useState('');

  const amountIn = useMemo(() => {
    try {
      return inputAmount ? parseEther(inputAmount) : 0n;
    } catch {
      return 0n;
    }
  }, [inputAmount]);

  const hasInsufficientBalance = amountIn > usdcBalance;

  // Use smart wallet as default recipient if none specified
  const effectiveRecipient = (recipient || smartWallet || '') as Address;

  const handleBridge = useCallback(async () => {
    if (!smartWallet || amountIn === 0n) return;

    const success = await executeBridge({
      amount: amountIn,
      recipient: effectiveRecipient,
      smartWallet,
    });

    if (success) {
      setInputAmount('');
    }
  }, [smartWallet, amountIn, effectiveRecipient, executeBridge]);

  const getButtonText = () => {
    if (isPending) return 'Bridging...';
    if (!isConnected) return 'Connect Wallet';
    if (!smartWallet) return 'Setup Smart Wallet First';
    if (!amountIn) return 'Enter Amount';
    if (hasInsufficientBalance) return 'Insufficient Balance';
    return 'Bridge to L2';
  };

  const isDisabled = isPending || !isConnected || !smartWallet || !amountIn || hasInsufficientBalance;

  return (
    <div className="w-full max-w-md mx-auto relative z-10">
      <div className="bg-surge-card/80 backdrop-blur-xl border border-surge-border/50 rounded-2xl p-5 space-y-4 shadow-xl shadow-black/20 hover-glow">
        <div className="flex items-center justify-between">
          <h2 className="text-lg font-semibold text-white">Bridge Tokens</h2>
          <span className="text-xs text-gray-400">L1 &rarr; L2</span>
        </div>

        {/* Token Amount */}
        <TokenInput
          token={USDC_TOKEN}
          amount={inputAmount}
          onAmountChange={setInputAmount}
          balance={usdcBalance}
          label="Amount"
        />

        {/* Flow Visualization */}
        {amountIn > 0n && (
          <div className="flex items-center justify-center gap-3 py-3">
            <div className="flex items-center gap-2 bg-surge-dark/50 px-3 py-2 rounded-lg">
              <span className="text-xs text-gray-400">L1</span>
              <span className="text-sm text-white font-medium">Lock</span>
            </div>
            <div className="text-surge-primary">&rarr;</div>
            <div className="flex items-center gap-2 bg-surge-dark/50 px-3 py-2 rounded-lg">
              <span className="text-xs text-gray-400">L2</span>
              <span className="text-sm text-white font-medium">Mint</span>
            </div>
          </div>
        )}

        {/* Recipient (optional) */}
        <div className="space-y-1">
          <label className="text-xs text-gray-400">Recipient on L2 (optional)</label>
          <input
            type="text"
            value={recipient}
            onChange={(e) => setRecipient(e.target.value)}
            placeholder={smartWallet ? `Default: ${smartWallet.slice(0, 10)}...` : '0x...'}
            className="w-full bg-surge-dark/50 border border-surge-border/30 rounded-lg px-3 py-2 text-sm text-white placeholder-gray-500 focus:outline-none focus:border-surge-primary/50"
          />
        </div>

        {/* Info */}
        {amountIn > 0n && (
          <div className="bg-surge-dark/30 rounded-lg p-3 space-y-1">
            <div className="flex justify-between text-sm">
              <span className="text-gray-400">You send</span>
              <span className="text-white">{formatEther(amountIn)} USDC</span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-gray-400">You receive</span>
              <span className="text-white">{formatEther(amountIn)} USDC on L2</span>
            </div>
          </div>
        )}

        {/* Bridge Button */}
        <button
          onClick={isConnected && !smartWallet ? onSetupWallet : handleBridge}
          disabled={isDisabled}
          className={`w-full py-4 rounded-xl font-semibold text-lg transition-all duration-200 ${
            isDisabled
              ? 'bg-surge-card/50 text-gray-500 cursor-not-allowed border border-surge-border/30'
              : 'bg-gradient-to-r from-surge-primary to-surge-secondary text-white hover:shadow-lg hover:shadow-surge-primary/30 hover:scale-[1.02] active:scale-[0.98]'
          }`}
        >
          {isPending ? (
            <span className="flex items-center justify-center gap-2">
              <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin" />
              Bridging...
            </span>
          ) : (
            getButtonText()
          )}
        </button>
      </div>
    </div>
  );
}
