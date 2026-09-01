import {
  checkERC20Message,
  checkERC721Message,
  checkERC1155Message,
  checkETHMessage,
  type CommonMessageFields,
} from './messageInvariants';

const WALLET = '0x1111111111111111111111111111111111111111';
const OWNER = '0x2222222222222222222222222222222222222222';
const TOKEN = '0x3333333333333333333333333333333333333333';
const ZERO = '0x0000000000000000000000000000000000000000';

const common = (o: Partial<CommonMessageFields> = {}): CommonMessageFields => ({
  to: WALLET,
  destOwner: OWNER,
  srcChainId: 1,
  destChainId: 167000,
  gasLimit: 750_000,
  fee: BigInt('130220640000000'),
  minGasLimit: 250_000,
  ...o,
});

describe('Bridge.sendMessage rules', () => {
  it('accepts a well-formed message', () => {
    expect(checkETHMessage(common())).toEqual([]);
  });

  it('rejects a zero recipient or destination owner', () => {
    expect(checkETHMessage(common({ to: ZERO }))).toContain('ZERO_RECIPIENT');
    expect(checkETHMessage(common({ to: null }))).toContain('ZERO_RECIPIENT');
    expect(checkETHMessage(common({ destOwner: ZERO }))).toContain('ZERO_DEST_OWNER');
    expect(checkETHMessage(common({ destOwner: null }))).toContain('ZERO_DEST_OWNER');
  });

  it('rejects a missing or same-chain destination', () => {
    expect(checkETHMessage(common({ destChainId: null }))).toContain('MISSING_DEST_CHAIN');
    expect(checkETHMessage(common({ srcChainId: null }))).toContain('MISSING_SRC_CHAIN');
    // The same-chain rule is a comparison, so an absent source chain quietly satisfies it
    expect(checkETHMessage(common({ srcChainId: null, destChainId: null }))).toContain('MISSING_SRC_CHAIN');
    expect(checkETHMessage(common({ srcChainId: 1, destChainId: 1 }))).toContain('SAME_CHAIN');
  });

  describe('B_INVALID_FEE', () => {
    it('rejects a fee alongside a zero gas limit', () => {
      // The exact combination that reverted when bridging with gasLimit deliberately 0
      expect(checkETHMessage(common({ gasLimit: 0 }))).toContain('FEE_WITH_ZERO_GAS_LIMIT');
    });

    it('accepts a zero gas limit with no fee', () => {
      expect(checkETHMessage(common({ gasLimit: 0, fee: BigInt(0) }))).toEqual([]);
    });
  });

  describe('B_INVALID_GAS_LIMIT', () => {
    it('rejects a gas limit that merely reaches the minimum', () => {
      // The contract subtracts the minimum and rejects a remainder of zero
      expect(checkETHMessage(common({ gasLimit: 250_000, minGasLimit: 250_000 }))).toContain('GAS_LIMIT_BELOW_MINIMUM');
    });

    it('accepts a gas limit one above the minimum', () => {
      expect(checkETHMessage(common({ gasLimit: 250_001, minGasLimit: 250_000 }))).toEqual([]);
    });

    it('skips the rule when the minimum is unknown rather than guessing', () => {
      expect(checkETHMessage(common({ gasLimit: 1, minGasLimit: undefined }))).toEqual([]);
    });
  });
});

describe('ERC20Vault rules', () => {
  const erc20 = (o = {}) => ({ ...common(), amount: BigInt(500), tokenAddress: TOKEN, ...o });

  it('accepts a well-formed transfer', () => {
    expect(checkERC20Message(erc20())).toEqual([]);
  });

  it('rejects a zero amount', () => {
    expect(checkERC20Message(erc20({ amount: BigInt(0) }))).toContain('ZERO_AMOUNT');
  });

  it('rejects a zero token address', () => {
    expect(checkERC20Message(erc20({ tokenAddress: ZERO }))).toContain('ZERO_TOKEN_ADDRESS');
  });

  it('still applies the common rules', () => {
    expect(checkERC20Message(erc20({ gasLimit: 0 }))).toContain('FEE_WITH_ZERO_GAS_LIMIT');
  });
});

describe('ERC721Vault rules', () => {
  const erc721 = (o = {}) => ({
    ...common(),
    tokenAddress: TOKEN,
    tokenIds: [BigInt(1)],
    amounts: [BigInt(0)],
    ...o,
  });

  it('accepts ids paired with zero amounts', () => {
    expect(checkERC721Message(erc721())).toEqual([]);
  });

  it('rejects a non-zero amount', () => {
    expect(checkERC721Message(erc721({ amounts: [BigInt(1)] }))).toContain('NON_ZERO_ERC721_AMOUNT');
  });

  it('rejects mismatched array lengths', () => {
    expect(checkERC721Message(erc721({ tokenIds: [BigInt(1), BigInt(2)], amounts: [BigInt(0)] }))).toContain(
      'TOKEN_ARRAY_MISMATCH',
    );
  });
});

describe('ERC1155Vault rules', () => {
  const erc1155 = (o = {}) => ({
    ...common(),
    tokenAddress: TOKEN,
    tokenIds: [BigInt(1)],
    amounts: [BigInt(5)],
    ...o,
  });

  it('accepts ids paired with non-zero amounts', () => {
    expect(checkERC1155Message(erc1155())).toEqual([]);
  });

  it('rejects a zero amount', () => {
    expect(checkERC1155Message(erc1155({ amounts: [BigInt(0)] }))).toContain('ZERO_ERC1155_AMOUNT');
  });

  it('rejects mismatched array lengths', () => {
    expect(checkERC1155Message(erc1155({ tokenIds: [BigInt(1), BigInt(2)], amounts: [BigInt(5)] }))).toContain(
      'TOKEN_ARRAY_MISMATCH',
    );
  });
});
