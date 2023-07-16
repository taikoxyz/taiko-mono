import { ethereumRequest } from "../../utils/ethereumRequest";

interface AddTokenButtonProps {
  address: string;
  symbol: string;
  decimals: number;
  image: string;
}

const addTokenToWallet = async (token: AddTokenButtonProps) => {
  const options = { ...token, type: "ERC20" };
  await ethereumRequest("wallet_watchAsset", options);
};

export function AddTokenButton({
  address,
  symbol,
  decimals,
  image,
}: AddTokenButtonProps) {
  return (
    <div
      onClick={() => addTokenToWallet({ address, symbol, decimals, image })}
      className="hover:cursor-pointer text-neutral-100 bg-[#E81899] hover:bg-[#d1168a] border-solid border-neutral-200 focus:ring-4 focus:outline-none focus:ring-neutral-100 font-medium rounded-lg text-sm px-3 py-2 text-center inline-flex items-center"
    >
      Add {symbol} to wallet
    </div>
  );
}
