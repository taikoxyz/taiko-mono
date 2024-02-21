// import { getContract } from "@wagmi/core";
// import { get } from "svelte/store";
import type { Address } from 'viem';

// import { erc721VaultABI, erc1155VaultABI } from "$abi";
// import { routingContractsMap } from "$bridgeConfig";
// import { destNetwork } from "$components/Bridge/state";
import type { TokenType } from '$libs/token';
// import { getConnectedWallet } from "$libs/util/getConnectedWallet";
// import { account } from '$stores/account';
// import { network } from '$stores/network';

// import type { NFTBridgeTransferOp } from ".";

/**
 * Checks if a NFT contract is supported by the vault contract by estimating the gas cost of a sendToken call
 * @param tokenAddress
 * @param tokenType
 * @returns boolean
 */
export const isSupportedNFTInterface = async (
  tokenAddress: Address,
  tokenType: TokenType.ERC1155 | TokenType.ERC721,
): Promise<boolean> => {
  throw new Error(`Not implemented isSupportedNFTInterface: ${tokenAddress} ${tokenType}`);
  // let interfaceSupported = false;

  // const user = get(account).address;
  // const srcChainId = get(network)?.id;
  // const destChainId = get(destNetwork)?.id;

  // if (!user || !srcChainId || !destChainId) throw new Error("User, srcChainId, and destChainId must be defined");

  // const walletClient = await getConnectedWallet(srcChainId);

  // if (tokenType === TokenType.ERC721) {
  //     const dummyArgs: NFTBridgeTransferOp = {
  //         to: user,
  //         destChainId: BigInt(destChainId),
  //         token: tokenAddress,
  //         fee: 0n,
  //         gasLimit: 0n,
  //         refundTo: user,
  //         memo: '',
  //         tokenIds: [1n],
  //         amounts: [0n],
  //     }
  //     const tokenVaultContract = getContract({
  //         walletClient,
  //         abi: erc721VaultABI,
  //         address: routingContractsMap[srcChainId][destChainId].erc721VaultAddress,
  //     });
  //     try {
  //         await tokenVaultContract.estimateGas.sendToken([dummyArgs], { value: 0n })
  //         interfaceSupported = true;

  //     } catch (e) {
  //         if (e instanceof ContractFunctionExecutionError) {
  //             if (e.cause.message.includes("VAULT_INTERFACE_NOT_SUPPORTED")) {
  //                 interfaceSupported = false;

  //             }
  //         } else {
  //             console.error(e);
  //         }
  //     }

  // } else if (tokenType === TokenType.ERC1155) {
  //     const dummyArgs: NFTBridgeTransferOp = {
  //         to: user,
  //         destChainId: BigInt(destChainId),
  //         token: tokenAddress,
  //         fee: 0n,
  //         gasLimit: 0n,
  //         refundTo: user,
  //         memo: '',
  //         tokenIds: [1n],
  //         amounts: [1n],
  //     }
  //     const tokenVaultContract = getContract({
  //         walletClient,
  //         abi: erc1155VaultABI,
  //         address: routingContractsMap[srcChainId][destChainId].erc1155VaultAddress,
  //     });
  //     tokenVaultContract.estimateGas.sendToken([dummyArgs], { value: 0n }).then(() => interfaceSupported = true).catch((e) => {
  //         if (e instanceof ContractFunctionExecutionError) {
  //             if (e.cause.message.includes("VAULT_INTERFACE_NOT_SUPPORTED")) {
  //                 interfaceSupported = false;

  //             }
  //         } else {
  //             console.error(e);
  //         }
  //     });
  // }
  // return interfaceSupported
};
