import React from "react";
import { DEFAULT_FROM_CHAIN_ID } from "../config/defaults";
import { Chain } from "../types";

import ChainSelector from "./chainSelector";
import TokenSelector from "./tokenSelector";

const BridgeForm: React.FC<{}> = () => {
  const [fromChainId, setFromChainId] = React.useState(DEFAULT_FROM_CHAIN_ID);

  const chainChangeHandler = (name: string, chain: Chain) => {
    if (name === "from") {
      setFromChainId(chain.id);
    }
  };

  return (
    <form className="bg-white rounded-md p-4 flex flex-col w-5/6 md:w-1/3">
      <ChainSelector.Select
        className="flex items-center justify-between"
        onChainChange={chainChangeHandler}
      >
        <div>
          <span>From:</span>
          <div className="text-xl">
            <ChainSelector.Options name="from" />
          </div>
        </div>
        <ChainSelector.Swap />
        <div>
          <span>To:</span>
          <div className="text-xl">
            <ChainSelector.Options name="to" />
          </div>
        </div>
      </ChainSelector.Select>
      <div className="flex items-center justify-between mt-8">
        <TokenSelector filterByChainId={fromChainId} />
        <input
          type="number"
          name="fromValue"
          placeholder="0.0"
          className="border-none bg-none text-right p-2"
        />
      </div>
      <button
        type="submit"
        className="bg-taiko-pink text-white w-[100px] m-auto rounded-md py-2 mt-6"
      >
        Bridge
      </button>
    </form>
  );
};

export default BridgeForm;
