import React from "react";

import ChainSelector from "../chainSelector";

const BridgeForm: React.FC<{}> = () => {
  return (
    <form className="bg-white rounded-md p-4 flex flex-col w-5/6 md:w-1/3">
      <ChainSelector.Select className="flex items-center justify-between">
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
      <div className="text-xl flex items-center justify-between">
        <input
          type="number"
          name="fromValue"
          placeholder="0.0"
          className="border-none bg-none text-right p-2"
        />
      </div>
      <div className="text-xl flex items-center justify-between">
        <input
          type="number"
          name="toValue"
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
