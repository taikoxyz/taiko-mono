import { chainConfig } from '$chainConfig';
import { PUBLIC_SLOW_L1_BRIDGING_WARNING } from '$env/static/public';

import { LayerType } from './types';

/**
 * @dev Whether a transfer to this chain is the slow direction. An L2 -> L1 message can only
 *      be claimed once the L2 state it was sent from is proven on L1, which takes hours rather
 *      than minutes, and a deployment asks for that to be said by setting
 *      PUBLIC_SLOW_L1_BRIDGING_WARNING (any non-empty value: the env is a string, so this
 *      keeps the truthiness the review steps always had). The review-step warning and the
 *      confirmation-step copy both read this one expression, so those screens cannot
 *      disagree about which direction is slow.
 * @param destChainId The destination chain, if one is selected
 * @return slow_ Whether the slow-L1 copy applies to this destination
 */
export const isSlowL1Bridging = (destChainId?: number): boolean =>
  !!PUBLIC_SLOW_L1_BRIDGING_WARNING && !!destChainId && chainConfig[destChainId]?.type === LayerType.L1;
