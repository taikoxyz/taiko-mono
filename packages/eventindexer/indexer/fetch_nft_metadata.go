package indexer

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"math/big"
	"net/http"
	"net/url"
	"strings"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common"
	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/contracts/erc1155"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/contracts/erc721"
)

func (i *Indexer) fetchNFTMetadata(
	ctx context.Context, contractAddress string,
	tokenID *big.Int,
	abiJSON string,
	methodName string,
	chainID *big.Int) (*eventindexer.NFTMetadata, error) {
	contractABI, err := abi.JSON(strings.NewReader(abiJSON))
	if err != nil {
		return nil, err
	}

	contractAddressCommon := common.HexToAddress(contractAddress)

	callData, err := contractABI.Pack(methodName, tokenID)
	if err != nil {
		return nil, err
	}

	msg := ethereum.CallMsg{
		To:   &contractAddressCommon,
		Data: callData,
	}

	result, err := i.ethClient.CallContract(ctx, msg, nil)
	if err != nil {
		return nil, errors.Wrap(err, "i.ethClient.CallContract")
	}

	var tokenURI string

	err = contractABI.UnpackIntoInterface(&tokenURI, methodName, result)
	if err != nil {
		return nil, errors.Wrap(err, "contractABI.UnpackIntoInterface")
	}

	mdURL := resolveMetadataURL(tokenURI)

	if !isValidURL(mdURL) {
		return nil, nil
	}

	var metadata *eventindexer.NFTMetadata

	//nolint
	resp, err := http.Get(mdURL)
	if err != nil {
		return nil, err
	}

	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, nil
	}

	err = json.NewDecoder(resp.Body).Decode(&metadata)
	if err != nil {
		return nil, err
	}

	if methodName == "tokenURI" {
		if err := i.fetchSymbol(ctx, contractABI, metadata, contractAddressCommon); err != nil {
			return nil, err
		}
	}

	metadata.ContractAddress = contractAddress
	metadata.TokenID = tokenID.Int64()
	metadata.ChainID = chainID.Int64()

	return metadata, nil
}

// isValidURL checks if the given string is a valid URL
func isValidURL(str string) bool {
	u, err := url.Parse(str)
	if err != nil || u.Scheme == "" || u.Host == "" {
		return false
	}

	return true
}

// isBase64 checks if the given string is a valid base64 encoded string
func isBase64(str string) bool {
	if !strings.Contains(str, "base64,") {
		return false
	}

	parts := strings.Split(str, "base64,")
	if len(parts) != 2 {
		return false
	}

	_, err := base64.StdEncoding.DecodeString(parts[1])

	return err == nil
}

func resolveMetadataURL(tokenURI string) string {
	if strings.HasPrefix(tokenURI, "ipfs://") {
		ipfsHash := strings.TrimPrefix(tokenURI, "ipfs://")
		resolvedURL := fmt.Sprintf("https://ipfs.io/ipfs/%s", ipfsHash)

		return resolvedURL
	}

	if isBase64(tokenURI) {
		parts := strings.Split(tokenURI, "base64,")

		decodedTokenURI, _ := base64.StdEncoding.DecodeString(parts[1])

		return string(decodedTokenURI)
	}

	return tokenURI
}

func (i *Indexer) fetchSymbol(ctx context.Context, contractABI abi.ABI, metadata *eventindexer.NFTMetadata, contractAddress common.Address) error {
	symbolCallData, err := contractABI.Pack("symbol")
	if err != nil {
		return errors.Wrap(err, "contractABI.Pack")
	}

	symbolMsg := ethereum.CallMsg{
		To:   &contractAddress,
		Data: symbolCallData,
	}

	symbolResult, err := i.ethClient.CallContract(ctx, symbolMsg, nil)
	if err != nil {
		return errors.Wrap(err, "i.ethClient.CallContract(symbolMsg)")
	}

	var symbol string

	err = contractABI.UnpackIntoInterface(&symbol, "symbol", symbolResult)
	if err != nil {
		return errors.Wrap(err, "contractABI.UnpackIntoInterface")
	}

	metadata.Symbol = symbol

	return nil
}

func (i *Indexer) fetchERC721Metadata(ctx context.Context,
	contractAddress string,
	tokenID *big.Int,
	chainID *big.Int) (*eventindexer.NFTMetadata, error) {
	return i.fetchNFTMetadata(ctx, contractAddress, tokenID, erc721.ABI, "tokenURI", chainID)
}

func (i *Indexer) fetchERC1155Metadata(ctx context.Context,
	contractAddress string,
	tokenID *big.Int,
	chainID *big.Int) (*eventindexer.NFTMetadata, error) {
	return i.fetchNFTMetadata(ctx, contractAddress, tokenID, erc1155.ABI, "uri", chainID)
}
