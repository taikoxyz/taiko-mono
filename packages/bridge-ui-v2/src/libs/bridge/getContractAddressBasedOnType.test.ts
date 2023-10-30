import { expect } from 'chai';

import { routingContractsMap } from '$bridgeConfig';
import { ContractType, type GetContractAddressType } from '$libs/bridge';
import { TokenType } from '$libs/token';

import { getContractAddressBasedOnType } from './getContractAddressBasedOnType';

const SRC_CHAIN_ID = 1;
const DEST_CHAIN_ID = 2;

describe('getContractAddressBasedOnType', () => {
  it('should return the correct contract address based on contract type', () => {
    // Given
    const args: GetContractAddressType = {
      srcChainId: SRC_CHAIN_ID,
      destChainId: DEST_CHAIN_ID,
      tokenType: TokenType.ERC20,
      contractType: ContractType.BRIDGE,
    };

    const expectedAddress = routingContractsMap[SRC_CHAIN_ID][DEST_CHAIN_ID].bridgeAddress;

    // When
    const address = getContractAddressBasedOnType(args);

    // Then
    expect(address).to.equal(expectedAddress);
  });
});
