// import { chainContractsMap, chains } from "$libs/chain";
// import { isETH } from "$libs/token";
// import { bridges } from "./bridges";
// import { estimateCostOfBridging } from "./estimateCostOfBridging";
// import type { ERC20BridgeArgs, ETHBridgeArgs } from "./types";

// export async function hasEnoughBalanceToBridge({
//   token,
//   balance,
//   srcChainId,
//   userAddress,
//   processingFee,
//   destChainId,
//   amount
// }) {
//   const to = userAddress;
//   destChainId = destChainId ?? chains.find((chain) => chain.id !== srcChainId)?.id,

//   if (isETH(token)) {

//     const { bridgeAddress } = chainContractsMap[srcChainId.toString()];

//     const bridgeArgs = {
//       to,
//       amount,
//       srcChainId,
//       bridgeAddress,
//       processingFee,
//       destChainId,
//     } as ETHBridgeArgs;

//     const estimatedCost = await estimateCostOfBridging(bridges.ETH, bridgeArgs);

//     return balance - processingFee - amount > estimatedCost
//   } else {
//     // const {  }

//     // const bridgeArgs = {
//     //   to,
//     //   amount,
//     //   srcChainId,
//     //   bridgeAddress,
//     //   processingFee,
//     //   destChainId,
//     // } as ERC20BridgeArgs;

//     // const estimatedCost = await estimateCostOfBridging(bridges.ERC20, bridgeArgs);
//   }
// }
