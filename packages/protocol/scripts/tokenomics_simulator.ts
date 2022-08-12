const assert = require("assert")

const FEE_PREMIUM_BLOCK_THRESHOLD = 256
const FEE_ADJUSTMENT_FACTOR = 32
const PROVING_DELAY_AVERAGING_FACTOR = 64
const FEE_PREMIUM_MAX_MUTIPLIER = 4
const FEE_TOTAL_MAX_MULTIPLIER = 100
const FEE_BIPS = 500 // 5%
const MILIS_PER_SECOND = 1e3
const GAS_LIMIT_BASE = 1000000

let _avgNumUnprovenBlocks = 0
let _avgProvingDelay = 0
let suggestedGasPrice = 0

function getRandomInt(max: number) {
    return Math.floor(Math.random() * max)
}

function adjustTargetReverse(
    prevTarget: number,
    prevMeasured: number,
    T: number,
    A: number
) {
    assert(prevTarget !== 0 && T !== 0 && A > 1)

    const x = prevTarget * A * T
    const y = (A - 1) * T + prevMeasured
    let nextTarget = x / y

    if (nextTarget === 0) {
        nextTarget = prevTarget
    }

    return nextTarget
}

function getProposerGasPrice(numUnprovenBlocks: number) {
    const threshold = Math.max(
        FEE_PREMIUM_BLOCK_THRESHOLD,
        _avgNumUnprovenBlocks
    )
    if (numUnprovenBlocks <= threshold) {
        return suggestedGasPrice
    } else {
        let premium = (10000 * numUnprovenBlocks) / (2 * threshold)
        premium = Math.min(FEE_PREMIUM_MAX_MUTIPLIER * 10000, premium)
        return Math.floor((suggestedGasPrice * premium) / 10000)
    }
}

function updateAverage(avg: number, current: number, factor: number) {
    if (current === 0) return avg
    if (avg === 0) return current

    return Math.floor(((factor - 1) * avg + current) / factor)
}

function calculateProverFees(
    proposerFee: number,
    provingDelay: number,
    provers: string[]
) {
    const size = provers.length
    assert(size > 0 && size <= 10, "invalid provers")

    const proverFees: number[] = []
    const totalFees = _calcTotalProverFee(proposerFee, provingDelay)
    const tenPctg = Math.floor(totalFees / 10)

    proverFees.push(tenPctg * (11 - size))
    for (let i = 1; i < size; i++) {
        proverFees.push(tenPctg)
    }

    return {
        proverFees,
        totalFees,
    }
}

function _calcTotalProverFee(proposerFee: number, provingDelay: number) {
    const a = _avgProvingDelay // threshold
    const t = provingDelay * MILIS_PER_SECOND
    const f = (proposerFee * (10000 - FEE_BIPS)) / 10000 // feeBaseline
    return t > a
        ? Math.min((f * t) / a + f / 2, FEE_TOTAL_MAX_MULTIPLIER * f)
        : f
}

function simulateFees() {
    suggestedGasPrice = 1e9

    console.log(
        "Height|unprovenBlocks|proposerGasPrice|proposeFee|provingDelay|proverFee|"
    )
    console.log("---|---|---|---|---|---")

    const rounds = 1000
    for (let i = 0; i < rounds; i++) {
        const unprovenBlocks = getRandomInt(100)
        const proposerGasPrice = getProposerGasPrice(unprovenBlocks)
        const gasLimit = getRandomInt(1000000) + GAS_LIMIT_BASE
        const proposeFee = proposerGasPrice * gasLimit

        const provingDelay = 60 + getRandomInt(60)

        const { totalFees: totalProverFee } = calculateProverFees(
            proposeFee,
            provingDelay,
            ["0x0"]
        )

        _avgNumUnprovenBlocks = updateAverage(
            _avgNumUnprovenBlocks,
            unprovenBlocks,
            512
        )

        _avgProvingDelay = updateAverage(
            _avgProvingDelay,
            provingDelay,
            PROVING_DELAY_AVERAGING_FACTOR
        )

        suggestedGasPrice = adjustTargetReverse(
            suggestedGasPrice,
            (proposeFee * 1000000) / totalProverFee,
            1000000,
            FEE_ADJUSTMENT_FACTOR
        )

        console.log(
            [
                i,
                unprovenBlocks,
                (proposerGasPrice / 1e9).toFixed(2) + "gwei",
                (proposeFee / 1e18).toFixed(2),
                provingDelay,
                (totalProverFee / 1e18).toFixed(2),
            ].join("|")
        )
    }
}

simulateFees()
