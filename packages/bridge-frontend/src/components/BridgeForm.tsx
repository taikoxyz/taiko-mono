import React from "react";

const BridgeForm: React.FC<{}> = () => {
  const [fromChain, setFromChain] = React.useState<string>("Mainnet");
  const [toChain, setToChain] = React.useState<string>("Taiko");

  const swap = () => {
    if (fromChain === "Mainnet") {
      setFromChain("Taiko");
      setToChain("Mainnet");
    } else {
      setFromChain("Mainnet");
      setToChain("Taiko");
    }
  };

  return (
    <form className="bg-white rounded-md p-4 flex flex-col w-5/6 md:w-1/3">
      <span>From:</span>
      <div className="text-xl flex items-center justify-between">
        <span>{fromChain}</span>
        <input
          type="number"
          name="fromValue"
          placeholder="0.0"
          className="border-none bg-none text-right p-2"
        />
      </div>
      <button
        type="button"
        onClick={swap}
        className="flex items-center justify-center text-taiko-pink shadow-md rounded-full h-12 w-12 m-auto text-2xl"
      >
        <span className="relative top-1">&darr;</span>
      </button>
      <span>To:</span>
      <div className="text-xl flex items-center justify-between">
        <span>{toChain}</span>
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
