import React from "react";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faAngleDown } from "@fortawesome/free-solid-svg-icons";

import Token from "./Token";
import { tokensByChain } from "../../config/tokens";
import { Token as TokenType } from "../../types";
import { DEFAULT_TOKEN } from "../../config/defaults";

interface Props {
  filterByChainId: number;
  onTokenSelected?: (token: TokenType) => void;
}

const TokenSelector: React.FC<Props> = ({
  filterByChainId,
  onTokenSelected,
}) => {
  const [showTokenSelector, setShowTokenSelector] = React.useState<boolean>();
  const tokenAddressesByChain = Object.keys(tokensByChain[filterByChainId]);
  const [tokenSelected, setTokenSelected] = React.useState<TokenType>(
    tokensByChain[filterByChainId][tokenAddressesByChain[0]] ?? DEFAULT_TOKEN
  );

  React.useEffect(() => {
    if (onTokenSelected) {
      onTokenSelected(tokensByChain[filterByChainId][tokenAddressesByChain[0]]);
    }
  }, [onTokenSelected, tokenAddressesByChain, filterByChainId]);

  const onSelectToken = (token: TokenType) => {
    setTokenSelected(token);
    setShowTokenSelector(false);
    if (onTokenSelected) {
      onTokenSelected(token);
    }
  };

  return (
    <div>
      <div className="relative border rounded-md px-4 py-2 flex items-center">
        <input type="text" value={tokenSelected.name} readOnly />
        <FontAwesomeIcon icon={faAngleDown} size="sm" />
        {/* <span className="text-lg font-bold">&#8964;</span> */}
        <button
          type="button"
          className="absolute bg-transparent h-full w-full top-0 left-0"
          onClick={() => setShowTokenSelector(true)}
        ></button>
      </div>
      <div
        className={`fixed top-0 left-0 bg-black/50 h-full w-full flex items-center justify-center ${
          showTokenSelector ? "" : "hidden"
        }`}
      >
        <div className="bg-white rounded-md w-1/4 min-h-[400px]">
          <div className="p-2 flex items-center justify-between">
            <h4 className="text-lg">Tokens</h4>
            <button
              type="button"
              className="text-3xl"
              onClick={() => setShowTokenSelector(false)}
            >
              &times;
            </button>
          </div>
          <div className="p-2 pb-4 border-b">
            <input
              type="text"
              placeholder="Search by name or address"
              className="w-full border p-1 rounded-md"
            />
          </div>
          <div className="grid grid-cols-1 divide-y divide-slate-100 py-2">
            {Object.keys(tokensByChain[filterByChainId]).map((address) => {
              const token = tokensByChain[filterByChainId][address];
              return (
                <Token
                  key={token.address}
                  token={token}
                  isSelected={token.address === tokenSelected?.address}
                  onSelect={onSelectToken}
                />
              );
            })}
          </div>
        </div>
      </div>
    </div>
  );
};

export default TokenSelector;
