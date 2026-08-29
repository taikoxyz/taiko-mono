import { UnsupportedPrivateRpcError } from '$libs/error';
import { getConnectedWallet } from '$libs/util/getConnectedWallet';

import { enablePrivateRpc } from './enablePrivateRpc';
import { hasEnabledPrivateRpc } from './privateRpcPreference';

const mainnet = {
  id: 1,
  name: 'Ethereum',
  nativeCurrency: { name: 'Ether', symbol: 'ETH', decimals: 18 },
  rpcUrls: { default: { http: ['https://a-public-node.example'] } },
};

vi.mock('$libs/chain', () => ({ chains: [], chainIdToChain: () => mainnet }));
vi.mock('$libs/wagmi', () => ({ config: {} }));
vi.mock('$libs/util/getConnectedWallet');

const addChain = vi.fn();

describe('enablePrivateRpc', () => {
  beforeEach(() => {
    localStorage.clear();
    addChain.mockReset();
    vi.mocked(getConnectedWallet).mockResolvedValue({ addChain } as never);
  });

  it('asks the wallet to point the chain at the private relay instead of a public node', async () => {
    await enablePrivateRpc(1);

    expect(addChain).toHaveBeenCalledWith({
      chain: { ...mainnet, rpcUrls: { default: { http: ['https://rpc.flashbots.net?hint=hash'] } } },
    });
  });

  it('remembers the choice once the wallet accepted it', async () => {
    await enablePrivateRpc(1);

    expect(hasEnabledPrivateRpc(1)).toBe(true);
  });

  it('does not remember the choice when the wallet rejects the prompt', async () => {
    addChain.mockRejectedValueOnce(new Error('user rejected'));

    await expect(enablePrivateRpc(1)).rejects.toThrow('user rejected');
    expect(hasEnabledPrivateRpc(1)).toBe(false);
  });

  it('refuses to touch the wallet for a chain with no private relay', async () => {
    await expect(enablePrivateRpc(167000)).rejects.toThrow(UnsupportedPrivateRpcError);
    expect(addChain).not.toHaveBeenCalled();
  });
});
