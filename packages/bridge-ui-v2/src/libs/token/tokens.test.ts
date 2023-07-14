import { ETHToken, isERC20, isETH, isTestToken, testERC20Tokens, TKOToken } from './tokens';

vi.mock('$env/static/public');

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
});
