interface SwapButtonProps {
  onClick: () => void;
  disabled: boolean;
  isLoading: boolean;
  isConnected: boolean;
  hasSmartWallet: boolean;
  hasInsufficientBalance: boolean;
  hasAmount: boolean;
}

export function SwapButton({
  onClick,
  disabled,
  isLoading,
  isConnected,
  hasSmartWallet,
  hasInsufficientBalance,
  hasAmount,
}: SwapButtonProps) {
  const getButtonText = () => {
    if (isLoading) return 'Swapping...';
    if (!isConnected) return 'Connect Wallet';
    if (!hasSmartWallet) return 'Setup Smart Wallet First';
    if (!hasAmount) return 'Enter Amount';
    if (hasInsufficientBalance) return 'Insufficient Balance';
    return 'Swap';
  };

  const isDisabled = disabled || isLoading || !isConnected || !hasSmartWallet || !hasAmount || hasInsufficientBalance;

  return (
    <button
      onClick={onClick}
      disabled={isDisabled}
      className={`w-full py-4 rounded-xl font-semibold text-lg transition-all duration-200 ${
        isDisabled
          ? 'bg-surge-card/50 text-gray-500 cursor-not-allowed border border-surge-border/30'
          : 'bg-gradient-to-r from-surge-primary to-surge-secondary text-white hover:shadow-lg hover:shadow-surge-primary/30 hover:scale-[1.02] active:scale-[0.98]'
      }`}
    >
      {isLoading ? (
        <span className="flex items-center justify-center gap-2">
          <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin" />
          Swapping...
        </span>
      ) : (
        getButtonText()
      )}
    </button>
  );
}
