import { useState } from 'react';
import { FullDisclaimer } from './FullDisclaimer';

interface DisclaimerModalProps {
  isOpen: boolean;
  onAccept: () => void;
  onCancel: () => void;
}

export function DisclaimerModal({ isOpen, onAccept, onCancel }: DisclaimerModalProps) {
  const [checked, setChecked] = useState(false);
  const [showFull, setShowFull] = useState(false);

  if (!isOpen) return null;

  const handleAccept = () => {
    setChecked(false);
    onAccept();
  };

  const handleCancel = () => {
    setChecked(false);
    onCancel();
  };

  return (
    <>
      <div className="fixed inset-0 bg-black/75 flex items-center justify-center z-50">
        <div className="bg-surge-card border border-surge-border/50 rounded-2xl p-6 w-full max-w-md mx-4 shadow-2xl">
          <div className="flex items-center gap-2 mb-4">
            <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 text-red-400 shrink-0" viewBox="0 0 20 20" fill="currentColor">
              <path fillRule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clipRule="evenodd" />
            </svg>
            <h2 className="text-lg font-bold text-white">Experimental Alpha - Please Read Before Proceeding</h2>
          </div>

          <div className="space-y-3 text-sm text-gray-300 mb-6">
            <p>
              This is unaudited, experimental software. <strong className="text-white">You may lose any funds you deposit.</strong> Smart contracts powering this Alpha have not been security audited and may contain critical bugs or vulnerabilities.
            </p>
            <p>
              Deposits are capped at $1 USD to limit exposure, but this does not protect you from total loss of deposited funds. Do not deposit any amount you are not fully prepared to lose entirely.
            </p>
            <p>
              Nethermind provides no guarantees and accepts no liability for loss of funds.
            </p>
          </div>

          <button
            onClick={() => setShowFull(true)}
            className="text-sm text-red-400 underline hover:text-red-300 mb-4 inline-block"
          >
            Read full disclaimer
          </button>

          <label className="flex items-start gap-2 mb-6 cursor-pointer group">
            <input
              type="checkbox"
              checked={checked}
              onChange={(e) => setChecked(e.target.checked)}
              className="mt-0.5 w-4 h-4 rounded border-surge-border accent-surge-primary cursor-pointer"
            />
            <span className="text-sm text-gray-300 group-hover:text-white transition-colors">
              I understand and accept these risks
            </span>
          </label>

          <div className="flex gap-3">
            <button
              onClick={handleCancel}
              className="flex-1 px-4 py-2 text-sm font-semibold rounded-lg border border-surge-border/50 text-gray-300 hover:text-white hover:border-surge-border transition-colors"
            >
              Cancel
            </button>
            <button
              onClick={handleAccept}
              disabled={!checked}
              className={`flex-1 px-4 py-2 text-sm font-semibold rounded-lg transition-all duration-200 ${
                checked
                  ? 'bg-gradient-to-r from-surge-primary to-surge-secondary text-white hover:shadow-lg hover:shadow-surge-primary/30'
                  : 'bg-surge-card/50 text-gray-500 cursor-not-allowed border border-surge-border/30'
              }`}
            >
              Continue
            </button>
          </div>
        </div>
      </div>
      <FullDisclaimer isOpen={showFull} onClose={() => setShowFull(false)} />
    </>
  );
}
