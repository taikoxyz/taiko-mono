import { MOCK_ERC20, MOCK_ERC721 } from './../src/tests/mocks/tokens';
import { TokenType } from './$libs/token/types';

export const customToken = [
  {
    ...MOCK_ERC20,
    type: TokenType.ERC20,
  },
  {
    ...MOCK_ERC721,
    type: TokenType.ERC721,
  },
];
