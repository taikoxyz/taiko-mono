import { routingContractsMap } from '$bridgeConfig';
import { ContractType, type GetContractAddressType } from '$libs/bridge';
import { TokenType } from '$libs/token';

import { getContractAddressByType } from './getContractAddressByType';

const SRC_CHAIN_ID = 1;
const DEST_CHAIN_ID = 2;
vi.mock('@wagmi/core');
vi.mock('$customToken', () => ({ customToken: [] }));
vi.mock('@web3modal/wagmi');
vi.mock('$bridgeConfig', () => ({
  routingContractsMap: {
    1: {
      2: {
        erc20VaultAddress: '0x00001',
        bridgeAddress: '0x00002',
        erc721VaultAddress: '0x00003',
        erc1155VaultAddress: '0x00004',
        crossChainSyncAddress: '0x00005',
        signalServiceAddress: '0x00006',
      },
    },
    2: {
      1: {
        erc20VaultAddress: '0x00007',
        bridgeAddress: '0x00008',
        erc721VaultAddress: '0x00009',
        erc1155VaultAddress: '0x00010',
        crossChainSyncAddress: '0x00011',
        signalServiceAddress: '0x00012',
      },
    },
  },
}));

describe('getContractAddressBasedOnType', () => {
  it('should return the correct vault contract address based on contract type (ERC20)', () => {
    // Given
    const args: GetContractAddressType = {
      srcChainId: SRC_CHAIN_ID,
      destChainId: DEST_CHAIN_ID,
      tokenType: TokenType.ERC20,
      contractType: ContractType.VAULT,
    };

    const expectedAddress = routingContractsMap[SRC_CHAIN_ID][DEST_CHAIN_ID].erc20VaultAddress;

    // When
    const address = getContractAddressByType(args);

    // Then
    expect(address).to.equal(expectedAddress);
    expect(address).not.toBeUndefined();
  });

  it('should return the correct vault contract address based on token type (ERC721)', () => {
    // Given
    const args: GetContractAddressType = {
      srcChainId: SRC_CHAIN_ID,
      destChainId: DEST_CHAIN_ID,
      tokenType: TokenType.ERC721,
      contractType: ContractType.VAULT,
    };

    const expectedAddress = routingContractsMap[SRC_CHAIN_ID][DEST_CHAIN_ID].erc721VaultAddress;

    // When
    const address = getContractAddressByType(args);

    // Then
    expect(address).to.equal(expectedAddress);
    expect(address).not.toBeUndefined();
  });

  it('should return the correct vault contract address based on token type (ERC1155)', () => {
    // Given
    const args: GetContractAddressType = {
      srcChainId: SRC_CHAIN_ID,
      destChainId: DEST_CHAIN_ID,
      tokenType: TokenType.ERC1155,
      contractType: ContractType.VAULT,
    };

    const expectedAddress = routingContractsMap[SRC_CHAIN_ID][DEST_CHAIN_ID].erc1155VaultAddress;

    // When
    const address = getContractAddressByType(args);

    // Then
    expect(address).to.equal(expectedAddress);
    expect(address).not.toBeUndefined();
  });

  it('should return the correct bridge contract address', () => {
    // Given
    const args: GetContractAddressType = {
      srcChainId: SRC_CHAIN_ID,
      destChainId: DEST_CHAIN_ID,
      contractType: ContractType.BRIDGE,
      tokenType: TokenType.ERC20,
    };

    const expectedAddress = routingContractsMap[SRC_CHAIN_ID][DEST_CHAIN_ID].bridgeAddress;

    // When
    const address = getContractAddressByType(args);

    // Then
    expect(address).to.equal(expectedAddress);
    expect(address).not.toBeUndefined();
  });

  it('should return the correct crosschain sync contract address', () => {
    // Given
    const args: GetContractAddressType = {
      srcChainId: SRC_CHAIN_ID,
      destChainId: DEST_CHAIN_ID,
      contractType: ContractType.CROSSCHAINSYNC,
      tokenType: TokenType.ERC20,
    };

    const expectedAddress = routingContractsMap[SRC_CHAIN_ID][DEST_CHAIN_ID].crossChainSyncAddress;

    // When
    const address = getContractAddressByType(args);

    // Then
    expect(address).to.equal(expectedAddress);
    expect(address).not.toBeUndefined();
  });

  it('should return the correct signalservice contract address', () => {
    // Given
    const args: GetContractAddressType = {
      srcChainId: SRC_CHAIN_ID,
      destChainId: DEST_CHAIN_ID,
      contractType: ContractType.SIGNALSERVICE,
      tokenType: TokenType.ERC20,
    };

    const expectedAddress = routingContractsMap[SRC_CHAIN_ID][DEST_CHAIN_ID].signalServiceAddress;

    // When
    const address = getContractAddressByType(args);

    // Then
    expect(address).to.equal(expectedAddress);
    expect(address).not.toBeUndefined();
  });

  it('should return the correct contract address for different configs', () => {
    // Given
    const args: GetContractAddressType = {
      srcChainId: DEST_CHAIN_ID,
      destChainId: SRC_CHAIN_ID,
      contractType: ContractType.SIGNALSERVICE,
      tokenType: TokenType.ERC20,
    };

    const expectedAddress = routingContractsMap[DEST_CHAIN_ID][SRC_CHAIN_ID].signalServiceAddress;

    // When
    const address = getContractAddressByType(args);

    // Then
    expect(address).to.equal(expectedAddress);
    expect(address).not.toBeUndefined();
  });
});
