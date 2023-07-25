import { readContract } from '@wagmi/core';

export async function detectContractType(contractAddress: string, tokenId: number) {
  // eslint-disable-next-line no-console
  console.info('detectContractType', contractAddress);

  // Use abi from @wagmi/core, and get it setup in wagmi.config.ts
  const ERC721_ABI = [
    {
      constant: true,
      inputs: [{ name: 'tokenId', type: 'uint256' }],
      name: 'ownerOf',
      outputs: [{ name: '', type: 'address' }],
      payable: false,
      stateMutability: 'view',
      type: 'function',
    },
  ];

  const ERC1155_ABI = [
    {
      constant: true,
      inputs: [
        { name: 'owner', type: 'address' },
        { name: 'operator', type: 'address' },
      ],
      name: 'isApprovedForAll',
      outputs: [{ name: '', type: 'bool' }],
      payable: false,
      stateMutability: 'view',
      type: 'function',
    },
  ];

  try {
    await readContract({
      address: contractAddress as `0x${string}`, // TODO: type Address
      abi: ERC721_ABI,
      functionName: 'ownerOf',
      args: [tokenId],
    });
    // TODO: please use getLogger from util/logger
    // eslint-disable-next-line no-console
    console.info('ERC721');
    return 'ERC721'; // TODO: use TokenType
  } catch (err) {
    // eslint-disable-next-line no-console
    console.log(err);
    try {
      await readContract({
        address: contractAddress as `0x${string}`,
        abi: ERC1155_ABI,
        functionName: 'isApprovedForAll',
        args: ['0x0000000000000000000000000000000000000000', '0x0000000000000000000000000000000000000000'],
      });
      // eslint-disable-next-line no-console
      console.info('ERC1155');
      return 'ERC1155'; // TODO: use TokenType
    } catch (err) {
      // eslint-disable-next-line no-console
      console.log(err);
      return 'UNKNOWN'; // TODO: throw UnknownTypeError and handle in the UI?
    }
  }
}
