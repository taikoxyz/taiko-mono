import { writable } from 'svelte/store'

export const openModal = writable(false)

export function open() {
  openModal.set(true)
}

export function close() {
  openModal.set(false)
}
