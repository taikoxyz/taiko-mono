import React, { SyntheticEvent } from "react";
import { chains } from "../config/chains";
import { ChainSelectorContext } from "./ChainSelector";
import type { AllowedNames } from "./ChainSelector";

interface Props {
  name: AllowedNames;
}

const ChainOptions: React.FC<Props> = ({ name }) => {
  const chainSelectorContext = React.useContext(ChainSelectorContext);

  React.useEffect(() => {
    if (!chainSelectorContext) {
      throw new Error("Options should be used inside a Select");
    }
  }, [chainSelectorContext]);

  const changeHandler = (event: SyntheticEvent) => {
    const selectedValue = (event.target as HTMLSelectElement).value;
    chainSelectorContext.setChain(name, chains[selectedValue]);
  };

  return (
    <select
      name={name}
      value={chainSelectorContext.state[name]}
      onChange={changeHandler}
    >
      {Object.keys(chains).map((chainId) => {
        const chain = chains[chainId];
        return (
          <option value={chainId} key={chainId}>
            {chain.name}
          </option>
        );
      })}
    </select>
  );
};

export default ChainOptions;
