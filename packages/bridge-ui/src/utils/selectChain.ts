import { switchNetwork } from '@wagmi/core';
import { ethers } from 'ethers';
import { fromChain, toChain } from '../store/chain';
import type { Chain, ChainID } from '../domain/chain';
import { signer } from '../store/signer';
import { getLogger } from '../utils/logger';

const log = getLogger('selectChain');

export async function selectChain(
  chainId: ChainID, // from chain
  bridgeChains: [Chain, Chain], // current chains to bridge between
) {
  await switchNetwork({ chainId });

  const provider = new ethers.providers.Web3Provider(
    globalThis.ethereum,
    'any',
  );

  // Requires requesting permission to connect users accounts
  const accounts = await provider.send('eth_requestAccounts', []);

  log('accounts', accounts);

  const [chain1, chain2] = bridgeChains;

  if (chainId === chain1.id) {
    log(`Bridging from "${chain1.name}" to "${chain2.name}"`);

    fromChain.set(chain1);
    toChain.set(chain2);
  } else {
    log(`Bridging from "${chain2.name}" to "${chain1.name}"`);

    fromChain.set(chain2);
    toChain.set(chain1);
  }

  const _signer = provider.getSigner();

  log('signer', _signer);

  signer.set(_signer);
}
