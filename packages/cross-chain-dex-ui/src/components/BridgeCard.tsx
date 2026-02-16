import { useState, useCallback, useMemo } from 'react';
import { parseUnits, formatUnits, Address } from 'viem';
import { TokenInput } from './TokenInput';
import { useSmartWallet } from '../hooks/useSmartWallet';
import { useTokenBalances } from '../hooks/useTokenBalances';
import { useUserOp } from '../hooks/useUserOp';
import { ETH_TOKEN, USDC_TOKEN } from '../lib/constants';

type BridgeToken = 'xDAI' | 'USDC';

interface BridgeCardProps {
  onSetupWallet: () => void;
}

export function BridgeCard({ onSetupWallet }: BridgeCardProps) {
  const { smartWallet, isConnected } = useSmartWallet();
  const { ethBalance, usdcBalance } = useTokenBalances(smartWallet);
  const { executeBridge, executeBridgeNative, isPending } = useUserOp();

  const [bridgeToken, setBridgeToken] = useState<BridgeToken>('USDC');
  const [inputAmount, setInputAmount] = useState('');
  const [recipient, setRecipient] = useState('');

  const currentToken = bridgeToken === 'xDAI' ? ETH_TOKEN : USDC_TOKEN;

  const amountIn = useMemo(() => {
    try {
      return inputAmount ? parseUnits(inputAmount, currentToken.decimals) : 0n;
    } catch {
      return 0n;
    }
  }, [inputAmount, currentToken.decimals]);
  const currentBalance = bridgeToken === 'xDAI' ? ethBalance : usdcBalance;
  const hasInsufficientBalance = amountIn > currentBalance;

  const effectiveRecipient = (recipient || smartWallet || '') as Address;

  const handleBridge = useCallback(async () => {
    if (!smartWallet || amountIn === 0n) return;

    let success: boolean;
    if (bridgeToken === 'xDAI') {
      success = await executeBridgeNative({
        amount: amountIn,
        recipient: effectiveRecipient,
        smartWallet,
      });
    } else {
      success = await executeBridge({
        amount: amountIn,
        recipient: effectiveRecipient,
        smartWallet,
      });
    }

    if (success) {
      setInputAmount('');
    }
  }, [smartWallet, amountIn, bridgeToken, effectiveRecipient, executeBridge, executeBridgeNative]);

  const getButtonText = () => {
    if (isPending) return 'Bridging...';
    if (!isConnected) return 'Connect Wallet';
    if (!smartWallet) return 'Setup Smart Wallet First';
    if (!amountIn) return 'Enter Amount';
    if (hasInsufficientBalance) return 'Insufficient Balance';
    return `Bridge ${bridgeToken} to L2`;
  };

  const isDisabled = isPending || !isConnected || !smartWallet || !amountIn || hasInsufficientBalance;

  return (
    <div className="w-full max-w-md mx-auto relative z-10">
      <div className="bg-surge-card/80 backdrop-blur-xl border border-surge-border/50 rounded-2xl p-5 space-y-4 shadow-xl shadow-black/20 hover-glow">
        <div className="flex items-center justify-between">
          <h2 className="text-lg font-semibold text-white">Bridge</h2>
          <span className="text-xs text-gray-400">L1 &rarr; L2</span>
        </div>

        {/* Token Selector */}
        <div className="flex gap-2">
          {(['xDAI', 'USDC'] as BridgeToken[]).map((t) => (
            <button
              key={t}
              onClick={() => { setBridgeToken(t); setInputAmount(''); }}
              className={`flex-1 py-2 rounded-lg text-sm font-medium transition-colors ${
                bridgeToken === t
                  ? 'bg-surge-primary text-white'
                  : 'bg-surge-dark/50 text-gray-400 hover:text-white border border-surge-border/30'
              }`}
            >
              {t}
            </button>
          ))}
        </div>

        {/* Token Amount */}
        <TokenInput
          token={currentToken}
          amount={inputAmount}
          onAmountChange={setInputAmount}
          balance={currentBalance}
          label="Amount"
        />

        {/* Flow Visualization */}
        {amountIn > 0n && (
          <div className="flex items-center justify-center gap-3 py-3">
            <div className="flex items-center gap-2 bg-surge-dark/50 px-3 py-2 rounded-lg">
              <span className="text-xs text-gray-400">L1</span>
              <span className="text-sm text-white font-medium">
                {bridgeToken === 'xDAI' ? 'Send' : 'Lock'}
              </span>
            </div>
            <div className="text-surge-primary">&rarr;</div>
            <div className="flex items-center gap-2 bg-surge-dark/50 px-3 py-2 rounded-lg">
              <span className="text-xs text-gray-400">L2</span>
              <span className="text-sm text-white font-medium">
                {bridgeToken === 'xDAI' ? 'Receive' : 'Mint'}
              </span>
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
              <span className="text-white">{formatUnits(amountIn, currentToken.decimals)} {bridgeToken}</span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-gray-400">You receive</span>
              <span className="text-white">{formatUnits(amountIn, currentToken.decimals)} {bridgeToken} on L2</span>
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
