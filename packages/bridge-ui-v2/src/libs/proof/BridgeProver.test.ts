import { type Address, encodeAbiParameters, type Hex } from 'viem';

function setupMocks() {
  
}

type Hop = {
  signalRootRelay: Address,
  signalRoot: Hex,
  storageProof: Hex,
}

describe('BridgeProver', () => {
  beforeEach(() => {
    setupMocks();
  });

  test('test encodeAbiParameters', () => {
    const hops: Hop[] = [];
    const testProof = encodeAbiParameters(
      // ['tuple(uint256 height, bytes proof)'],
      [
        {
          type: 'tuple',
          components: [
            { name: 'crossChainSync', type: 'address' },
            { name: 'height', type: 'uint256' },
            { name: 'storageProof', type: 'bytes' },
            { name: 'hops', type: 'tuple[]' },
          ],
        },
      ],
      [{ crossChainSync: "0x0000000000000000000000000000000000000000", height: BigInt(1), storageProof: "0xc0", hops: hops}],
    );
    console.log("test encodeAbiParameters", testProof);
  })
})