import { formatCountdown } from '$lib/format';

export type FaucetPrimaryAction = 'claim' | 'connect' | 'none' | 'switch';

export interface FaucetViewStateInput {
  claimAmountLabel: string;
  cooldownUntilMs: number | null;
  isClaiming: boolean;
  isConfigured: boolean;
  isConnected: boolean;
  isCorrectChain: boolean;
  isRefreshing: boolean;
  lastClaimHash: string | null;
  nowMs: number;
}

export interface FaucetViewState {
  cooldownActive: boolean;
  cooldownRemainingMs: number;
  detail: string;
  primaryAction: FaucetPrimaryAction;
  primaryDisabled: boolean;
  primaryLabel: string;
  showBridgeCta: boolean;
}

export function deriveFaucetViewState(input: FaucetViewStateInput): FaucetViewState {
  const cooldownRemainingMs =
    input.cooldownUntilMs && input.cooldownUntilMs > input.nowMs ? input.cooldownUntilMs - input.nowMs : 0;
  const cooldownActive = cooldownRemainingMs > 0;

  if (!input.isConfigured) {
    return {
      cooldownActive,
      cooldownRemainingMs,
      detail: 'This deployment is missing one or more required public environment variables.',
      primaryAction: 'none',
      primaryDisabled: true,
      primaryLabel: 'Configuration required',
      showBridgeCta: false,
    };
  }

  if (!input.isConnected) {
    return {
      cooldownActive,
      cooldownRemainingMs,
      detail: 'Connect a wallet on Ethereum Hoodi to read your cooldown and submit a claim.',
      primaryAction: 'connect',
      primaryDisabled: false,
      primaryLabel: 'Connect wallet',
      showBridgeCta: false,
    };
  }

  if (!input.isCorrectChain) {
    return {
      cooldownActive,
      cooldownRemainingMs,
      detail: 'This faucet only works on Ethereum Hoodi. Switch networks before claiming.',
      primaryAction: 'switch',
      primaryDisabled: false,
      primaryLabel: 'Switch to Ethereum Hoodi',
      showBridgeCta: false,
    };
  }

  if (input.isClaiming) {
    return {
      cooldownActive,
      cooldownRemainingMs,
      detail: 'The claim transaction has been submitted. Wait for confirmation before trying again.',
      primaryAction: 'none',
      primaryDisabled: true,
      primaryLabel: 'Claiming...',
      showBridgeCta: false,
    };
  }

  if (input.isRefreshing && !input.claimAmountLabel) {
    return {
      cooldownActive,
      cooldownRemainingMs,
      detail: 'Refreshing faucet status from Ethereum Hoodi.',
      primaryAction: 'none',
      primaryDisabled: true,
      primaryLabel: 'Loading faucet...',
      showBridgeCta: false,
    };
  }

  if (cooldownActive) {
    return {
      cooldownActive,
      cooldownRemainingMs,
      detail: `Your next claim window opens in ${formatCountdown(cooldownRemainingMs)}.`,
      primaryAction: 'claim',
      primaryDisabled: true,
      primaryLabel: `Available in ${formatCountdown(cooldownRemainingMs)}`,
      showBridgeCta: Boolean(input.lastClaimHash),
    };
  }

  return {
    cooldownActive: false,
    cooldownRemainingMs: 0,
    detail: 'Claim on Ethereum Hoodi, then use the bridge CTA below to move USDC onto Taiko Hoodi.',
    primaryAction: 'claim',
    primaryDisabled: false,
    primaryLabel: `Claim ${input.claimAmountLabel || 'USDC'}`,
    showBridgeCta: false,
  };
}
