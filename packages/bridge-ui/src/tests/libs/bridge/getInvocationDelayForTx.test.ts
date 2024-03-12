import { getInvoationDelayForTx } from '$libs/bridge/getInvocationDelayForTx';
import { getInvocationDelaysForDestBridge } from '$libs/bridge/getInvocationDelaysForDestBridge';
import { getProofReceiptForMsgHash } from '$libs/bridge/getProofReceiptForMsgHash';
import { getLatestBlockTimestamp } from '$libs/util/getLatestBlockTimestamp';
import { ALICE, L1_CHAIN_ID, L2_CHAIN_ID, MOCK_BRIDGE_TX_1 } from '$mocks';

vi.mock('$customToken', () => {
  const mockERC20 = {
    name: 'MockERC20',
    addresses: { '1': '0x123' },
    symbol: 'MTF',
    decimals: 18,
    type: 'ERC20',
  };
  return {
    customToken: [mockERC20],
  };
});

vi.mock('$libs/bridge/getInvocationDelaysForDestBridge');
vi.mock('$libs/bridge/getProofReceiptForMsgHash');
vi.mock('$libs/util/getLatestBlockTimestamp');

describe('getInvocationDelayForTx()', () => {
  it('should return the invocation delays for the transaction', async () => {
    const MOCK_BLOCK_TIMESTAMP = 1632787200n;
    const MOCK_RECIEPT_TIMESTAMP = 1632787200n - 200n;
    const PREFERRED_CLAIMER_DELAY = 100n;
    const NOT_PREFERRED_CLAIMER_DELAY = 200n;
    const MOCK_DELAYS = [PREFERRED_CLAIMER_DELAY, NOT_PREFERRED_CLAIMER_DELAY] as const;

    //Given
    vi.mocked(getInvocationDelaysForDestBridge).mockResolvedValue(MOCK_DELAYS);
    vi.mocked(getLatestBlockTimestamp).mockResolvedValue(MOCK_BLOCK_TIMESTAMP);
    vi.mocked(getProofReceiptForMsgHash).mockResolvedValue([MOCK_RECIEPT_TIMESTAMP, ALICE]);

    //When
    const result = await getInvoationDelayForTx(MOCK_BRIDGE_TX_1);

    //Then
    expect(result).toStrictEqual({
      preferredDelay: PREFERRED_CLAIMER_DELAY - (MOCK_BLOCK_TIMESTAMP - MOCK_RECIEPT_TIMESTAMP),
      notPreferredDelay: NOT_PREFERRED_CLAIMER_DELAY - (MOCK_BLOCK_TIMESTAMP - MOCK_RECIEPT_TIMESTAMP),
    });
    expect(getInvocationDelaysForDestBridge).toHaveBeenCalledWith({
      srcChainId: BigInt(L1_CHAIN_ID),
      destChainId: BigInt(L2_CHAIN_ID),
    });
    expect(getLatestBlockTimestamp).toHaveBeenCalledWith(BigInt(L2_CHAIN_ID));
    expect(getProofReceiptForMsgHash).toHaveBeenCalledWith({
      msgHash: MOCK_BRIDGE_TX_1.msgHash,
      destChainId: BigInt(L2_CHAIN_ID),
      srcChainId: BigInt(L1_CHAIN_ID),
    });
  });
});
