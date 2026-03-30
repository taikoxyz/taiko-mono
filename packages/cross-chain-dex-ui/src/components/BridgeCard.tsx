import { useState, useCallback, useMemo } from "react";
import { parseUnits, formatUnits, Address } from "viem";
import { TokenInput } from "./TokenInput";
import { useSmartWallet } from "../hooks/useSmartWallet";
import { useTokenBalances } from "../hooks/useTokenBalances";
import { useL2TokenBalances } from "../hooks/useL2TokenBalances";
import { useUserOp } from "../hooks/useUserOp";
import { useSpendingLimit } from "../hooks/useSpendingLimit";
import { ETH_TOKEN, USDC_TOKEN, L1_NATIVE_SYMBOL } from "../lib/constants";
import { DisclaimerModal } from "./DisclaimerModal";
import { useDisclaimer } from "../hooks/useDisclaimer";
import { WarningBanner } from "./WarningBanner";
import { BridgeDirection } from "../types";

type BridgeToken = typeof L1_NATIVE_SYMBOL | "USDC";

interface BridgeCardProps {
  onSetupWallet: () => void;
}

export function BridgeCard({ onSetupWallet }: BridgeCardProps) {
  const { smartWallet, isConnected, l2WalletExists } = useSmartWallet();
  const { ethBalance, usdcBalance } = useTokenBalances(smartWallet);
  const { ethBalance: l2EthBalance, usdcBalance: l2UsdcBalance } = useL2TokenBalances(smartWallet);
  const { executeBridge, executeBridgeNative, executeBridgeOutNative, isPending } = useUserOp();
  const { hasExceededL2Limit, wouldExceed, recordSpending, remaining } = useSpendingLimit(smartWallet);
  const { isDisclaimerOpen, requireDisclaimer, onAccept, onCancel } = useDisclaimer();

  const [direction, setDirection] = useState<BridgeDirection>("L1_TO_L2");
  const [bridgeToken, setBridgeToken] = useState<BridgeToken>(L1_NATIVE_SYMBOL);
  const [inputAmount, setInputAmount] = useState("");
  const [recipient, setRecipient] = useState("");

  const isDeposit = direction === "L1_TO_L2";

  const currentToken =
    bridgeToken === L1_NATIVE_SYMBOL ? ETH_TOKEN : USDC_TOKEN;

  const amountIn = useMemo(() => {
    try {
      return inputAmount ? parseUnits(inputAmount, currentToken.decimals) : 0n;
    } catch {
      return 0n;
    }
  }, [inputAmount, currentToken.decimals]);

  // Use L1 balances for deposit, L2 balances for withdrawal
  const currentBalance = isDeposit
    ? (bridgeToken === L1_NATIVE_SYMBOL ? ethBalance : usdcBalance)
    : (bridgeToken === L1_NATIVE_SYMBOL ? l2EthBalance : l2UsdcBalance);

  const hasInsufficientBalance = amountIn > currentBalance;
  const bridgeAmountUsd = amountIn > 0n ? Number(formatUnits(amountIn, currentToken.decimals)) : 0;

  // Only apply spending limit checks for deposits
  const exceedsL2Limit = isDeposit && (hasExceededL2Limit || (bridgeAmountUsd > 0 && wouldExceed(bridgeAmountUsd)));

  // For withdrawals, default recipient to smartWallet (not EOA)
  const effectiveRecipient = (recipient || smartWallet || "") as Address;

  // USDC bridge-out is not supported yet
  const isWithdrawUSDC = !isDeposit && bridgeToken === "USDC";

  const handleBridge = useCallback(async () => {
    if (!smartWallet || amountIn === 0n) return;

    let success: boolean;

    if (!isDeposit) {
      // Bridge-out: L2 → L1 (native only)
      success = await executeBridgeOutNative({
        amount: amountIn,
        recipient: effectiveRecipient,
        smartWallet,
      });
    } else if (bridgeToken === L1_NATIVE_SYMBOL) {
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
      if (isDeposit) recordSpending(bridgeAmountUsd);
      setInputAmount("");
    }
  }, [
    smartWallet,
    amountIn,
    isDeposit,
    bridgeToken,
    bridgeAmountUsd,
    effectiveRecipient,
    executeBridge,
    executeBridgeNative,
    executeBridgeOutNative,
    recordSpending,
  ]);

  const getButtonText = () => {
    if (isPending) return "Bridging...";
    if (!isConnected) return "Connect Wallet";
    if (!smartWallet) return "Setup Smart Wallet First";
    if (!amountIn) return "Enter Amount";
    if (isWithdrawUSDC) return "USDC withdrawal not supported yet";
    if (isDeposit && hasExceededL2Limit) return "L2 deposit limit reached ($1)";
    if (isDeposit && exceedsL2Limit) return `Exceeds $1 limit ($${remaining.toFixed(2)} left)`;
    if (!isDeposit && !l2WalletExists) return "Create L2 wallet first";
    if (hasInsufficientBalance) return "Insufficient Balance";
    if (!isDeposit) return `Withdraw ${bridgeToken} to L1`;
    return `Bridge ${bridgeToken} to L2`;
  };

  const isDisabled =
    isPending ||
    !isConnected ||
    !smartWallet ||
    !amountIn ||
    hasInsufficientBalance ||
    exceedsL2Limit ||
    isWithdrawUSDC ||
    (!isDeposit && !l2WalletExists);

  return (
    <div className="flex flex-col md:flex-row items-start gap-4 justify-center w-full relative z-10">
      {/* Left panel — inputs */}
      <div className="w-full md:max-w-md bg-surge-card/80 border border-surge-border/50 rounded-2xl p-4 space-y-3 shadow-xl shadow-black/20 hover-glow transition-all duration-[1000ms] ease-[cubic-bezier(0.16,1,0.3,1)]">
        <div className="flex items-center justify-between">
          <h2 className="text-lg font-semibold text-white">Bridge</h2>
          <span className="text-xs text-gray-400">
            {isDeposit ? "L1 \u2192 L2" : "L2 \u2192 L1"}
          </span>
        </div>
        <WarningBanner />

        {/* Direction Toggle */}
        <div className="flex gap-2">
          <button
            onClick={() => {
              setDirection("L1_TO_L2");
              setInputAmount("");
            }}
            className={`flex-1 py-2 rounded-lg text-sm font-medium transition-colors ${
              isDeposit
                ? "bg-surge-primary text-white"
                : "bg-surge-dark/50 text-gray-400 hover:text-white border border-surge-border/30"
            }`}
          >
            Deposit L1&rarr;L2
          </button>
          <button
            onClick={() => {
              setDirection("L2_TO_L1");
              setInputAmount("");
            }}
            className={`flex-1 py-2 rounded-lg text-sm font-medium transition-colors ${
              !isDeposit
                ? "bg-surge-primary text-white"
                : "bg-surge-dark/50 text-gray-400 hover:text-white border border-surge-border/30"
            }`}
          >
            Withdraw L2&rarr;L1
          </button>
        </div>

        {/* Token Selector */}
        <div className="flex gap-2">
          {([L1_NATIVE_SYMBOL, "USDC"] as BridgeToken[]).map((t) => (
            <button
              key={t}
              onClick={() => {
                setBridgeToken(t);
                setInputAmount("");
              }}
              className={`flex-1 py-2 rounded-lg text-sm font-medium transition-colors ${
                bridgeToken === t
                  ? "bg-surge-primary text-white"
                  : "bg-surge-dark/50 text-gray-400 hover:text-white border border-surge-border/30"
              }`}
            >
              {t}
            </button>
          ))}
        </div>

        {/* USDC withdrawal not supported notice */}
        {isWithdrawUSDC && (
          <div className="bg-yellow-500/10 border border-yellow-500/30 rounded-lg px-3 py-2 text-xs text-yellow-400">
            USDC withdrawal (L2&rarr;L1) is not yet supported. Only native {L1_NATIVE_SYMBOL} withdrawals are available.
          </div>
        )}

        {/* Token Amount */}
        <TokenInput
          token={currentToken}
          amount={inputAmount}
          onAmountChange={setInputAmount}
          balance={currentBalance}
          label="Amount"
        />

        {/* Recipient (optional) */}
        <div className="space-y-1">
          <label className="text-xs text-gray-400">
            {isDeposit ? "Recipient on L2 (optional)" : "Recipient on L1 (optional)"}
          </label>
          <input
            type="text"
            value={recipient}
            onChange={(e) => setRecipient(e.target.value)}
            placeholder={
              smartWallet ? `Default: ${smartWallet.slice(0, 10)}...` : "0x..."
            }
            className="w-full bg-surge-dark/50 border border-surge-border/30 rounded-lg px-3 py-2 text-sm text-white placeholder-gray-500 focus:outline-none focus:border-surge-primary/50"
          />
        </div>

        {/* Bridge Button */}
        <button
          onClick={isConnected && !smartWallet ? onSetupWallet : () => requireDisclaimer(handleBridge)}
          disabled={isDisabled}
          className={`w-full py-3 rounded-xl font-semibold text-base transition-all duration-200 ${
            isDisabled
              ? "bg-surge-card/50 text-gray-500 cursor-not-allowed border border-surge-border/30"
              : "bg-gradient-to-r from-surge-primary to-surge-secondary text-white hover:shadow-lg hover:shadow-surge-primary/30 hover:scale-[1.02] active:scale-[0.98]"
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

      {/* Right panel — bridge details (shown when amount is entered) */}
      {amountIn > 0n && (
        <div className="w-full md:max-w-sm bg-surge-card/80 border border-surge-border/50 rounded-2xl p-4 space-y-3 shadow-xl shadow-black/20 animate-panel-in">
          <h3 className="text-xs font-semibold text-gray-400 uppercase tracking-widest">Bridge Details</h3>

          {/* Flow Visualization */}
          <div className="flex items-center justify-center gap-3 py-3">
            <div className="flex items-center gap-2 bg-surge-dark/50 px-3 py-2 rounded-lg">
              <span className="text-xs text-gray-400">{isDeposit ? "L1" : "L2"}</span>
              <span className="text-sm text-white font-medium">
                {isDeposit ? (bridgeToken === L1_NATIVE_SYMBOL ? "Send" : "Lock") : "Send"}
              </span>
            </div>
            <div className="text-surge-primary">&rarr;</div>
            <div className="flex items-center gap-2 bg-surge-dark/50 px-3 py-2 rounded-lg">
              <span className="text-xs text-gray-400">{isDeposit ? "L2" : "L1"}</span>
              <span className="text-sm text-white font-medium">
                {isDeposit ? (bridgeToken === L1_NATIVE_SYMBOL ? "Receive" : "Mint") : "Receive"}
              </span>
            </div>
          </div>

          {/* Transfer Summary */}
          <div className="bg-surge-dark/30 rounded-lg p-3 space-y-1">
            <div className="flex justify-between text-sm">
              <span className="text-gray-400">You send</span>
              <span className="text-white">
                {formatUnits(amountIn, currentToken.decimals)} {bridgeToken}
              </span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-gray-400">You receive</span>
              <span className="text-white">
                {formatUnits(amountIn, currentToken.decimals)} {bridgeToken} on {isDeposit ? "L2" : "L1"}
              </span>
            </div>
            <div className="flex justify-between text-sm mt-1 pt-1 border-t border-surge-border/30">
              <span className="text-gray-400">Recipient</span>
              <span className="text-white text-xs font-mono">
                {effectiveRecipient
                  ? `${effectiveRecipient.slice(0, 6)}...${effectiveRecipient.slice(-4)}`
                  : "—"}
              </span>
            </div>
          </div>
        </div>
      )}
      <DisclaimerModal isOpen={isDisclaimerOpen} onAccept={onAccept} onCancel={onCancel} />
    </div>
  );
}
