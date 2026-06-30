export const MANUAL_CLAIM_ROUTE = '/transactions';

type ManualClaimHrefArgs = {
  enoughEth: boolean;
  selected: boolean;
};

export function getManualClaimHref({ enoughEth, selected }: ManualClaimHrefArgs): string | null {
  if (!selected || !enoughEth) {
    return null;
  }

  return MANUAL_CLAIM_ROUTE;
}
