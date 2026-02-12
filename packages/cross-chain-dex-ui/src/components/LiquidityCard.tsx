import { useState, useCallback, useMemo } from 'react';
import { parseEther, formatEther } from 'viem';
import { TokenInput } from './TokenInput';
import { useSmartWallet } from '../hooks/useSmartWallet';
import { useDexReserves } from '../hooks/useDexReserves';
import { useTokenBalances } from '../hooks/useTokenBalances';
import { useUserOp } from '../hooks/useUserOp';
import { ETH_TOKEN, USDC_TOKEN } from '../lib/constants';

interface LiquidityCardProps {
  onSetupWallet: () => void;
}

export function LiquidityCard({ onSetupWallet }: LiquidityCardProps) {
  const { smartWallet, isConnected } = useSmartWallet();
  const { ethReserve, tokenReserve } = useDexReserves();
  const { ethBalance, usdcBalance } = useTokenBalances(smartWallet);
  const { executeAddLiquidity, isPending } = useUserOp();

  const [ethInput, setEthInput] = useState('');
  const [tokenInput, setTokenInput] = useState('');
  const [priceInput, setPriceInput] = useState('1000'); // USDC per ETH

  const hasReserves = ethReserve > 0n && tokenReserve > 0n;
  const price = hasReserves
    ? Number(formatEther(tokenReserve)) / Number(formatEther(ethReserve))
    : Number(priceInput) || 0;

  // When user edits ETH, auto-fill token amount based on pool ratio or user-set price
  const handleEthChange = useCallback((value: string) => {
    setEthInput(value);
    if (price > 0 && value) {
      try {
        const ethVal = Number(value);
        if (ethVal > 0) {
          setTokenInput(String(ethVal * price));
        } else {
          setTokenInput('');
        }
      } catch {
        // invalid input
      }
    } else if (!value) {
      setTokenInput('');
    }
  }, [price]);

  // When user edits token, auto-fill ETH amount based on pool ratio or user-set price
  const handleTokenChange = useCallback((value: string) => {
    setTokenInput(value);
    if (price > 0 && value) {
      try {
        const tokenVal = Number(value);
        if (tokenVal > 0) {
          setEthInput(String(tokenVal / price));
        } else {
          setEthInput('');
        }
      } catch {
        // invalid input
      }
    } else if (!value) {
      setEthInput('');
    }
  }, [price]);

  // When price changes on a fresh pool, recalculate token from current ETH input
  const handlePriceChange = useCallback((value: string) => {
    setPriceInput(value);
    const p = Number(value);
    if (p > 0 && ethInput) {
      const ethVal = Number(ethInput);
      if (ethVal > 0) {
        setTokenInput(String(ethVal * p));
      }
    }
  }, [ethInput]);

  const ethAmount = useMemo(() => {
    try {
      return ethInput ? parseEther(ethInput) : 0n;
    } catch {
      return 0n;
    }
  }, [ethInput]);

  const tokenAmount = useMemo(() => {
    try {
      return tokenInput ? parseEther(tokenInput) : 0n;
    } catch {
      return 0n;
    }
  }, [tokenInput]);

  const hasInsufficientETH = ethAmount > ethBalance;
  const hasInsufficientTokens = tokenAmount > usdcBalance;

  const handleAddLiquidity = useCallback(async () => {
    if (!smartWallet || ethAmount === 0n || tokenAmount === 0n) return;

    const success = await executeAddLiquidity({
      ethAmount,
      tokenAmount,
      smartWallet,
    });

    if (success) {
      setEthInput('');
      setTokenInput('');
    }
  }, [smartWallet, ethAmount, tokenAmount, executeAddLiquidity]);

  const getButtonText = () => {
    if (isPending) return 'Adding Liquidity...';
    if (!isConnected) return 'Connect Wallet';
    if (!smartWallet) return 'Setup Smart Wallet First';
    if (!ethAmount || !tokenAmount) return 'Enter Amounts';
    if (hasInsufficientETH) return 'Insufficient ETH';
    if (hasInsufficientTokens) return 'Insufficient USDC Tokens';
    return 'Add Liquidity to L2';
  };

  const isDisabled = isPending || !isConnected || !smartWallet || !ethAmount || !tokenAmount || hasInsufficientETH || hasInsufficientTokens;

  return (
    <div className="w-full max-w-md mx-auto relative z-10">
      <div className="bg-surge-card/80 backdrop-blur-xl border border-surge-border/50 rounded-2xl p-5 space-y-4 shadow-xl shadow-black/20 hover-glow">
        <div className="flex items-center justify-between">
          <h2 className="text-lg font-semibold text-white">Add Liquidity</h2>
          <span className="text-xs text-gray-400">L1 &rarr; L2 DEX</span>
        </div>

        {/* ETH Input */}
        <TokenInput
          token={ETH_TOKEN}
          amount={ethInput}
          onAmountChange={handleEthChange}
          balance={ethBalance}
          label="ETH Amount"
        />

        <div className="flex justify-center">
          <div className="text-gray-400 text-lg">+</div>
        </div>

        {/* Token Input */}
        <TokenInput
          token={USDC_TOKEN}
          amount={tokenInput}
          onAmountChange={handleTokenChange}
          balance={usdcBalance}
          label="Token Amount"
        />

        {/* Set initial price when pool is empty */}
        {!hasReserves && (
          <div className="bg-yellow-500/10 border border-yellow-500/30 rounded-lg p-3 space-y-2">
            <div className="text-xs text-yellow-400 font-medium">Pool is empty — set the initial price</div>
            <div className="flex items-center gap-2">
              <span className="text-sm text-gray-400 whitespace-nowrap">1 ETH =</span>
              <input
                type="number"
                value={priceInput}
                onChange={(e) => handlePriceChange(e.target.value)}
                className="flex-1 bg-surge-dark/50 border border-surge-border/50 rounded-lg px-3 py-1.5 text-white text-sm outline-none focus:border-surge-primary/50"
                placeholder="1000"
                min="0"
              />
              <span className="text-sm text-gray-400">USDC</span>
            </div>
          </div>
        )}

        {/* Current Pool Info */}
        <div className="bg-surge-dark/30 rounded-lg p-3 space-y-1">
          <div className="text-xs text-gray-400 font-medium mb-2">L2 DEX Pool</div>
          <div className="flex justify-between text-sm">
            <span className="text-gray-400">ETH Reserve</span>
            <span className="text-white">{formatEther(ethReserve)} ETH</span>
          </div>
          <div className="flex justify-between text-sm">
            <span className="text-gray-400">Token Reserve</span>
            <span className="text-white">{formatEther(tokenReserve)} USDC</span>
          </div>
          {price > 0 && (
            <div className="flex justify-between text-sm">
              <span className="text-gray-400">Price</span>
              <span className="text-white">
                1 ETH = {price.toFixed(2)} USDC
              </span>
            </div>
          )}
        </div>

        {/* Flow Info */}
        {ethAmount > 0n && tokenAmount > 0n && (
          <div className="bg-surge-dark/30 rounded-lg p-3 space-y-1">
            <div className="flex justify-between text-sm">
              <span className="text-gray-400">Operation</span>
              <span className="text-white">Lock on L1 &rarr; Add to L2 DEX</span>
            </div>
          </div>
        )}

        {/* Add Liquidity Button */}
        <button
          onClick={isConnected && !smartWallet ? onSetupWallet : handleAddLiquidity}
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
              Adding Liquidity...
            </span>
          ) : (
            getButtonText()
          )}
        </button>
      </div>
    </div>
  );
}
