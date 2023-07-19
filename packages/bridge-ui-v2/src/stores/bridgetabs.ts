import { derived, get, writable } from 'svelte/store';

function persistentWritable(key: string, startValue: string) {
  const savedValue = localStorage.getItem(key);
  const initialValue = savedValue === null ? startValue : JSON.parse(savedValue);
  const store = writable(initialValue);
  store.subscribe(($value) => localStorage.setItem(key, JSON.stringify($value)));

  return store;
}

export const activeTab = persistentWritable('activeTab', 'erc20_tab');

export const isActive = derived(activeTab, ($activeTab) => (tabName: string) => $activeTab === tabName);

export function checkIsActive(tabName: string): boolean {
  const checkActiveTab = get(isActive);
  return checkActiveTab(tabName);
}
