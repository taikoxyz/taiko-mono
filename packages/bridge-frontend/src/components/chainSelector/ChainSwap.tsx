import React from "react";
import { ChainSelectorContext } from "./ChainSelector";

const ChainSwap: React.FC<{}> = () => {
  const chainSelectorContext = React.useContext(ChainSelectorContext);

  React.useEffect(() => {
    if (!chainSelectorContext) {
      throw new Error("Options should be used inside a Select");
    }
  }, [chainSelectorContext]);

  return (
    <button
      type="button"
      onClick={chainSelectorContext.swap}
      className="flex items-center justify-center text-taiko-pink shadow-md rounded-full h-12 w-12 m-auto text-2xl"
    >
      <span className="relative top-1">&rarr;</span>
    </button>
  );
};

export default ChainSwap;
