import { Buffer } from 'buffer';

export const decodeBase64ToJson = (base64: string) => {
  return JSON.parse(Buffer.from(base64, 'base64').toString('utf-8'));
};
