import { watchAccount, watchNetwork } from '@wagmi/core'

import { startWatching, stopWatching } from './watcher'

vi.mock('@wagmi/core', () => ({
  watchNetwork: vi.fn(),
  watchAccount: vi.fn(),
}))

const mockUnwatchNetwork = vi.fn()
const mockUnwatchAccount = vi.fn()

describe('wagmi watcher', () => {
  beforeEach(() => {
    vi.mocked(watchAccount).mockReset().mockReturnValue(mockUnwatchNetwork)
    vi.mocked(watchNetwork).mockReset().mockReturnValue(mockUnwatchAccount)
  })
  it('should start watching', () => {
    startWatching()

    expect(watchNetwork).toHaveBeenCalledTimes(1)
    expect(watchAccount).toHaveBeenCalledTimes(1)

    startWatching()

    expect(watchNetwork).toHaveBeenCalledTimes(1)
    expect(watchAccount).toHaveBeenCalledTimes(1)
  })

  it('should stop watching', () => {
    startWatching()

    expect(mockUnwatchNetwork).not.toHaveBeenCalled()
    expect(mockUnwatchAccount).not.toHaveBeenCalled()

    stopWatching()

    expect(mockUnwatchNetwork).toHaveBeenCalled()
    expect(mockUnwatchAccount).toHaveBeenCalled()
  })
})
