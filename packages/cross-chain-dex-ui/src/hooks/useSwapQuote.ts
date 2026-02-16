import { useMemo } from 'react';
import { SwapQuote, SwapDirection } from '../types';
import { calculateAmountOut } from '../lib/userOp';
import { FEE_PERCENT, ETH_TOKEN, USDC_TOKEN } from '../lib/constants';

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
    const noLiquidity = ethReserve === 0n || tokenReserve === 0n;

    if (amountIn === 0n || noLiquidity) {
      return {
        amountOut: 0n,
        priceImpact: 0,
        fee: 0n,
        rate: 0,
        insufficientLiquidity: noLiquidity && amountIn > 0n,
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

    // Calculate human-readable rate (output per input), normalizing for decimal differences
    const inputDecimals = direction === 'ETH_TO_USDC' ? ETH_TOKEN.decimals : USDC_TOKEN.decimals;
    const outputDecimals = direction === 'ETH_TO_USDC' ? USDC_TOKEN.decimals : ETH_TOKEN.decimals;
    const rate = amountIn > 0n
      ? (Number(amountOut) / Number(amountIn)) * (10 ** (inputDecimals - outputDecimals))
      : 0;

    // Flag as insufficient liquidity if output would drain >95% of the reserve
    const insufficientLiquidity = amountOut > (reserveOut * 95n) / 100n;

    return {
      amountOut,
      priceImpact,
      fee,
      rate,
      insufficientLiquidity,
    };
  }, [direction, amountIn, ethReserve, tokenReserve]);
}

export { FEE_PERCENT };
