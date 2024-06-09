package eventindexer

import (
	"context"
	"database/sql/driver"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"

	"github.com/morkid/paginate"
)

type Attribute struct {
	TraitType string `json:"trait_type"`
	Value     string `json:"value"`
}

type Attributes []Attribute

func (a Attributes) Value() (driver.Value, error) {
	// Convert Attributes to JSON
	return json.Marshal(a)
}

func (a *Attributes) Scan(value interface{}) error {
	// Convert JSON to Attributes
	bytes, ok := value.([]byte)
	if !ok {
		return errors.New("type assertion to []byte failed")
	}

	return json.Unmarshal(bytes, a)
}

type NFTMetadata struct {
	ID              int        `json:"id"`
	ContractAddress string     `json:"contract_address"`
	TokenID         string     `json:"token_id"`
	Name            string     `json:"name,omitempty"`
	Description     string     `json:"description,omitempty"`
	Symbol          string     `json:"symbol,omitempty"`
	Attributes      Attributes `json:"attributes,omitempty"`
	ImageURL        string     `json:"image_url,omitempty"`
}

type NFTMetadataRepository interface {
	SaveNFTMetadata(ctx context.Context, metadata *NFTMetadata) (*NFTMetadata, error)
	GetNFTMetadata(ctx context.Context, contractAddress string, tokenID string) (*NFTMetadata, error)
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
