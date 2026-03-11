import { type Address, formatUnits, type Hex } from 'viem';

export function shortAddress(value: Address | null | undefined): string {
  if (!value) return 'Connect wallet';
  return `${value.slice(0, 6)}...${value.slice(-4)}`;
}

export function formatTokenAmount(value: bigint | null, decimals: number, maximumFractionDigits = 2): string {
  if (value === null) return '--';

  const numericValue = Number(formatUnits(value, decimals));
  if (!Number.isFinite(numericValue)) {
    return formatUnits(value, decimals);
  }

  return new Intl.NumberFormat(undefined, {
    maximumFractionDigits,
  }).format(numericValue);
}

export function formatCountdown(milliseconds: number): string {
  if (milliseconds <= 0) return 'now';

  const totalSeconds = Math.ceil(milliseconds / 1000);
  const days = Math.floor(totalSeconds / 86_400);
  const hours = Math.floor((totalSeconds % 86_400) / 3_600);
  const minutes = Math.floor((totalSeconds % 3_600) / 60);
  const seconds = totalSeconds % 60;

  if (days > 0) return `${days}d ${hours}h`;
  if (hours > 0) return `${hours}h ${minutes}m`;
  if (minutes > 0) return `${minutes}m ${seconds}s`;
  return `${seconds}s`;
}

export function formatDateTime(milliseconds: number | null): string {
  if (!milliseconds) return 'Ready now';

  return new Intl.DateTimeFormat(undefined, {
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  }).format(milliseconds);
}

export function explorerUrl(
  baseUrl: string | null,
  kind: 'address' | 'tx',
  value: Address | Hex | undefined,
): string | null {
  if (!baseUrl || !value) return null;
  return `${baseUrl}/${kind}/${value}`;
}

export function normalizeError(error: unknown): string {
  if (typeof error === 'object' && error !== null) {
    const candidate = error as {
      shortMessage?: string;
      details?: string;
      message?: string;
      cause?: { shortMessage?: string; message?: string };
    };

    return (
      candidate.shortMessage ||
      candidate.cause?.shortMessage ||
      candidate.details ||
      candidate.message ||
      candidate.cause?.message ||
      'The request did not complete.'
    );
  }

  return 'The request did not complete.';
}
