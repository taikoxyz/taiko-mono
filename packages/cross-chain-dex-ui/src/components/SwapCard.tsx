import { useState, useCallback, useMemo } from 'react';
import { parseEther, formatEther } from 'viem';
import { TokenInput } from './TokenInput';
import { SwapDetails } from './SwapDetails';
import { SwapPath } from './SwapPath';
import { SwapButton } from './SwapButton';
import { useSmartWallet } from '../hooks/useSmartWallet';
import { useDexReserves } from '../hooks/useDexReserves';
import { useSwapQuote } from '../hooks/useSwapQuote';
import { useTokenBalances } from '../hooks/useTokenBalances';
import { useUserOp } from '../hooks/useUserOp';
import { SwapDirection } from '../types';
import { ETH_TOKEN, USDC_TOKEN } from '../lib/constants';

interface SwapCardProps {
  onSetupWallet: () => void;
  onFundWallet?: () => void;
}

export function SwapCard({ onSetupWallet, onFundWallet }: SwapCardProps) {
  const { smartWallet, isConnected } = useSmartWallet();
  const { ethReserve, tokenReserve, isLoading: reservesLoading } = useDexReserves();
  const { ethBalance, usdcBalance } = useTokenBalances(smartWallet);
  const { executeSwap, isPending } = useUserOp();

  const [direction, setDirection] = useState<SwapDirection>('ETH_TO_USDC');
  const [inputAmount, setInputAmount] = useState('');

  const amountIn = useMemo(() => {
    try {
      return inputAmount ? parseEther(inputAmount) : 0n;
    } catch {
      return 0n;
    }
  }, [inputAmount]);

  const quote = useSwapQuote({
    direction,
    amountIn,
    ethReserve,
    tokenReserve,
  });

  const inputToken = direction === 'ETH_TO_USDC' ? ETH_TOKEN : USDC_TOKEN;
  const outputToken = direction === 'ETH_TO_USDC' ? USDC_TOKEN : ETH_TOKEN;
  const inputBalance = direction === 'ETH_TO_USDC' ? ethBalance : usdcBalance;
  const outputBalance = direction === 'ETH_TO_USDC' ? usdcBalance : ethBalance;

  const hasInsufficientBalance = amountIn > inputBalance;

  const handleSwapDirection = useCallback(() => {
    setDirection((prev) => (prev === 'ETH_TO_USDC' ? 'USDC_TO_ETH' : 'ETH_TO_USDC'));
    setInputAmount('');
  }, []);

  const handleSwap = useCallback(async () => {
    if (!smartWallet || amountIn === 0n) return;

    const success = await executeSwap({
      direction,
      amountIn,
      expectedAmountOut: quote.amountOut,
      smartWallet,
    });

    if (success) {
      setInputAmount('');
    }
  }, [smartWallet, amountIn, direction, quote.amountOut, executeSwap]);

  return (
    <div className="w-full max-w-md mx-auto relative z-10">
      <div className="bg-surge-card/80 backdrop-blur-xl border border-surge-border/50 rounded-2xl p-5 space-y-4 shadow-xl shadow-black/20 hover-glow">
        {/* Header */}
        <div className="flex items-center justify-between">
          <h2 className="text-lg font-semibold text-white">Swap</h2>
          {reservesLoading && (
            <span className="text-xs text-gray-400">Loading reserves...</span>
          )}
        </div>

        {/* Input Token */}
        <TokenInput
          token={inputToken}
          amount={inputAmount}
          onAmountChange={setInputAmount}
          balance={inputBalance}
          label="From"
        />

        {/* Swap Direction Button */}
        <div className="flex justify-center -my-2 relative z-10">
          <button
            onClick={handleSwapDirection}
            className="p-2 bg-surge-card border border-surge-border rounded-lg hover:bg-surge-dark transition-colors"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              className="h-5 w-5 text-gray-400"
              viewBox="0 0 20 20"
              fill="currentColor"
            >
              <path
                fillRule="evenodd"
                d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z"
                clipRule="evenodd"
              />
              <path
                fillRule="evenodd"
                d="M14.707 12.707a1 1 0 01-1.414 0L10 9.414l-3.293 3.293a1 1 0 01-1.414-1.414l4-4a1 1 0 011.414 0l4 4a1 1 0 010 1.414z"
                clipRule="evenodd"
              />
            </svg>
          </button>
        </div>

        {/* Output Token */}
        <TokenInput
          token={outputToken}
          amount={quote.amountOut > 0n ? formatEther(quote.amountOut) : ''}
          onAmountChange={() => {}}
          balance={outputBalance}
          label="To"
          disabled
          showMax={false}
        />

        {/* Swap Details */}
        <SwapDetails quote={quote} direction={direction} amountIn={amountIn} />

        {/* Swap Path Visualization */}
        <SwapPath direction={direction} show={amountIn > 0n} />

        {/* Swap Button */}
        <SwapButton
          onClick={isConnected && !smartWallet ? onSetupWallet : handleSwap}
          disabled={false}
          isLoading={isPending}
          isConnected={isConnected}
          hasSmartWallet={!!smartWallet}
          hasInsufficientBalance={hasInsufficientBalance}
          hasAmount={amountIn > 0n}
        />

        {/* Smart Wallet Info */}
        {isConnected && smartWallet && (
          <div className="text-center">
            <p className="text-xs text-gray-500">
              Swapping via Smart Wallet: {smartWallet.slice(0, 8)}...{smartWallet.slice(-6)}
            </p>
          </div>
        )}
      </div>
    </div>
  );
}
