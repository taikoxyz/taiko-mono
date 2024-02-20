import debug from 'debug';

export function getLogger(namesapce: string) {
  return debug(`bridge:${namesapce}`);
}
