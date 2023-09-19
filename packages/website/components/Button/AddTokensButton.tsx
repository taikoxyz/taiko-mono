import {
  SEPOLIA_ADD_ETHEREUM_CHAIN,
  SEPOLIA_ADD_TOKENS,
  SEPOLIA_CONFIG,
  JOLNIR_ADD_ETHEREUM_CHAIN,
  JOLNIR_ADD_TOKENS,
  JOLNIR_CONFIG,
} from "../../domain/chain";

import { ethereumRequest } from "../../utils/ethereumRequest";

type ConnectButtonProps = {
  network:
    | typeof SEPOLIA_CONFIG.names.shortName
    | typeof JOLNIR_CONFIG.names.shortName;
};

const chainMap = {
  Sepolia: SEPOLIA_CONFIG.chainId.hex,
};

const configMap = {
  Sepolia: SEPOLIA_ADD_ETHEREUM_CHAIN,
  Jolnir: JOLNIR_ADD_ETHEREUM_CHAIN,
};

const tokenConfigMap = {
  Sepolia: SEPOLIA_ADD_TOKENS,
  Jolnir: JOLNIR_ADD_TOKENS,
};

interface AddTokensButtonProps {
  network: ConnectButtonProps["network"];
}

const addTokensToWallet = async ({ network }: AddTokensButtonProps) => {
  const { ethereum } = window as any;
  if (ethereum.chainId != chainMap[network]) {
    await ethereumRequest("wallet_addEthereumChain", [configMap[network]]);
  }
  for (const token of tokenConfigMap[network]) {
    const params = {
      options: {
        address: token.address,
        symbol: token.symbol,
        decimals: token.decimals,
        image: token.image,
      },
      type: "ERC20",
    };
    await ethereumRequest("wallet_watchAsset", params);
  }
};

export function AddTokensButton({ network }: AddTokensButtonProps) {
  return (
    <div
      onClick={() => addTokensToWallet({ network })}
      className="hover:cursor-pointer text-neutral-100 bg-[#E81899] hover:bg-[#d1168a] border-solid border-neutral-200 focus:ring-4 focus:outline-none focus:ring-neutral-100 font-medium rounded-lg text-sm px-3 py-2 text-center inline-flex items-center m-1 w-48 justify-center"
    >
      Add {network} tokens
    </div>
  );
}
