import Bull from '../components/icons/Bull.svelte';
import Horse from '../components/icons/Horse.svelte';
import Unknown from '../components/icons/Unknown.svelte';
import {
  ETHToken,
  isERC20,
  isETH,
  isTestToken,
  testERC20Tokens,
  TKOToken,
} from './tokens';

jest.mock('../constants/envVars', () => ({
  TEST_ERC20: [
    {
      address: '0x959922bE3CAee4b8Cd9a407cc3ac1C251C2007B1',
      symbol: 'BLL',
      name: 'Bull Token',
    },
    {
      address: '0x0B306BF915C4d645ff596e518fAf3F9669b97016',
      symbol: 'HORSE',
      name: 'Horse Token',
    },
    {
      address: '0x123',
      symbol: 'UNK',
      name: 'Unknown token',
    },
  ],
}));

const BLL = testERC20Tokens[0];
const HORSE = testERC20Tokens[1];

describe('Tokens', () => {
  it('tests isTestToken', () => {
    expect(isTestToken(BLL)).toBeTruthy();
    expect(isTestToken(HORSE)).toBeTruthy();
    expect(isTestToken(ETHToken)).toBeFalsy();
  });

  it('tests isETH', () => {
    expect(isETH(ETHToken)).toBeTruthy();
    expect(isETH(BLL)).toBeFalsy();
    expect(isETH(HORSE)).toBeFalsy();
    expect(isETH(TKOToken)).toBeFalsy();
  });

  it('tests isERC20', () => {
    expect(isERC20(ETHToken)).toBeFalsy();
    expect(isERC20(BLL)).toBeTruthy();
    expect(isERC20(HORSE)).toBeTruthy();
    expect(isERC20(TKOToken)).toBeTruthy();
  });

  it('tests unknonw token in testERC20Tokens', () => {
    expect(testERC20Tokens).toHaveLength(3);
    expect(testERC20Tokens[0].logoComponent).toBe(Bull);
    expect(testERC20Tokens[1].logoComponent).toBe(Horse);

    // Should have the Unknown component
    expect(testERC20Tokens[2].logoComponent).toBe(Unknown);
  });
});
