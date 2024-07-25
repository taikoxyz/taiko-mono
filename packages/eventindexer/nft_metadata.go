package eventindexer

import (
	"context"
	"database/sql/driver"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strconv"

	"github.com/morkid/paginate"
)

type Attribute struct {
	TraitType string `json:"trait_type"`
	Value     string `json:"value"`
}

type Attributes []Attribute

type NFTMetadata struct {
	ID              int        `json:"id"`
	ChainID         int64      `json:"chain_id"`
	ContractAddress string     `json:"contract_address"`
	TokenID         int64      `json:"token_id"`
	Name            string     `json:"name,omitempty"`
	Description     string     `json:"description,omitempty"`
	Symbol          string     `json:"symbol,omitempty"`
	Attributes      Attributes `json:"attributes,omitempty"`
	ImageURL        string     `json:"image_url,omitempty"`
	ImageData       string     `json:"image_data,omitempty"`
}

type NFTMetadataRepository interface {
	SaveNFTMetadata(ctx context.Context, metadata *NFTMetadata) (*NFTMetadata, error)
	GetNFTMetadata(ctx context.Context, contractAddress string, tokenID int64, chainID int64) (*NFTMetadata, error)
	FindByContractAddress(ctx context.Context, req *http.Request, contractAddress string) (paginate.Page, error)
}

func (n *NFTMetadata) UnmarshalJSON(data []byte) error {
	type Alias NFTMetadata

	aux := &struct {
		ImageURL string `json:"image_url"`
		Image    string `json:"image"`
		*Alias
	}{
		Alias: (*Alias)(n),
	}

	if err := json.Unmarshal(data, &aux); err != nil {
		return fmt.Errorf("failed to unmarshal JSON: %v", err)
	}

	if aux.ImageURL != "" {
		n.ImageURL = aux.ImageURL
	} else {
		n.ImageURL = aux.Image
	}

	return nil
}

func (a Attributes) Value() (driver.Value, error) {
	return json.Marshal(a)
}

func (a *Attributes) Scan(value interface{}) error {
	bytes, ok := value.([]byte)
	if !ok {
		return errors.New("type assertion to []byte failed")
	}

	return json.Unmarshal(bytes, a)
}

func (a *Attribute) UnmarshalJSON(data []byte) error {
	type Alias Attribute

	aux := &struct {
		Value interface{} `json:"value"`
		*Alias
	}{
		Alias: (*Alias)(a),
	}

	if err := json.Unmarshal(data, &aux); err != nil {
		return err
	}

	switch v := aux.Value.(type) {
	case string:
		a.Value = v
	case float64:
		a.Value = strconv.FormatFloat(v, 'f', -1, 64)
	default:
		return fmt.Errorf("unexpected type for value field: %T", aux.Value)
	}

	return nil
}
