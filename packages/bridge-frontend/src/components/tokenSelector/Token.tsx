import React from "react";
import { useAccount, useBalance } from "wagmi";
import { utils, BigNumber } from "ethers";

import type { Token as TokenType } from "../../types";

interface Props {
  token: TokenType;
  isSelected: boolean;
  onSelect: (token: TokenType) => void;
}

const Token: React.FC<Props> = ({ token, isSelected, onSelect }) => {
  const { address } = useAccount();
  const { data, isError, isLoading } = useBalance({
    addressOrName: address,
    ...(token.symbol !== "ETH" ? { token: token.address } : {}),
  });

  return (
    <div
      className={`flex items-center p-2 hover:bg-slate-100 cursor-pointer ${
        isSelected ? "!bg-slate-200" : ""
      }`}
      key={token.address}
      onClick={() => onSelect(token)}
    >
      <img src={token.logoUrl} alt={token.name} className="h-5 w-5 mr-2" />
      <span className="flex-1">{token.symbol}</span>
      {data ? (
        <span>{utils.formatUnits(data?.value as BigNumber, "ether")}</span>
      ) : (
        <span>0.0</span>
      )}
    </div>
  );
};

export default Token;
