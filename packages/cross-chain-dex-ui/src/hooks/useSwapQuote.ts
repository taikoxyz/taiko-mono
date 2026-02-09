import { useMemo } from 'react';
import { SwapQuote, SwapDirection } from '../types';
import { calculateAmountOut } from '../lib/userOp';
import { FEE_PERCENT } from '../lib/constants';

interface UseSwapQuoteParams {
  direction: SwapDirection;
  amountIn: bigint;
  ethReserve: bigint;
  tokenReserve: bigint;
}

export function useSwapQuote({
  direction,
  amountIn,
  ethReserve,
  tokenReserve,
}: UseSwapQuoteParams): SwapQuote {
  return useMemo(() => {
    if (amountIn === 0n || ethReserve === 0n || tokenReserve === 0n) {
      return {
        amountOut: 0n,
        priceImpact: 0,
        fee: 0n,
        rate: 0,
      };
    }

    const reserveIn = direction === 'ETH_TO_USDC' ? ethReserve : tokenReserve;
    const reserveOut = direction === 'ETH_TO_USDC' ? tokenReserve : ethReserve;

    const amountOut = calculateAmountOut(amountIn, reserveIn, reserveOut);

    // Calculate fee (0.3% of input)
    const fee = (amountIn * 3n) / 1000n;

    // Calculate price impact
    // Price impact = (idealOutput - actualOutput) / idealOutput * 100
    const idealOutput = (amountIn * reserveOut) / reserveIn;
    const priceImpact =
      idealOutput > 0n
        ? Number(((idealOutput - amountOut) * 10000n) / idealOutput) / 100
        : 0;

    // Calculate rate (output per input)
    const rate = amountIn > 0n ? Number(amountOut) / Number(amountIn) : 0;

    return {
      amountOut,
      priceImpact,
      fee,
      rate,
    };
  }, [direction, amountIn, ethReserve, tokenReserve]);
}

export { FEE_PERCENT };
