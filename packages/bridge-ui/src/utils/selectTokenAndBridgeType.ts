import { get } from 'svelte/store';

import { BridgeType } from '../domain/bridge';
import type { Token } from '../domain/token';
import { bridgeType } from '../store/bridge';
import { token } from '../store/token';
import { isETH } from '../token/tokens';
import { getLogger } from './logger';

const log = getLogger('util:selectTokenAndBridgeType');

export function selectTokenAndBridgeType(_token: Token) {
  // We do nothing if the token is already selected
  if (_token === get(token)) return;

  log('Selecting token', _token);
  token.set(_token);

  // We need to also update the type of bridge
  if (isETH(_token)) {
    log('Selecting ETH bridge');
    bridgeType.set(BridgeType.ETH);
  } else {
    log('Selecting ERC20 bridge');
    bridgeType.set(BridgeType.ERC20);
  }
}
