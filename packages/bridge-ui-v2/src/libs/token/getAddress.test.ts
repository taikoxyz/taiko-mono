import { getContract, type GetContractResult } from '@wagmi/core';

import { tokenVaultABI } from '$abi';
import { PUBLIC_L1_CHAIN_ID, PUBLIC_L2_CHAIN_ID } from '$env/static/public';
import { chainContractsMap } from '$libs/chain';

import { getAddress } from './getAddress';
import { ETHToken, testERC20Tokens } from './tokens';

vi.mock('$env/static/public');
vi.mock('@wagmi/core');
vi.mock('$abi');

const HORSEToken = testERC20Tokens[1];

const mockTokenContract = {
  read: {
    canonicalToBridged: vi.fn(),
  },
} as unknown as GetContractResult<readonly unknown[], unknown>;

describe('getAddress', () => {
  beforeAll(() => {
    vi.mocked(getContract).mockReturnValue(mockTokenContract);
  });

  it('should return undefined if ETH', async () => {
    expect(await getAddress({ token: ETHToken, srcChainId: Number(PUBLIC_L1_CHAIN_ID) })).toBeUndefined();
  });

  it('should return the address if ERC20 and has address on the source chain', async () => {
    expect(await getAddress({ token: HORSEToken, srcChainId: Number(PUBLIC_L1_CHAIN_ID) })).toEqual(
      HORSEToken.addresses[PUBLIC_L1_CHAIN_ID],
    );
  });

  it('should return undefined if ERC20 and has no address on the source chain and no destination chain is is passed in', async () => {
    expect(await getAddress({ token: HORSEToken, srcChainId: Number(PUBLIC_L2_CHAIN_ID) })).toBeUndefined();
  });

  it('should return the address of deployed ERC20 token', async () => {
    vi.mocked(mockTokenContract.read.canonicalToBridged).mockResolvedValue('0x456789');

    expect(
      await getAddress({
        token: HORSEToken,
        srcChainId: Number(PUBLIC_L2_CHAIN_ID),
        destChainId: Number(PUBLIC_L1_CHAIN_ID),
      }),
    ).toEqual('0x456789');
    expect(mockTokenContract.read.canonicalToBridged).toHaveBeenCalledWith([
      BigInt(1),
      HORSEToken.addresses[PUBLIC_L1_CHAIN_ID],
    ]);
    expect(getContract).toHaveBeenCalledWith({
      abi: tokenVaultABI,
      address: chainContractsMap[PUBLIC_L2_CHAIN_ID].tokenVaultAddress,
      chainId: Number(PUBLIC_L2_CHAIN_ID),
    });
  });
});
