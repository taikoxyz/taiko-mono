import { Contract } from 'ethers';
import HeaderSyncABI from '../constants/abi/HeaderSync';
import { chains } from '../chain/chains';
import { MessageStatus } from '../domain/message';
import type { BridgeTransaction } from '../domain/transaction';
import { providers } from '../provider/providers';
import { isTransactionProcessable } from './isTransactionProcessable';
import { L1_CHAIN_ID, L2_CHAIN_ID } from '../constants/envVars';

jest.mock('ethers');
jest.mock('../constants/envVars');

describe('isTransactionProcessable', () => {
  it('should return false if the transaction is not processable', async () => {
    const mockLatestSyncedHeader = {};
    const mockGetLatestSyncedHeader = jest
      .fn()
      .mockResolvedValue(mockLatestSyncedHeader);
    const mockContract = jest.mocked(Contract).mockImplementation(
      () =>
        ({
          getLatestSyncedHeader: mockGetLatestSyncedHeader,
        } as unknown as Contract),
    );

    const mockBlock = { number: 1 } as any;
    const mockGetBlock = jest
      .mocked(providers[L1_CHAIN_ID].getBlock)
      .mockResolvedValue(mockBlock);

    expect(
      await isTransactionProcessable({
        receipt: null,
        message: null,
        status: MessageStatus.New,
      } as BridgeTransaction),
    ).toBeFalsy();

    expect(
      await isTransactionProcessable({
        receipt: { blockNumber: 2 },
        message: {},
        fromChainId: L1_CHAIN_ID,
        toChainId: L2_CHAIN_ID,
        status: MessageStatus.New,
      } as BridgeTransaction),
    ).toBeFalsy();

    expect(mockContract).toHaveBeenCalledWith(
      chains[L2_CHAIN_ID].headerSyncAddress,
      HeaderSyncABI,
      providers[L2_CHAIN_ID],
    );
    expect(mockGetLatestSyncedHeader).toHaveBeenCalledTimes(1);
    expect(mockGetBlock).toHaveBeenCalledWith(mockLatestSyncedHeader);
  });

  it('should return true if the status is not New', async () => {
    expect(
      await isTransactionProcessable({
        receipt: { blockNumber: 2 },
        message: {},
        fromChainId: L1_CHAIN_ID,
        toChainId: L2_CHAIN_ID,
        status: MessageStatus.Done,
      } as BridgeTransaction),
    ).toBeTruthy();
  });

  it('should return true if the status is not New', async () => {
    expect(
      await isTransactionProcessable({
        receipt: { blockNumber: 2 },
        message: {},
        fromChainId: L1_CHAIN_ID,
        toChainId: L2_CHAIN_ID,
        status: MessageStatus.Done,
      } as BridgeTransaction),
    ).toBeTruthy();
  });

  // TODO: missing test for when the block number is less than the latest synced header
});
