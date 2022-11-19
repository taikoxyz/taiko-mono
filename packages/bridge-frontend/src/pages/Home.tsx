import React from "react";

import BridgeForm from "../components/BridgeForm";
import Transactions from "../components/Transactions";

const Home: React.FC<{}> = () => {
  return (
    <div className="h-full w-full flex flex-col items-center pt-20">
      <h1 className="text-2xl text-white my-2">Taiko Bridge</h1>
      <BridgeForm />
      <Transactions />
    </div>
  );
};

export default Home;
