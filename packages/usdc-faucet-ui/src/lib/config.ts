import { type Address, isAddress, zeroAddress } from 'viem';

const PLACEHOLDER_PROJECT_ID = '00000000000000000000000000000000';
const publicEnv = import.meta.env as Record<string, string | undefined>;

function parseChainId(rawValue: string, fallbackValue: number): number {
  const parsedValue = Number(rawValue);
  return Number.isInteger(parsedValue) && parsedValue > 0 ? parsedValue : fallbackValue;
}

function parseUrl(rawValue: string): string | null {
  const trimmedValue = rawValue.trim();
  if (!trimmedValue) return null;

  try {
    return new URL(trimmedValue).toString().replace(/\/$/, '');
  } catch {
    return null;
  }
}

function parseAddress(rawValue: string): Address | null {
  const trimmedValue = rawValue.trim();
  if (!trimmedValue || !isAddress(trimmedValue) || trimmedValue === zeroAddress) {
    return null;
  }

  return trimmedValue as Address;
}

const chainId = parseChainId(publicEnv.PUBLIC_HOODI_CHAIN_ID ?? '', 560_048);
const chainName = publicEnv.PUBLIC_HOODI_CHAIN_NAME?.trim() || 'Ethereum Hoodi';
const rpcUrl = parseUrl(publicEnv.PUBLIC_HOODI_RPC_URL ?? '');
const explorerUrl = parseUrl(publicEnv.PUBLIC_HOODI_EXPLORER_URL ?? '');
const tokenAddress = parseAddress(publicEnv.PUBLIC_USDC_ADDRESS ?? '');
const faucetAddress = parseAddress(publicEnv.PUBLIC_USDC_FAUCET_ADDRESS ?? '');
const bridgeUrl = parseUrl(publicEnv.PUBLIC_HOODI_BRIDGE_URL ?? '');

const configurationIssues = [
  !rpcUrl ? 'PUBLIC_HOODI_RPC_URL' : null,
  !explorerUrl ? 'PUBLIC_HOODI_EXPLORER_URL' : null,
  !tokenAddress ? 'PUBLIC_USDC_ADDRESS' : null,
  !faucetAddress ? 'PUBLIC_USDC_FAUCET_ADDRESS' : null,
  !bridgeUrl ? 'PUBLIC_HOODI_BRIDGE_URL' : null,
].filter((issue): issue is string => issue !== null);

const configurationWarnings = [
  !(publicEnv.PUBLIC_WALLETCONNECT_PROJECT_ID ?? '').trim() ? 'PUBLIC_WALLETCONNECT_PROJECT_ID' : null,
].filter((warning): warning is string => warning !== null);

export const appConfig = {
  bridgeUrl,
  chainId,
  chainName,
  explorerUrl,
  faucetAddress,
  isConfigured: configurationIssues.length === 0,
  rpcUrl,
  tokenAddress,
  walletConnectProjectId: (publicEnv.PUBLIC_WALLETCONNECT_PROJECT_ID ?? '').trim() || PLACEHOLDER_PROJECT_ID,
};

export const configIssues = configurationIssues;
export const configWarnings = configurationWarnings;
