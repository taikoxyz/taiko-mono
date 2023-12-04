import { Contract, ethers } from "ethers";
import TaikoL1 from "../constants/abi/TaikoL1";

export const getProposers = async (
  provider: ethers.providers.JsonRpcProvider,
  contractAddress: string
): Promise<number> => {
  const contract: Contract = new Contract(contractAddress, TaikoL1, provider);
  const events = await getAllEvents(contract, provider);

  const uniqueProposers = getUniqueProposers(events);

  return uniqueProposers.length;
};

const getAllEvents = async (contract: Contract, provider: ethers.providers.JsonRpcProvider) => {
  const events = [];
  const latestBlock = await provider.getBlockNumber();
  const batchSize = 1000;
  for (let i = 0; i < latestBlock; i += batchSize) {
    const end = i + batchSize > latestBlock ? latestBlock : i + batchSize;
    const filteredEvents = await contract.queryFilter("BlockProposed", i, end);
    events.push(...filteredEvents);
  }
  return events;
};

const getUniqueProposers = (events: any[]) => {
  const uniqueProposers = [];
  events.forEach((event) => {
    if (!uniqueProposers.includes(event.args.meta.beneficiary)) {
      uniqueProposers.push(event.args.meta.beneficiary);
    }
  });
  return uniqueProposers;
};
