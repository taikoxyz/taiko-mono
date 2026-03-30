import { createContext, useContext, useState, ReactNode } from "react";
import { TxOverlayState } from "../types";

interface TxStatusContextValue {
  txStatus: TxOverlayState;
  setTxStatus: (s: TxOverlayState) => void;
}

const TxStatusContext = createContext<TxStatusContextValue>({
  txStatus: { phase: "idle" },
  setTxStatus: () => {},
});

export function TxStatusProvider({ children }: { children: ReactNode }) {
  const [txStatus, setTxStatus] = useState<TxOverlayState>({ phase: "idle" });
  return (
    <TxStatusContext.Provider value={{ txStatus, setTxStatus }}>
      {children}
    </TxStatusContext.Provider>
  );
}

export function useTxStatus() {
  return useContext(TxStatusContext);
}
