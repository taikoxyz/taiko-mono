import React from "react";

import type { Chain } from "../types";

import { DEFAULT_FROM_CHAIN_ID, DEFAULT_TO_CHAIN_ID } from "../config/defaults";
import { chains } from "../config/chains";

export type AllowedNames = "from" | "to";

type ChainSelectorContextType = {
  state: Record<AllowedNames, number>;
  setChain: (name: AllowedNames, chain: Chain) => void;
  swap: () => void;
};

const defaultValue = {
  state: {
    from: DEFAULT_FROM_CHAIN_ID,
    to: DEFAULT_TO_CHAIN_ID,
  },
  setChain: (name: AllowedNames, chain: Chain) => {},
  swap: () => {},
};

type Props = {
  onChainChange?: (name: string, chain: Chain) => void;
  className?: string;
};

export const ChainSelectorContext =
  React.createContext<ChainSelectorContextType>(defaultValue);

const ChainSelector: React.FC<React.PropsWithChildren<Props>> = ({
  children,
  onChainChange,
  className = "",
}) => {
  const [state, setState] = React.useState(defaultValue.state);
  const setChain = (name: AllowedNames, chain: Chain) => {
    let otherChain: AllowedNames;

    if (name === "from") {
      otherChain = "to";
    } else {
      otherChain = "from";
    }

    let newOtherChainValue;
    const chainIdsArray = Object.keys(chains);

    for (let i = 0; i < chainIdsArray.length; i++) {
      if (state[otherChain] !== parseInt(chainIdsArray[i])) {
        newOtherChainValue = parseInt(chainIdsArray[i]);
        break;
      }
    }

    if (onChainChange) {
      onChainChange(name, chain);
    }

    if (name === "from") {
      setState({
        from: chain.id,
        to: newOtherChainValue as number,
      });
    } else {
      setState({
        to: chain.id,
        from: newOtherChainValue as number,
      });
    }
  };

  const swap = () => {
    setState({
      from: state.to,
      to: state.from,
    });
  };

  return (
    <div className={className}>
      <ChainSelectorContext.Provider
        value={{
          state,
          setChain,
          swap,
        }}
      >
        {children}
      </ChainSelectorContext.Provider>
    </div>
  );
};

export default ChainSelector;
