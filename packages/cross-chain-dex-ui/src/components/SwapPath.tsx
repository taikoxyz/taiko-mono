import { SwapDirection } from '../types';
import { ETH_TOKEN, USDC_TOKEN } from '../lib/constants';

interface SwapPathProps {
  direction: SwapDirection;
  show: boolean;
}

export function SwapPath({ direction, show }: SwapPathProps) {
  if (!show) return null;

  const inputToken = direction === 'ETH_TO_USDC' ? ETH_TOKEN : USDC_TOKEN;
  const outputToken = direction === 'ETH_TO_USDC' ? USDC_TOKEN : ETH_TOKEN;

  return (
    <div className="bg-surge-dark/50 rounded-xl p-4 border border-surge-border/30">
      <div className="text-xs text-gray-500 mb-3 text-center">Swap Route</div>

      {/* Icons Row - all vertically centered */}
      <div className="flex items-center">
        {/* Input Token */}
        <div className="flex flex-col items-center flex-shrink-0 w-10">
          <div className="w-10 h-10 rounded-full bg-surge-card border border-surge-border/50 flex items-center justify-center">
            <img src={inputToken.logo} alt={inputToken.symbol} className="w-6 h-6" />
          </div>
          <span className="text-[10px] text-gray-400 mt-1">{inputToken.symbol}</span>
        </div>

        {/* Bridge Line to L2 */}
        <div className="flex-1 flex items-center mx-1 relative self-start mt-5">
          <div className="flex-1 h-[2px] bg-gradient-to-r from-emerald-500/50 to-cyan-500/50" />
          <div className="w-0 h-0 border-t-[5px] border-t-transparent border-b-[5px] border-b-transparent border-l-[7px] border-l-cyan-500/70" />
          <span className="absolute -bottom-4 left-1/2 -translate-x-1/2 text-[9px] text-gray-500">bridge</span>
        </div>

        {/* DEX Icon */}
        <div className="flex flex-col items-center flex-shrink-0 w-10">
          <div className="w-10 h-10 rounded-lg bg-gradient-to-br from-emerald-500/20 to-cyan-500/20 border border-emerald-500/30 flex items-center justify-center">
            <svg className="w-5 h-5 text-emerald-400" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <path d="M7 16V4M7 4L3 8M7 4L11 8M17 8V20M17 20L21 16M17 20L13 16" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
          </div>
          <span className="text-[10px] text-gray-400 mt-1">DEX</span>
        </div>

        {/* Bridge Line back to L1 */}
        <div className="flex-1 flex items-center mx-1 relative self-start mt-5">
          <div className="flex-1 h-[2px] bg-gradient-to-r from-cyan-500/50 to-emerald-500/50" />
          <div className="w-0 h-0 border-t-[5px] border-t-transparent border-b-[5px] border-b-transparent border-l-[7px] border-l-emerald-500/70" />
          <span className="absolute -bottom-4 left-1/2 -translate-x-1/2 text-[9px] text-gray-500">bridge</span>
        </div>

        {/* Output Token */}
        <div className="flex flex-col items-center flex-shrink-0 w-10">
          <div className="w-10 h-10 rounded-full bg-surge-card border border-surge-border/50 flex items-center justify-center">
            <img src={outputToken.logo} alt={outputToken.symbol} className="w-6 h-6" />
          </div>
          <span className="text-[10px] text-gray-400 mt-1">{outputToken.symbol}</span>
        </div>
      </div>

      {/* L1/L2 Labels Row */}
      <div className="flex items-start mt-4">
        <div className="w-10 flex justify-center flex-shrink-0">
          <span className="text-[11px] text-emerald-500 font-bold">L1</span>
        </div>
        <div className="flex-1" />
        <div className="w-10 flex justify-center flex-shrink-0">
          <span className="text-[11px] text-cyan-500 font-bold">L2</span>
        </div>
        <div className="flex-1" />
        <div className="w-10 flex justify-center flex-shrink-0">
          <span className="text-[11px] text-emerald-500 font-bold">L1</span>
        </div>
      </div>
    </div>
  );
}
