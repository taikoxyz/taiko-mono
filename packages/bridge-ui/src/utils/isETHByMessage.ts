import type { Message } from '../domain/message';

export function isETHByMessage(message?: Message): boolean {
  return message?.data === '0x' || !message?.data;
}
