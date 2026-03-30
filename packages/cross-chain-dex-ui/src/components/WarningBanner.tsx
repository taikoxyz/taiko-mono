import { useState } from 'react';
import { FullDisclaimer } from './FullDisclaimer';

export function WarningBanner() {
  const [showDisclaimer, setShowDisclaimer] = useState(false);

  return (
    <>
      <div className="bg-red-500/10 border border-red-500/30 rounded-lg px-3 py-2 text-xs text-red-400 flex items-center gap-1.5">
        <svg xmlns="http://www.w3.org/2000/svg" className="h-3.5 w-3.5 shrink-0" viewBox="0 0 20 20" fill="currentColor">
          <path fillRule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clipRule="evenodd" />
        </svg>
        Experimental Alpha - transaction limit of US $1. <button onClick={() => setShowDisclaimer(true)} className="underline hover:text-red-300">See disclaimer</button>
      </div>
      <FullDisclaimer isOpen={showDisclaimer} onClose={() => setShowDisclaimer(false)} />
    </>
  );
}

export function WarningBannerWrapped() {
  const [showDisclaimer, setShowDisclaimer] = useState(false);

  return (
    <>
      <div className="bg-red-500/10 border border-red-500/30 rounded-lg px-3 py-2 text-xs text-red-400 flex items-start gap-1.5 mb-4">
        <svg xmlns="http://www.w3.org/2000/svg" className="h-3.5 w-3.5 shrink-0 mt-0.5" viewBox="0 0 20 20" fill="currentColor">
          <path fillRule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clipRule="evenodd" />
        </svg>
        <span>Experimental Alpha - transaction limit of US $1. <button onClick={() => setShowDisclaimer(true)} className="underline hover:text-red-300">See disclaimer</button></span>
      </div>
      <FullDisclaimer isOpen={showDisclaimer} onClose={() => setShowDisclaimer(false)} />
    </>
  );
}
