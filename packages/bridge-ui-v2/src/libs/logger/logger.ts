import debug from 'debug'

export function getLogger(namespace: string) {
  const log = debug(`bridge:${namespace}`)
  const logerr = debug(`bridge:${namespace}:error`)
  return { log, logerr }
}
