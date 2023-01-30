import { BigNumber, Contract, ethers } from "ethers";
import TaikoL1 from "../constants/abi/TaikoL1";

export const getConfig = async (
  provider: ethers.providers.JsonRpcProvider,
  contractAddress: string
): Promise<{
  chainId: BigNumber;
  maxNumBlocks: BigNumber;
  blockHashHistory: BigNumber;
  zkProofsPerBlock: BigNumber;
  maxVerificationsPerTx: BigNumber;
  commitConfirmations: BigNumber;
  maxProofsPerForkChoice: BigNumber;
  blockMaxGasLimit: BigNumber;
  maxTransactionsPerBlock: BigNumber;
  maxBytesPerTxList: BigNumber;
  minTxGasLimit: BigNumber;
  anchorTxGasLimit: BigNumber;
  feePremiumLamda: BigNumber;
  rewardBurnBips: BigNumber;
  proposerDepositPctg: BigNumber;
  feeBaseMAF: BigNumber;
  blockTimeMAF: BigNumber;
  proofTimeMAF: BigNumber;
  rewardMultiplierPctg: BigNumber;
  feeGracePeriodPctg: BigNumber;
  feeMaxPeriodPctg: BigNumber;
  blockTimeCap: BigNumber;
  proofTimeCap: BigNumber;
  bootstrapDiscountHalvingPeriod: BigNumber;
  initialUncleDelay: BigNumber;
  enableTokenomics: boolean;
  enablePublicInputsCheck: boolean;
  enableProofValidation: boolean;
}> => {
  const contract: Contract = new Contract(contractAddress, TaikoL1, provider);
  return await contract.getConfig();
};
