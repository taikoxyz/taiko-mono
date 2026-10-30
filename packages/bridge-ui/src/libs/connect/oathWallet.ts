import type { createWeb3Modal } from '@web3modal/wagmi';

type CustomWallets = NonNullable<Parameters<typeof createWeb3Modal>[0]['customWallets']>;

export function getOathWallets(userAgent = typeof navigator === 'undefined' ? '' : navigator.userAgent): CustomWallets {
  // Oath is iOS-only; desktop users connect by scanning the QR with their iPhone.
  if (/android/i.test(userAgent)) return [];
  return [
    {
      id: 'oath-wallet',
      name: 'Oath Wallet',
      homepage: 'https://oathwallet.org',
      image_url: '/oath-wallet.svg',
      mobile_link: 'oathwallet://',
      app_store: 'https://apps.apple.com/app/id6780187283',
    },
  ];
}
