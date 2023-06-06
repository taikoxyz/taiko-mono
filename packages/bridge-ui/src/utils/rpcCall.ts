import { ethers } from 'ethers';

import { getLogger } from './logger';

type RPCMethod =
  | 'eth_requestAccounts'
  | 'wallet_watchAsset'
  | 'wallet_addEthereumChain';

const log = getLogger('util:rpcCall');

export const errorCodes = {
  rpc: {
    invalidInput: -32000,
    resourceNotFound: -32001,
    resourceUnavailable: -32002,
    transactionRejected: -32003,
    methodNotSupported: -32004,
    limitExceeded: -32005,
    parse: -32700,
    invalidRequest: -32600,
    methodNotFound: -32601,
    invalidParams: -32602,
    internal: -32603,
  },
  provider: {
    userRejectedRequest: 4001,
    unauthorized: 4100,
    unsupportedMethod: 4200,
    disconnected: 4900,
    chainDisconnected: 4901,
  },
};

// The type definition for provider.send method is actually incorrect, hence:
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function rpcCall(method: RPCMethod, params?: any) {
  const provider = new ethers.providers.Web3Provider(
    globalThis.ethereum,
    'any',
  );

  log(`RPC call "${method}" with params`, params);

  try {
    // The provider could be of use here, so we also return it
    return {
      provider,
      returnValue: await provider.send(method, params),
    };
  } catch (error) {
    console.error(error);

    throw new Error(`RPC call "${method}" failed`, { cause: error });
  }
}
