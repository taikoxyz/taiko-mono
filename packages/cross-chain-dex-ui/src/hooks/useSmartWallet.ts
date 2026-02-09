import { useState, useEffect, useCallback } from 'react';
import { Address, decodeEventLog, zeroAddress } from 'viem';
import { useAccount, useWriteContract, useWaitForTransactionReceipt, useReadContract } from 'wagmi';
import toast from 'react-hot-toast';
import { UserOpsSubmitterFactoryABI } from '../lib/contracts';
import { USER_OPS_FACTORY } from '../lib/constants';

export function useSmartWallet() {
  const { address: ownerAddress, isConnected } = useAccount();
  const [isInitializing, setIsInitializing] = useState(true);
  const [justCreatedWallet, setJustCreatedWallet] = useState<Address | null>(null);

  const { writeContract, data: txHash, isPending: isCreating, reset } = useWriteContract();
  const { data: receipt, isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash: txHash,
  });

  // Read smart wallet from factory contract
  const { data: smartWalletFromFactory, isLoading: isLoadingFromFactory, refetch } = useReadContract({
    address: USER_OPS_FACTORY,
    abi: UserOpsSubmitterFactoryABI,
    functionName: 'getSubmitter',
    args: ownerAddress ? [ownerAddress] : undefined,
    query: {
      enabled: !!ownerAddress && isConnected,
    },
  });

  // Determine the smart wallet address (use just-created wallet or factory result)
  const smartWallet = justCreatedWallet
    ? justCreatedWallet
    : (smartWalletFromFactory && smartWalletFromFactory !== zeroAddress
        ? smartWalletFromFactory as Address
        : null);

  // Update initializing state
  useEffect(() => {
    if (!isConnected || !ownerAddress) {
      setIsInitializing(false);
      setJustCreatedWallet(null);
      return;
    }
    if (!isLoadingFromFactory) {
      setIsInitializing(false);
    }
  }, [isConnected, ownerAddress, isLoadingFromFactory]);

  // Handle successful wallet creation - parse event logs
  useEffect(() => {
    if (isSuccess && receipt && ownerAddress) {
      // Parse the SubmitterCreated event from logs
      for (const log of receipt.logs) {
        try {
          const decoded = decodeEventLog({
            abi: UserOpsSubmitterFactoryABI,
            data: log.data,
            topics: log.topics,
          });

          if (decoded.eventName === 'SubmitterCreated') {
            const createdAddress = decoded.args.submitter as Address;
            console.log('Smart wallet created:', createdAddress);

            // Dismiss loading and show success
            toast.dismiss('create-wallet');
            toast.success(`Smart wallet created: ${createdAddress.slice(0, 8)}...${createdAddress.slice(-6)}`);

            // Immediately set the wallet address to trigger UI update
            setJustCreatedWallet(createdAddress);

            // Also refetch from factory for consistency
            refetch();

            // Reset the write contract state
            reset();
            break;
          }
        } catch {
          // Not a SubmitterCreated event, continue
        }
      }
    }
  }, [isSuccess, receipt, ownerAddress, reset, refetch]);

  const createSmartWallet = useCallback(async () => {
    if (!ownerAddress) {
      throw new Error('Wallet not connected');
    }

    writeContract({
      address: USER_OPS_FACTORY,
      abi: UserOpsSubmitterFactoryABI,
      functionName: 'createSubmitter',
      args: [ownerAddress],
    });
  }, [ownerAddress, writeContract]);

  return {
    smartWallet,
    isLoading: isInitializing || isLoadingFromFactory,
    isCreating: isCreating || isConfirming,
    createSmartWallet,
    ownerAddress,
    isConnected,
    refetch,
  };
}
