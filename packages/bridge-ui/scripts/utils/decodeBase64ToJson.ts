import { Buffer } from 'buffer';

export const decodeBase64ToJson = (base64: string) => {
  try {
    const decodedString = Buffer.from(base64, 'base64').toString('utf-8');
    return JSON.parse(decodedString);
  } catch (error) {
    throw new Error('Failed to decode and parse JSON from base64: ' + (error as Error).message);
  }
};
