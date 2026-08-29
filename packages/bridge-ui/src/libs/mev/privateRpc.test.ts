import { getPrivateRpc } from './privateRpc';

describe('getPrivateRpc', () => {
  it('uses the maximum privacy hint on mainnet so searchers never see the claim calldata', () => {
    expect(getPrivateRpc(1)?.url).toBe('https://rpc.flashbots.net?hint=hash');
  });

  it('covers sepolia so the flow can be exercised on a testnet', () => {
    expect(getPrivateRpc(11155111)?.name).toBe('Flashbots Protect');
  });

  it('returns undefined for chains without a private relay', () => {
    // Taiko Alethia: no private relay market exists for it, claims stay on the wallet's endpoint.
    expect(getPrivateRpc(167000)).toBeUndefined();
  });
});
