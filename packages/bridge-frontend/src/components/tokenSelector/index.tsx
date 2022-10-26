import React from "react";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faAngleDown } from "@fortawesome/free-solid-svg-icons";

import { tokensByChain } from "../../config/tokens";
import { Token } from "../../types";

interface Props {
  filterByChainId: number;
}

const TokenSelector: React.FC<Props> = ({ filterByChainId }) => {
  const [showTokenSelector, setShowTokenSelector] = React.useState<boolean>();
  const [tokenSelected, setTokenSelected] = React.useState<Token>();

  return (
    <div>
      <div className="relative border rounded-md px-4 py-2 flex items-center">
        <input type="text" value={"USDC"} readOnly />
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
                <div
                  className={`flex items-center p-2 hover:bg-slate-100 ${
                    token.address === tokenSelected?.address
                      ? "!bg-slate-200"
                      : ""
                  }`}
                  key={token.address}
                  onClick={() => {
                    setTokenSelected(token);
                    setShowTokenSelector(false);
                  }}
                >
                  <span className="flex-1">{token.symbol}</span>
                  <span>0.0</span>
                </div>
              );
            })}
          </div>
        </div>
      </div>
    </div>
  );
};

export default TokenSelector;
