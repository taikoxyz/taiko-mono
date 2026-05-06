import { sideNavigationTabs } from './navigationItems';

test('includes the relayer tab between bridge and transactions', () => {
  expect(sideNavigationTabs.map((tab) => tab.href)).toEqual(['/', '/relayer', '/transactions']);
  expect(sideNavigationTabs[1]).toMatchObject({
    href: '/relayer',
    icon: 'relayer',
    label: 'nav.relayer',
  });
});
