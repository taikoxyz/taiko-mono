type Message = {
    id: number
    sender: string
    srcChainId: number
    destChainId: number
    owner: string
    to: string
    refundAddress: string
    depositValue: number
    callValue: number
    processingFee: number
    gasLimit: number
    data: string
    memo: string
}

export { Message }
