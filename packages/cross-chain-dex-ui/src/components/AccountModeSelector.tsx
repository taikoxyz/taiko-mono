import { AccountMode } from '../types';

interface AccountModeSelectorProps {
  isOpen: boolean;
  onSelect: (mode: AccountMode) => void;
  onClose: () => void;
}

export function AccountModeSelector({ isOpen, onSelect, onClose }: AccountModeSelectorProps) {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-black/75 flex items-center justify-center z-50">
      <div className="bg-surge-card border border-surge-border/50 rounded-2xl p-6 w-full max-w-md mx-4 shadow-2xl hover-glow">
        <h2 className="text-xl font-bold text-white mb-2">Choose Account Type</h2>
        <p className="text-gray-400 text-sm mb-6">
          Your wallet supports Ambire Smart Account (EIP-7702). Choose how you'd like to interact with Surge.
        </p>

        <div className="space-y-3">
          <button
            onClick={() => onSelect('safe')}
            className="w-full text-left p-4 bg-surge-dark rounded-xl border border-surge-border/30 hover:border-surge-primary/50 transition-colors group"
          >
            <div className="flex items-center gap-3 mb-1">
              <div className="w-8 h-8 bg-blue-500/20 rounded-lg flex items-center justify-center">
                <svg className="w-4 h-4 text-blue-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                </svg>
              </div>
              <span className="text-white font-medium group-hover:text-surge-primary transition-colors">Safe Wallet</span>
            </div>
            <p className="text-xs text-gray-500 ml-11">
              Creates a dedicated Safe. Works with any wallet.
            </p>
          </button>

          <button
            onClick={() => onSelect('ambire')}
            className="w-full text-left p-4 bg-surge-dark rounded-xl border border-surge-border/30 hover:border-surge-secondary/50 transition-colors group"
          >
            <div className="flex items-center gap-3 mb-1">
              <div className="w-8 h-8 bg-purple-500/20 rounded-lg flex items-center justify-center">
                <svg className="w-4 h-4 text-purple-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 10V3L4 14h7v7l9-11h-7z" />
                </svg>
              </div>
              <span className="text-white font-medium group-hover:text-surge-secondary transition-colors">Ambire Account</span>
            </div>
            <p className="text-xs text-gray-500 ml-11">
              Uses your existing 7702 smart account. No extra wallet needed.
            </p>
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
