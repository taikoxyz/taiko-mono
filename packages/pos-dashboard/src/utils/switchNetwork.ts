import { switchNetwork as wagmiSwitchNetwork } from 'wagmi/actions';

export async function switchNetwork(chainId: number) {
  await wagmiSwitchNetwork({ chainId });
}
