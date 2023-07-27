import { readContract } from '@wagmi/core';

export async function fetchERC1155Images(contractAddress: string, tokenIds: number[]) {
  const ERC1155_ABI = [
    {
      constant: true,
      inputs: [{ name: 'id', type: 'uint256' }],
      name: 'uri',
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
        abi: ERC1155_ABI,
        functionName: 'uri',
        args: [id],
      });
      const url = uri as string;

      // Replace placeholder with actual id
      // const resolvedUrl = url.replace("{id}", id.toString());

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
