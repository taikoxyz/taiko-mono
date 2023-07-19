import {
  ELDFELL_ADD_ETHEREUM_CHAIN,
  ELDFELL_CONFIG,
  GRIMSVOTN_ADD_ETHEREUM_CHAIN,
  GRIMSVOTN_CONFIG,
  SEPOLIA_ADD_ETHEREUM_CHAIN,
  SEPOLIA_CONFIG,
} from "../../domain/chain";

import { ethereumRequest } from "../../utils/ethereumRequest";

type ConnectButtonProps = {
  network:
  | typeof SEPOLIA_CONFIG.names.shortName
  | typeof ELDFELL_CONFIG.names.shortName
  | typeof GRIMSVOTN_CONFIG.names.shortName;
};

const chainMap = {
  Eldfell: ELDFELL_CONFIG.chainId.hex, // 167005
  Grimsvotn: GRIMSVOTN_CONFIG.chainId.hex, // 167005
  Sepolia: SEPOLIA_CONFIG.chainId.hex, // 11155111
};

const configMap = {
  Eldfell: ELDFELL_ADD_ETHEREUM_CHAIN,
  Grimsvotn: GRIMSVOTN_ADD_ETHEREUM_CHAIN,
  Sepolia: SEPOLIA_ADD_ETHEREUM_CHAIN,
};

interface AddTokenButtonProps {
  address: string;
  symbol: string;
  decimals: number;
  image: string;
  network: ConnectButtonProps["network"];
}

const addTokenToWallet = async (token: AddTokenButtonProps) => {
  const { ethereum } = window as any;

  if (ethereum.chainId != chainMap[token.network]) {
    await ethereumRequest("wallet_addEthereumChain", [configMap[token.network]]);
  }

  const params = { options: { address: token.address, symbol: token.symbol, decimals: token.decimals, image: token.image }, type: "ERC20" };

  await ethereumRequest("wallet_watchAsset", params);

};

export function AddTokenButton({
  address,
  symbol,
  decimals,
  image,
  network,
}: AddTokenButtonProps) {
  return (
    <div
      onClick={() => addTokenToWallet({ address, symbol, decimals, image, network })}
      className="hover:cursor-pointer text-neutral-100 bg-[#E81899] hover:bg-[#d1168a] border-solid border-neutral-200 focus:ring-4 focus:outline-none focus:ring-neutral-100 font-medium rounded-lg text-sm px-3 py-2 text-center inline-flex items-center"
    >
      Add {symbol} ({network})
    </div>
  );
}
