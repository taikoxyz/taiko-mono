import { get } from 'svelte/store';

import { BridgeType } from '../domain/bridge';
import { bridgeType } from '../store/bridge';
import { token } from '../store/token';
import { ETHToken, TKOToken } from '../token/tokens';
import { selectTokenAndBridgeType } from './selectTokenAndBridgeType';

jest.mock('svelte/store');
jest.mock('../constants/envVars');

jest.mock('../store/token', () => ({
  token: {
    set: jest.fn(),
  },
}));

jest.mock('../store/bridge', () => ({
  bridgeType: {
    set: jest.fn(),
  },
}));

describe('selectTokenAndBridgeType', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('should select ETH token and bridge', () => {
    selectTokenAndBridgeType(ETHToken);

    expect(token.set).toHaveBeenCalledWith(ETHToken);
    expect(bridgeType.set).toHaveBeenCalledWith(BridgeType.ETH);
  });

  it('should do nothing if the token is already selected', () => {
    jest.mocked(get).mockReturnValueOnce(ETHToken);

    selectTokenAndBridgeType(ETHToken);

    expect(token.set).not.toHaveBeenCalled();
    expect(bridgeType.set).not.toHaveBeenCalled();
  });

  it('should select ERC20 token and bridge', () => {
    selectTokenAndBridgeType(TKOToken);

    expect(token.set).toHaveBeenCalledWith(TKOToken);
    expect(bridgeType.set).toHaveBeenCalledWith(BridgeType.ERC20);
  });
});
