import { useEffect } from 'react';
import { useSmartWallet } from '../hooks/useSmartWallet';
import toast from 'react-hot-toast';

interface SmartWalletSetupProps {
  isOpen: boolean;
  onClose: () => void;
}

export function SmartWalletSetup({ isOpen, onClose }: SmartWalletSetupProps) {
  const { createSmartWallet, isCreating, ownerAddress, smartWallet } = useSmartWallet();

  // Auto-close modal when smart wallet is created
  useEffect(() => {
    if (smartWallet && isOpen) {
      onClose();
    }
  }, [smartWallet, isOpen, onClose]);

  if (!isOpen) return null;

  const handleCreate = async () => {
    try {
      await createSmartWallet();
      toast.loading('Creating smart wallet...', { id: 'create-wallet' });
    } catch (error) {
      toast.error('Failed to create smart wallet');
    }
  };

  return (
    <div className="fixed inset-0 bg-black/70 backdrop-blur-sm flex items-center justify-center z-50">
      <div className="bg-surge-card/90 backdrop-blur-xl border border-surge-border/50 rounded-2xl p-6 w-full max-w-md mx-4 shadow-2xl hover-glow">
        <h2 className="text-xl font-bold text-white mb-2">Setup Surge Smart Wallet</h2>
        <p className="text-gray-400 text-sm mb-6">
          A smart wallet (UserOpsSubmitter) is required to execute cross-chain swaps. Your connected EOA wallet will sign UserOps that the smart wallet executes.
        </p>

        <div>
          <p className="text-sm text-gray-400 mb-4">
            This will deploy a new UserOpsSubmitter contract with your connected wallet as the owner.
          </p>
          <div className="bg-surge-dark rounded-lg p-3 mb-4">
            <div className="text-xs text-gray-500 mb-1">Owner (your EOA)</div>
            <div className="text-sm text-white font-mono">
              {ownerAddress}
            </div>
          </div>
          <button
            onClick={handleCreate}
            disabled={isCreating}
            className="w-full py-3 bg-surge-primary hover:bg-surge-secondary disabled:opacity-50 disabled:cursor-not-allowed text-white rounded-lg font-medium transition-colors flex items-center justify-center gap-2"
          >
            {isCreating ? (
              <>
                <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                Creating Smart Wallet...
              </>
            ) : (
              'Create Smart Wallet'
            )}
          </button>
        </div>

        <button
          onClick={onClose}
          className="w-full mt-4 py-2 text-gray-400 hover:text-white text-sm transition-colors"
        >
          Cancel
        </button>
      </div>
    </div>
  );
}
