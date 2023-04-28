import { writable } from 'svelte/store'

// Private to the component
export const openModal = writable(false)

export function open() {
  openModal.set(true)
}

export function close() {
  openModal.set(false)
}
