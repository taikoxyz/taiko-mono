import React from "react";

import type { Chain } from "../../types";

import {
  DEFAULT_FROM_CHAIN_ID,
  DEFAULT_TO_CHAIN_ID,
} from "../../config/defaults";
import { chains } from "../../config/chains";

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
  onChainChange?: (name: string, chainId: number) => void;
  defaultFromChain?: number;
  className?: string;
};

export const ChainSelectorContext =
  React.createContext<ChainSelectorContextType>(defaultValue);

const findOtherChain = (chainId: number) => {
  let newOtherChainValue;
  const chainIdsArray = Object.keys(chains);

  for (let i = 0; i < chainIdsArray.length; i++) {
    if (chainId !== parseInt(chainIdsArray[i])) {
      newOtherChainValue = parseInt(chainIdsArray[i]);
      break;
    }
  }

  return newOtherChainValue ?? DEFAULT_TO_CHAIN_ID;
};

const ChainSelector: React.FC<React.PropsWithChildren<Props>> = ({
  children,
  onChainChange,
  defaultFromChain,
  className = "",
}) => {
  const [state, setState] = React.useState(() => {
    return {
      ...defaultValue.state,
      from: defaultFromChain ?? DEFAULT_FROM_CHAIN_ID,
      to: findOtherChain(defaultFromChain ?? DEFAULT_FROM_CHAIN_ID),
    };
  });
  const setChain = (name: AllowedNames, chain: Chain) => {
    const newOtherChainValue = findOtherChain(chain.id);

    if (name === "from") {
      setState({
        from: chain.id,
        to: newOtherChainValue as number,
      });
      if (onChainChange) {
        onChainChange("from", chain.id);
        onChainChange("to", newOtherChainValue);
      }
    } else {
      setState({
        to: chain.id,
        from: newOtherChainValue as number,
      });
      if (onChainChange) {
        onChainChange("to", chain.id);
        onChainChange("from", newOtherChainValue);
      }
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
