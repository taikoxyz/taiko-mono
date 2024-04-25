import debug from 'debug'

export function getLogger(namesapce: string) {
    return debug(`nft-lab:${namesapce}`)
}
