interface FullDisclaimerProps {
  isOpen: boolean;
  onClose: () => void;
}

export function FullDisclaimer({ isOpen, onClose }: FullDisclaimerProps) {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-black/80 flex items-center justify-center z-[60]">
      <div className="bg-surge-card border border-surge-border/50 rounded-2xl w-full max-w-2xl mx-4 shadow-2xl max-h-[85vh] flex flex-col">
        <div className="p-6 pb-0">
          <h2 className="text-xl font-bold text-white">Surge Realtime Alpha - Experimental Software Disclaimer</h2>
        </div>

        <div className="p-6 overflow-y-auto space-y-4 text-sm text-gray-300 leading-relaxed">
          <p>
            <strong className="text-white">Please read this disclaimer carefully before using the Surge Realtime Alpha ("the Alpha").</strong> By interacting with any component of the Alpha (including the bridge, explorer, DEX, or RPC), you acknowledge that you have read, understood, and accepted the terms described below.
          </p>

          <div>
            <h3 className="text-white font-semibold mb-1">What the Alpha Is</h3>
            <p>
              The Surge Realtime Alpha is an experimental, research-grade deployment demonstrating synchronous composability between L1 and L2. By merging sequencing and proving into a single L1 transaction, L2 state is trustlessly finalized immediately.
            </p>
            <p className="mt-2">
              This is novel, frontier infrastructure: not a production system, not audited, and intended for use only for test transactions involving negligible value.
            </p>
          </div>

          <div>
            <h3 className="text-white font-semibold mb-1">Risks</h3>
            <p>
              Smart contracts underlying this deployment have not undergone a security audit and may contain critical vulnerabilities. The system may be taken offline at any time without notice. You may lose any funds you deposit. As a safeguard, the UI enforces a maximum deposit of $1 USD equivalent - this is not a guarantee against loss, but a guardrail to limit potential exposure.
            </p>
            <p className="mt-2">
              Nethermind provides no guarantees of uptime, correctness, or recoverability of funds.
            </p>
          </div>

          <div>
            <h3 className="text-white font-semibold mb-1">Who Should Use This</h3>
            <p>
              This Alpha is intended exclusively for technically sophisticated users, such as developers, researchers, and protocol engineers, who understand the risks of interacting with experimental blockchain infrastructure. It is not intended for general audiences, and it is not suitable for any use involving funds you cannot afford to lose entirely.
            </p>
          </div>

          <div>
            <h3 className="text-white font-semibold mb-1">No Warranties</h3>
            <p>
              The Alpha is provided "as is" and "as available," without warranty of any kind, express or implied. Nethermind makes no representations regarding the security, reliability, accuracy, or fitness for any purpose of this software.
            </p>
          </div>

          <div>
            <h3 className="text-white font-semibold mb-1">No Liability</h3>
            <p>
              To the maximum extent permitted by applicable law, Nethermind and its contributors shall not be liable for any direct, indirect, incidental, consequential, or special damages arising from your use of the Alpha, including but not limited to loss of funds, loss of data, or service interruption.
            </p>
          </div>

          <div>
            <h3 className="text-white font-semibold mb-1">Regulatory Status</h3>
            <p>
              This Alpha is a technical research deployment. It is not a regulated financial product or service. You are solely responsible for ensuring that your use of the Alpha complies with all laws and regulations applicable in your jurisdiction.
            </p>
          </div>

          <div>
            <h3 className="text-white font-semibold mb-1">Changes and Termination</h3>
            <p>
              Nethermind reserves the right to modify, suspend, or discontinue the Alpha at any time without notice.
            </p>
          </div>
        </div>

        <div className="p-6 pt-4 border-t border-surge-border/30">
          <button
            onClick={onClose}
            className="w-full py-3 bg-surge-primary hover:bg-surge-secondary text-white rounded-lg font-medium transition-colors"
          >
            Close
          </button>
        </div>
      </div>
    </div>
  );
}
