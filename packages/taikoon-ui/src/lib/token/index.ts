import { chainId } from '$lib/chain';

import { taikoonTokenAddress } from '../../generated/abi';
import type { IAddress } from '../../types';
import { balanceOf } from './balanceOf';
import { canMint } from './canMint';
import { estimateMintGasCost } from './estimateMintGasCost';
import { maxSupply } from './maxSupply';
import { mint } from './mint';
import { name } from './name';
import { ownerOf } from './ownerOf';
import { tokenOfOwner } from './tokenOfOwner';
import { tokenURI } from './tokenURI';
import { totalSupply } from './totalSupply';

function address(): IAddress {
  return taikoonTokenAddress[chainId];
}

const Token = {
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
