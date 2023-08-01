import { readContract } from '@wagmi/core';

export async function fetchERC721Images(contractAddress: string, tokenIds: number[]) {
  const ERC721_ABI = [
    {
      constant: true,
      inputs: [{ name: 'tokenId', type: 'uint256' }],
      name: 'tokenURI',
      outputs: [{ name: '', type: 'string' }],
      payable: false,
      stateMutability: 'view',
      type: 'function',
    },
  ];

  type ImageEntry = { [id: string]: string };
  type ImagesArray = ImageEntry[];
  const result: { images: ImagesArray; errors: number[] } = {
    images: [],
    errors: [],
  };

  for (const id of tokenIds) {
    try {
      const uri = await readContract({
        address: contractAddress as `0x${string}`,
        abi: ERC721_ABI,
        functionName: 'tokenURI',
        args: [id],
      });
      const url = uri as string;

      // Todo: temporary fix for pinata gateway
      const baseUrlToRemove = 'https://gateway.pinata.cloud';

      const metadata = await fetch(url.replace(baseUrlToRemove, '')).then(async (res) => await res.json());
      result.images.push({ [id]: metadata.image.replace(baseUrlToRemove, '') });
    } catch (error) {
      result.errors.push(id);
      console.error(error);
    }
  }
  return result;
}
