import { BigNumber, Contract, ethers } from 'ethers';
import type { Prover } from '../domain/prover';
import type { Staker } from '../domain/staker';
import ProverPool from '../constants/abi/ProverPool';

export const getProverInfo = async (
  provider: ethers.providers.JsonRpcProvider,
  contractAddress: string,
  userAddress: string,
): Promise<{ prover: Prover; staker: Staker }> => {
  const contract: Contract = new Contract(
    contractAddress,
    ProverPool,
    provider,
  );
  const staker = await contract.getStaker(userAddress);

  const resp: { prover: Prover; staker: Staker } = {
    staker: staker,
    prover: {
      currentCapacity: 0,
      address: '',
      amountStaked: BigNumber.from(0),
    },
  };

  if (staker.proverId !== 0) {
    const prover = await contract.proverIdToAddress(staker.proverId);
    resp.prover = prover;
  }
  return resp;
};
