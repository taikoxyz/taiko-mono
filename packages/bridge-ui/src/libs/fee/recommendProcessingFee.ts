import { NoCanonicalInfoFoundError } from '$libs/error';
import { relayerApiServices } from '$libs/relayer';
import { FeeTypes } from '$libs/relayer/types';
import { type Token, TokenType } from '$libs/token';
import { getTokenAddresses } from '$libs/token/getTokenAddresses';
import { getLogger } from '$libs/util/logger';

const log = getLogger('libs:recommendedProcessingFee');

type RecommendProcessingFeeArgs = {
  token: Token;
  destChainId: number;
  srcChainId?: number;
};

export async function recommendProcessingFee({
  token,
  destChainId,
  srcChainId,
}: RecommendProcessingFeeArgs): Promise<bigint> {
  if (!srcChainId) {
    return 0n;
  }

  let fee;

  if (token.type !== TokenType.ETH) {
    const tokenInfo = await getTokenAddresses({ token, srcChainId, destChainId });
    if (!tokenInfo) throw new NoCanonicalInfoFoundError();

    let isTokenAlreadyDeployed = false;

    if (tokenInfo.bridged) {
      const { address } = tokenInfo.bridged;
      if (address) {
        isTokenAlreadyDeployed = true;
      }
    }
    if (token.type === TokenType.ERC20) {
      if (isTokenAlreadyDeployed) {
        log(`token ${token.symbol} is already deployed on chain ${destChainId}`);

        fee = await relayerApiServices[0].recommendedProcessingFees({
          typeFilter: FeeTypes.Erc20Deployed,
          destChainIDFilter: destChainId,
        });
      } else {
        fee = await relayerApiServices[0].recommendedProcessingFees({
          typeFilter: FeeTypes.Erc20NotDeployed,
          destChainIDFilter: destChainId,
        });
        log(`token ${token.symbol} is not deployed on chain ${destChainId}`);
      }
    } else if (token.type === TokenType.ERC721) {
      if (isTokenAlreadyDeployed) {
        log(`token ${token.symbol} is already deployed on chain ${destChainId}`);
        fee = await relayerApiServices[0].recommendedProcessingFees({
          typeFilter: FeeTypes.Erc721Deployed,
          destChainIDFilter: destChainId,
        });
      } else {
        log(`token ${token.symbol} is not deployed on chain ${destChainId}`);
        fee = await relayerApiServices[0].recommendedProcessingFees({
          typeFilter: FeeTypes.Erc721NotDeployed,
          destChainIDFilter: destChainId,
        });
      }
    } else if (token.type === TokenType.ERC1155) {
      if (isTokenAlreadyDeployed) {
        log(`token ${token.symbol} is already deployed on chain ${destChainId}`);
        fee = await relayerApiServices[0].recommendedProcessingFees({
          typeFilter: FeeTypes.Erc1155Deployed,
          destChainIDFilter: destChainId,
        });
      } else {
        log(`token ${token.symbol} is not deployed on chain ${destChainId}`);
        fee = await relayerApiServices[0].recommendedProcessingFees({
          typeFilter: FeeTypes.Erc1155NotDeployed,
          destChainIDFilter: destChainId,
        });
      }
    }
  } else {
    log(`Fee for ETH bridging`);
    fee = await relayerApiServices[0].recommendedProcessingFees({
      typeFilter: FeeTypes.Eth,
      destChainIDFilter: destChainId,
    });
  }
  if (!fee) throw new Error('Unable to get fee from relayer API');

  const feeInWei = BigInt(fee[0].amount);
  log(`Recommended fee: ${feeInWei.toString()}`);
  return feeInWei;
}
