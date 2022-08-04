import { expect } from "chai"
import { ethers } from "hardhat"
import { BigNumber as EBN } from "ethers"

interface TxLegacy {
    txType: 0
    nonce: number
    gasPrice: number
    gasLimit: number
    destination: string
    amount: EBN
    data: Uint8Array
    v: number
    r: string
    s: string
}

interface AccessItem {
    addr: string
    slots: string[]
}

interface Tx2930 {
    txType: 1
    chainId: string
    nonce: number
    gasPrice: number
    gasLimit: number
    destination: string
    amount: EBN
    data: Uint8Array
    accessList: AccessItem[]
    signatureYParity: boolean
    signatureR: string
    signatureS: string
}

interface Tx1559 {
    txType: 2
    chainId: string
    nonce: number
    maxPriorityFeePerGas: number
    maxFeePerGas: number
    gasLimit: number
    destination: string
    amount: EBN
    data: Uint8Array
    accessList: AccessItem[]
    signatureYParity: boolean
    signatureR: string
    signatureS: string
}

type TxObj = TxLegacy | Tx2930 | Tx1559

describe("LibTxList", function () {
    let rlpWriter: any
    let libTxList: any

    before(async function () {
        rlpWriter = await (
            await ethers.getContractFactory("TestLib_RLPWriter")
        ).deploy()
        libTxList = await (
            await ethers.getContractFactory("LibTxList")
        ).deploy()
    })

    function randomBytes32() {
        return ethers.utils.hexlify(ethers.utils.randomBytes(32))
    }

    async function rlpEncodeTxLegacy(txLegacy: TxLegacy) {
        const txLegacyEncoded = []
        txLegacyEncoded.push(await rlpWriter.writeUint(txLegacy.nonce))
        txLegacyEncoded.push(await rlpWriter.writeUint(txLegacy.gasPrice))
        txLegacyEncoded.push(await rlpWriter.writeUint(txLegacy.gasLimit))
        txLegacyEncoded.push(await rlpWriter.writeAddress(txLegacy.destination))
        txLegacyEncoded.push(await rlpWriter.writeUint(txLegacy.amount))
        txLegacyEncoded.push(await rlpWriter.writeBytes(txLegacy.data))
        txLegacyEncoded.push(await rlpWriter.writeUint(txLegacy.v))
        txLegacyEncoded.push(await rlpWriter.writeUint(txLegacy.r))
        txLegacyEncoded.push(await rlpWriter.writeUint(txLegacy.s))

        // console.log('txLegacyEncoded: ', txLegacyEncoded);
        const txLegacyBytes = await rlpWriter.writeList(txLegacyEncoded)
        return txLegacyBytes
    }

    async function rlpEncodeAccessList(accessList: AccessItem[]) {
        const bytesArr = []
        for (const item of accessList) {
            const itemEncoded = []
            const slotsEncoded = []
            itemEncoded.push(await rlpWriter.writeAddress(item.addr))

            for (const slot of item.slots) {
                slotsEncoded.push(await rlpWriter.writeUint(slot))
            }
            itemEncoded.push(await rlpWriter.writeList(slotsEncoded))
            bytesArr.push(await rlpWriter.writeList(itemEncoded))
        }

        const accessListBytes = await rlpWriter.writeList(bytesArr)
        return accessListBytes
    }

    async function rlpEncodeTx2930(tx2930: Tx2930) {
        const tx2930Encoded = []
        tx2930Encoded.push(await rlpWriter.writeUint(tx2930.chainId))
        tx2930Encoded.push(await rlpWriter.writeUint(tx2930.nonce))
        tx2930Encoded.push(await rlpWriter.writeUint(tx2930.gasPrice))
        tx2930Encoded.push(await rlpWriter.writeUint(tx2930.gasLimit))
        tx2930Encoded.push(await rlpWriter.writeAddress(tx2930.destination))
        tx2930Encoded.push(await rlpWriter.writeUint(tx2930.amount))
        tx2930Encoded.push(await rlpWriter.writeBytes(tx2930.data))
        const accessListBytes = await rlpEncodeAccessList(tx2930.accessList)
        tx2930Encoded.push(await rlpWriter.writeBytes(accessListBytes))
        tx2930Encoded.push(await rlpWriter.writeBool(tx2930.signatureYParity))
        tx2930Encoded.push(await rlpWriter.writeUint(tx2930.signatureR))
        tx2930Encoded.push(await rlpWriter.writeUint(tx2930.signatureS))

        const tx2930Bytes = await rlpWriter.writeList(tx2930Encoded)

        const wrappedBytes = await rlpWriter.writeList([
            await rlpWriter.writeUint(tx2930.txType),
            tx2930Bytes,
        ])
        return wrappedBytes
    }

    async function rlpEncodeTx1559(tx1559: Tx1559) {
        const tx1559Encoded = []
        tx1559Encoded.push(await rlpWriter.writeUint(tx1559.chainId))
        tx1559Encoded.push(await rlpWriter.writeUint(tx1559.nonce))
        tx1559Encoded.push(
            await rlpWriter.writeUint(tx1559.maxPriorityFeePerGas)
        )
        tx1559Encoded.push(await rlpWriter.writeUint(tx1559.maxFeePerGas))
        tx1559Encoded.push(await rlpWriter.writeUint(tx1559.gasLimit))
        tx1559Encoded.push(await rlpWriter.writeAddress(tx1559.destination))
        tx1559Encoded.push(await rlpWriter.writeUint(tx1559.amount))
        tx1559Encoded.push(await rlpWriter.writeBytes(tx1559.data))
        const accessListBytes = await rlpEncodeAccessList(tx1559.accessList)
        tx1559Encoded.push(await rlpWriter.writeBytes(accessListBytes))
        tx1559Encoded.push(await rlpWriter.writeBool(tx1559.signatureYParity))
        tx1559Encoded.push(await rlpWriter.writeUint(tx1559.signatureR))
        tx1559Encoded.push(await rlpWriter.writeUint(tx1559.signatureS))

        const tx1559Bytes = await rlpWriter.writeList(tx1559Encoded)

        const wrappedBytes = await rlpWriter.writeList([
            await rlpWriter.writeUint(tx1559.txType),
            tx1559Bytes,
        ])
        return wrappedBytes
    }

    async function rlpEncodeTxList(txList: TxObj[]) {
        const bytesArr = []

        for (const tx of txList) {
            let bs: string = ""
            if (tx.txType === 0) {
                bs = await rlpEncodeTxLegacy(tx)
            } else if (tx.txType === 1) {
                bs = await rlpEncodeTx2930(tx)
            } else if (tx.txType === 2) {
                bs = await rlpEncodeTx1559(tx)
            } else {
                throw new Error("unsupported tx type:" + typeof tx)
            }

            bytesArr.push(bs)
        }
        const txListBytes = await rlpWriter.writeList(bytesArr)
        return txListBytes
    }

    describe("decodeTxList", function () {
        it("should revert if tx list is empty", async function () {
            const txList: TxObj[] = []
            const txListBytes = await rlpEncodeTxList(txList)
            await expect(
                libTxList.callStatic.decodeTxList(txListBytes)
            ).to.be.revertedWith("empty txList")
        })

        it("should revert with random bytes", async function () {
            const randomBytes = ethers.utils.hexlify(
                ethers.utils.randomBytes(73)
            )
            await expect(
                libTxList.callStatic.decodeTxList(randomBytes)
            ).to.be.revertedWith("Invalid RLP")
        })

        it("should be able to decode txList with single legacy transaction", async function () {
            const txLegacy: TxLegacy = {
                txType: 0,
                nonce: 1,
                gasPrice: 11e9,
                gasLimit: 123456,
                destination: ethers.Wallet.createRandom().address,
                amount: ethers.utils.parseEther("1.23"),
                data: ethers.utils.randomBytes(10),
                v: 1,
                r: randomBytes32(),
                s: randomBytes32(),
            }
            const txListBytes = await rlpEncodeTxList([txLegacy])

            const decodedTxList = await libTxList.callStatic.decodeTxList(
                txListBytes
            )
            // console.log('decodedT: ', decodedTxList)
            expect(decodedTxList.items.length).to.equal(1)
            const decodedTx1 = decodedTxList.items[0]
            expect(decodedTx1.gasLimit.toNumber()).to.equal(txLegacy.gasLimit)
        })

        it("should be able to decode txList with multiple legacy transaction", async function () {
            const txLegacy1: TxLegacy = {
                txType: 0,
                nonce: 1,
                gasPrice: 11e9,
                gasLimit: 123456,
                destination: ethers.Wallet.createRandom().address,
                amount: ethers.utils.parseEther("1.23"),
                data: ethers.utils.randomBytes(10),
                v: 1,
                r: randomBytes32(),
                s: randomBytes32(),
            }

            const txLegacy2: TxLegacy = {
                txType: 0,
                nonce: 2,
                gasPrice: 11e9,
                gasLimit: 456789,
                destination: ethers.Wallet.createRandom().address,
                amount: ethers.utils.parseEther("23.123"),
                data: ethers.utils.randomBytes(10),
                v: 2,
                r: randomBytes32(),
                s: randomBytes32(),
            }

            const txListBytes = await rlpEncodeTxList([txLegacy1, txLegacy2])

            const decodedTxList = await libTxList.callStatic.decodeTxList(
                txListBytes
            )
            // console.log('decoded: ', decodedTxList)
            expect(decodedTxList.items.length).to.equal(2)
            const decodedTx1 = decodedTxList.items[0]
            const decodedTx2 = decodedTxList.items[1]
            expect(decodedTx1.gasLimit.toNumber()).to.equal(txLegacy1.gasLimit)
            expect(decodedTx2.gasLimit.toNumber()).to.equal(txLegacy2.gasLimit)
        })
    })
})
