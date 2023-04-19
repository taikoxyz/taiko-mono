import { ethers } from "ethers";

export async function withdrawTaikoTokens(
  signer: ethers.Signer,
  chains: Chains,
  providers: Providers
) {
  const contract = new ethers.Contract(
    chains[transaction.toChainId].bridgeAddress,
    BridgeABI,
    provider
  );

  const contract = new ethers.Contract(
    chains[transaction.toChainId].bridgeAddress,
    BridgeABI,
    providers[chains[transaction.toChainId].id]
  );
}
