import type { IconType } from '$components/Icon/Icon.svelte';

export type SideNavigationTab = {
  href: string;
  icon: IconType;
  label: string;
  routeId: string;
};

export const sideNavigationTabs: SideNavigationTab[] = [
  {
    href: '/',
    icon: 'bridge',
    label: 'nav.bridge',
    routeId: '/',
  },
  {
    href: '/relayer',
    icon: 'relayer',
    label: 'nav.relayer',
    routeId: '/relayer',
  },
  {
    href: '/transactions',
    icon: 'transactions',
    label: 'nav.transactions',
    routeId: '/transactions',
  },
];
