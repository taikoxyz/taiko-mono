import { SwapQuote, SwapDirection } from '../types';
import { formatEther } from 'viem';
import { FEE_PERCENT } from '../lib/constants';

interface SwapDetailsProps {
  quote: SwapQuote;
  direction: SwapDirection;
  amountIn: bigint;
}

export function SwapDetails({ quote, direction, amountIn }: SwapDetailsProps) {
  if (amountIn === 0n) return null;

  const inputSymbol = direction === 'ETH_TO_USDC' ? 'ETH' : 'USDC';
  const outputSymbol = direction === 'ETH_TO_USDC' ? 'USDC' : 'ETH';

  return (
    <div className="bg-surge-dark rounded-xl p-4 space-y-3">
      <div className="flex justify-between items-center text-sm">
        <span className="text-gray-400">Rate</span>
        <span className="text-white">
          1 {inputSymbol} = {quote.rate.toFixed(6)} {outputSymbol}
        </span>
      </div>

      <div className="flex justify-between items-center text-sm">
        <span className="text-gray-400">Fee ({FEE_PERCENT}%)</span>
        <span className="text-white">
          {Number(formatEther(quote.fee)).toFixed(6)} {inputSymbol}
        </span>
      </div>

      <div className="flex justify-between items-center text-sm">
        <span className="text-gray-400">Price Impact</span>
        <span
          className={`${
            quote.priceImpact > 5
              ? 'text-red-500'
              : quote.priceImpact > 1
              ? 'text-yellow-500'
              : 'text-green-500'
          }`}
        >
          {quote.priceImpact.toFixed(2)}%
        </span>
      </div>

      <div className="flex justify-between items-center text-sm">
        <span className="text-gray-400">Expected Output</span>
        <span className="text-white font-medium">
          {Number(formatEther(quote.amountOut)).toFixed(6)} {outputSymbol}
        </span>
      </div>
    </div>
  );
}
