import { defaultWagmiConfig } from '@web3modal/wagmi';

import { PUBLIC_WALLETCONNECT_PROJECT_ID } from '$env/static/public';
import { chains } from '$lib/chain';

const projectId = PUBLIC_WALLETCONNECT_PROJECT_ID;

const metadata = {
  name: 'Taiko Trailblazer',
  description: 'Taiko Trailblazer',
  url: 'https://trailblazers.taiko.xyz/',
  icons: ['https://avatars.githubusercontent.com/u/99078433'],
};

export default function getConfig() {
  return defaultWagmiConfig({
    projectId,
    chains,
    metadata,
  });
}
