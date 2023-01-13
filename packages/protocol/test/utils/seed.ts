import { BigNumber, ethers } from "ethers";

const createAndSeedWallets = async (
    len: number,
    signer: any,
    amount: BigNumber = ethers.utils.parseEther("1")
): Promise<ethers.Wallet[]> => {
    const wallets: ethers.Wallet[] = [];
    for (let i = 0; i < len; i++) {
        const wallet = ethers.Wallet.createRandom().connect(signer.provider);
        const tx = await signer.sendTransaction({
            to: await wallet.getAddress(),
            value: amount,
        });

        await tx.wait(1);
        wallets.push(wallet);
    }

    return wallets;
};

export default createAndSeedWallets;
