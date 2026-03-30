import { Token } from '../types';
import { formatUnits } from 'viem';

interface TokenInputProps {
  token: Token;
  amount: string;
  onAmountChange: (value: string) => void;
  balance: bigint;
  label: string;
  disabled?: boolean;
  showMax?: boolean;
}

export function TokenInput({
  token,
  amount,
  onAmountChange,
  balance,
  label,
  disabled = false,
  showMax = true,
}: TokenInputProps) {
  const handleMaxClick = () => {
    onAmountChange(formatUnits(balance, token.decimals));
  };

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value;
    // Allow empty string, numbers, and one decimal point
    if (value === '' || /^\d*\.?\d*$/.test(value)) {
      onAmountChange(value);
    }
  };

  return (
    <div className="bg-surge-dark/50 rounded-xl p-3 border border-surge-border/20">
      <div className="flex justify-between items-center mb-2">
        <span className="text-sm text-gray-400">{label}</span>
        <div className="flex items-center gap-2">
          <span className="text-sm text-gray-400">
            Balance: {Number(formatUnits(balance, token.decimals)).toFixed(4)}
          </span>
          {showMax && !disabled && balance > 0n && (
            <button
              onClick={handleMaxClick}
              className="text-xs text-surge-primary hover:text-surge-secondary font-medium px-2 py-0.5 bg-surge-primary/10 rounded hover:bg-surge-primary/20 transition-colors"
            >
              MAX
            </button>
          )}
        </div>
      </div>

      <div className="flex items-center gap-3">
        {/* Token selector - fixed width */}
        <div className="flex items-center gap-2 bg-surge-card/80 px-3 py-2 rounded-lg shrink-0">
          <img src={token.logo} alt={token.symbol} className="w-6 h-6" />
          <span className="text-white font-medium">{token.symbol}</span>
        </div>

        {/* Input - takes remaining space */}
        <input
          type="text"
          value={amount}
          onChange={handleChange}
          disabled={disabled}
          placeholder="0.0"
          className="flex-1 min-w-0 bg-transparent text-2xl text-white text-right outline-none placeholder-gray-600 disabled:opacity-50"
        />
      </div>
    </div>
  );
}
