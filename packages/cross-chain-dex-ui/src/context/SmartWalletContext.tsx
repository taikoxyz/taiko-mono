import { createContext, useContext, ReactNode, useMemo } from 'react';
import { useSmartWalletInternal, SmartWalletState } from '../hooks/useSmartWallet';
import { useTokenBalances as useTokenBalancesHook } from '../hooks/useTokenBalances';

interface SmartWalletContextValue extends SmartWalletState {
  tokenBalances: ReturnType<typeof useTokenBalancesHook>;
}

const SmartWalletContext = createContext<SmartWalletContextValue | null>(null);

export function SmartWalletProvider({ children }: { children: ReactNode }) {
  const wallet = useSmartWalletInternal();
  const tokenBalances = useTokenBalancesHook(wallet.smartWallet);
  const value = useMemo(() => ({ ...wallet, tokenBalances }), [wallet, tokenBalances]);
  return (
    <SmartWalletContext.Provider value={value}>
      {children}
    </SmartWalletContext.Provider>
  );
}

export function useSmartWallet(): SmartWalletContextValue {
  const ctx = useContext(SmartWalletContext);
  if (!ctx) throw new Error('useSmartWallet must be used within SmartWalletProvider');
  return ctx;
}

export function useSharedTokenBalances() {
  const { tokenBalances } = useSmartWallet();
  return tokenBalances;
}
