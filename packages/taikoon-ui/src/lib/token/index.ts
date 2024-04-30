import { zeroAddress } from 'viem';

import { taikoonTokenAddress } from '../../generated/abi';
import { web3modal } from '../../lib/connect';
import type { IAddress, IChainId } from '../../types';
import { balanceOf } from './balanceOf';
import { canMint } from './canMint';
import { estimateMintGasCost } from './estimateMintGasCost';
import { maxSupply } from './maxSupply';
import { mint } from './mint';
import { name } from './name';
import { ownerOf } from './ownerOf';
import { symbol } from './symbol';
import { tokenOfOwner } from './tokenOfOwner';
import { tokenURI } from './tokenURI';
import { totalSupply } from './totalSupply';

function address(): IAddress {
  const { selectedNetworkId } = web3modal.getState();
  if (!selectedNetworkId) return zeroAddress;

  const chainId = selectedNetworkId as IChainId;
  return taikoonTokenAddress[chainId];
}

const Token = {
  symbol,
  name,
  totalSupply,
  tokenURI,
  address,
  ownerOf,
  balanceOf,
  canMint,
  maxSupply,
  mint,
  tokenOfOwner,
  estimateMintGasCost,
};

export default Token;
