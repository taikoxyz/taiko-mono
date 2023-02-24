import { BigNumber, ethers } from "ethers";
import { TestTaikoToken } from "../../typechain";

const createAndSeedWallets = async (
    len: number,
    signer: any,
    amount: BigNumber = ethers.utils.parseEther("1")
): Promise<ethers.Wallet[]> => {
    const wallets: ethers.Wallet[] = [];
    for (let i = 0; i < len; i++) {
        const wallet = ethers.Wallet.createRandom({
            extraEntropy: ethers.utils.randomBytes(32),
        }).connect(signer.provider);
        const tx = await signer.sendTransaction({
            to: await wallet.getAddress(),
            value: amount,
        });

        await tx.wait(1);
        wallets.push(wallet);
    }

    return wallets;
};

const sendTinyEtherToZeroAddress = async (signer: any) => {
    const tx = await signer.sendTransaction({
        to: ethers.constants.AddressZero,
        value: BigNumber.from(1),
    });
    await tx.wait(1);
};

const seedTko = async (
    wallets: { getSigner: () => ethers.Wallet }[],
    taikoToken: TestTaikoToken
) => {
    for (const wallet of wallets) {
        // prover needs TKO or their reward will be cut down to 1 wei.
        await (
            await taikoToken.mintAnyone(
                await wallet.getSigner().getAddress(),
                ethers.utils.parseEther("100")
            )
        ).wait(1);
    }
};

export { createAndSeedWallets, sendTinyEtherToZeroAddress, seedTko };
