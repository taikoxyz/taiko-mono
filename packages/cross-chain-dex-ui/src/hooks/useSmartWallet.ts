import { useState, useEffect, useCallback, useRef } from 'react';
import { type Address, keccak256, encodePacked, decodeEventLog } from 'viem';
import { useAccount, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import toast from 'react-hot-toast';
import { SafeProxyFactoryABI } from '../lib/contracts';
import { SAFE_PROXY_FACTORY, SAFE_SINGLETON, SAFE_FALLBACK_HANDLER } from '../lib/constants';
import { buildSafeSetupCalldata } from '../lib/safeOp';
import { l1PublicClient, l2PublicClient } from '../lib/config';
import { useUserOp } from './useUserOp';

const STORAGE_KEY = 'surge_safe_address_';

function getSavedSafe(owner: string): Address | null {
  try {
    const saved = localStorage.getItem(STORAGE_KEY + owner.toLowerCase());
    return saved as Address | null;
  } catch {
    return null;
  }
}

function saveSafe(owner: string, safe: Address): void {
  try {
    localStorage.setItem(STORAGE_KEY + owner.toLowerCase(), safe);
  } catch {}
}

export function useSmartWallet() {
  const { address: ownerAddress, isConnected } = useAccount();
  const [isInitializing, setIsInitializing] = useState(true);
  const [smartWallet, setSmartWallet] = useState<Address | null>(null);
  const [l2WalletExists, setL2WalletExists] = useState(false);
  const [isCreatingL2Wallet, setIsCreatingL2Wallet] = useState(false);

  const { writeContract, data: txHash, isPending: isCreating, reset } = useWriteContract();
  const { data: receipt, isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash: txHash,
  });

  const { executeCreateL2Wallet } = useUserOp();
  const l2PollRef = useRef<ReturnType<typeof setInterval> | null>(null);

  // Cleanup L2 poll on unmount
  useEffect(() => {
    return () => {
      if (l2PollRef.current) clearInterval(l2PollRef.current);
    };
  }, []);

  // On connect: check localStorage for a saved Safe address and verify it has code on-chain.
  useEffect(() => {
    if (!isConnected || !ownerAddress) {
      setSmartWallet(null);
      setIsInitializing(false);
      return;
    }

    const saved = getSavedSafe(ownerAddress);
    if (saved) {
      l1PublicClient
        .getCode({ address: saved })
        .then((code) => {
          if (code && code !== '0x') {
            setSmartWallet(saved);
          }
          setIsInitializing(false);
        })
        .catch(() => setIsInitializing(false));
    } else {
      setIsInitializing(false);
    }
  }, [isConnected, ownerAddress]);

  // After a successful creation tx, parse the ProxyCreation event to get the proxy address.
  useEffect(() => {
    if (!isSuccess || !receipt || !ownerAddress) return;

    for (const log of receipt.logs) {
      try {
        const decoded = decodeEventLog({
          abi: SafeProxyFactoryABI,
          data: log.data,
          topics: log.topics,
        });

        if (decoded.eventName === 'ProxyCreation') {
          const proxyAddress = (decoded.args as { proxy: Address }).proxy;
          console.log('Safe created:', proxyAddress);
          toast.dismiss('create-wallet');
          toast.success(
            `Safe wallet created: ${proxyAddress.slice(0, 8)}...${proxyAddress.slice(-6)}`,
          );
          setSmartWallet(proxyAddress);
          saveSafe(ownerAddress, proxyAddress);
          reset();
          break;
        }
      } catch {
        // Not a ProxyCreation log — skip.
      }
    }
  }, [isSuccess, receipt, ownerAddress, reset]);

  // After L1 Safe is known, check if the same address has code on L2
  useEffect(() => {
    if (!smartWallet) {
      setL2WalletExists(false);
      return;
    }

    l2PublicClient
      .getCode({ address: smartWallet })
      .then((code) => {
        setL2WalletExists(!!(code && code !== '0x'));
      })
      .catch(() => setL2WalletExists(false));
  }, [smartWallet]);

  const createSmartWallet = useCallback(async () => {
    if (!ownerAddress) throw new Error('Wallet not connected');

    const initializer = buildSafeSetupCalldata(ownerAddress, SAFE_FALLBACK_HANDLER);
    const saltNonce = BigInt(keccak256(encodePacked(['address'], [ownerAddress])));

    writeContract({
      address: SAFE_PROXY_FACTORY,
      abi: SafeProxyFactoryABI,
      functionName: 'createProxyWithNonce',
      args: [SAFE_SINGLETON, initializer, saltNonce],
    });
  }, [ownerAddress, writeContract]);

  const createL2Wallet = useCallback(async (): Promise<void> => {
    if (!ownerAddress || !smartWallet) {
      toast.error('Smart wallet not ready');
      return;
    }

    setIsCreatingL2Wallet(true);
    try {
      const success = await executeCreateL2Wallet({ owner: ownerAddress, smartWallet });
      if (success) {
        toast.success('L2 Safe creation submitted via bridge');
        // Poll L2 for wallet code every 5s until found (max 60 attempts = 5 min)
        let attempts = 0;
        if (l2PollRef.current) clearInterval(l2PollRef.current);
        l2PollRef.current = setInterval(async () => {
          attempts++;
          try {
            const code = await l2PublicClient.getCode({ address: smartWallet });
            if (code && code !== '0x') {
              setL2WalletExists(true);
              if (l2PollRef.current) clearInterval(l2PollRef.current);
              l2PollRef.current = null;
            }
          } catch {}
          if (attempts >= 60 && l2PollRef.current) {
            clearInterval(l2PollRef.current);
            l2PollRef.current = null;
          }
        }, 5000);
      } else {
        toast.error('Failed to create L2 Safe');
      }
    } catch (err) {
      const msg = err instanceof Error ? err.message : 'Failed to create L2 Safe';
      toast.error(msg);
    } finally {
      setIsCreatingL2Wallet(false);
    }
  }, [ownerAddress, smartWallet, executeCreateL2Wallet]);

  return {
    smartWallet,
    isLoading: isInitializing,
    isCreating: isCreating || isConfirming,
    createSmartWallet,
    ownerAddress,
    isConnected,
    refetch: () => {},
    l2WalletExists,
    createL2Wallet,
    isCreatingL2Wallet,
  };
}
