import React from "react";
import { useNetwork, useSwitchNetwork } from "wagmi";

import { DEFAULT_FROM_CHAIN_ID } from "../config/defaults";
import { Chain } from "../types";

import ChainSelector from "./chainSelector";
import TokenSelector from "./tokenSelector";

const BridgeForm: React.FC<{}> = () => {
  const { chain } = useNetwork();
  const [fromChainId, setFromChainId] = React.useState(
    chain?.id ?? DEFAULT_FROM_CHAIN_ID
  );

  const { isLoading, switchNetwork } = useSwitchNetwork({
    chainId: fromChainId,
  });
  const [showSwitchButton, setShowSwitchButton] =
    React.useState<boolean>(false);
  React.useEffect(() => {
    if (chain?.id !== fromChainId) {
      setShowSwitchButton(true);
    } else {
      setShowSwitchButton(false);
    }
  }, [chain, fromChainId]);

  const chainChangeHandler = (name: string, chainId: number) => {
    if (name === "from") {
      setFromChainId(chainId);
    }
  };

  const switchNetworkHandler = async () => {
    switchNetwork && (await switchNetwork());
    setShowSwitchButton(false);
  };

  return (
    <form className="bg-white rounded-md p-4 flex flex-col w-5/6 md:w-1/3">
      <ChainSelector.Select
        className="flex items-center justify-between"
        onChainChange={chainChangeHandler}
        defaultFromChain={fromChainId}
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
      {showSwitchButton && switchNetwork && (
        <button
          onClick={switchNetworkHandler}
          type="button"
          className="bg-taiko-pink text-white w-[140px] m-auto rounded-md py-2 mt-6"
          disabled={isLoading}
        >
          {isLoading ? "Switching..." : "Switch Network"}
        </button>
      )}
      <button
        type="submit"
        className={`bg-taiko-pink text-white w-[100px] m-auto rounded-md py-2 mt-6 ${
          !(showSwitchButton && switchNetwork) ? "" : "hidden"
        }`}
      >
        Bridge
      </button>
    </form>
  );
};

export default BridgeForm;
