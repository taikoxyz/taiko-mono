package model

type Transaction struct {
	To                     *AddressParam            `json:"to"`
	CreatedContract        *AddressParam            `json:"created_contract"`
	Hash                   string                   `json:"hash"`
	Result                 string                   `json:"result"`
	Confirmations          int                      `json:"confirmations"`
	Status                 *string                  `json:"status"`
	Block                  *int                     `json:"block"`
	Timestamp              *string                  `json:"timestamp"`
	ConfirmationDuration   []int                    `json:"confirmation_duration"`
	From                   AddressParam             `json:"from"`
	Value                  string                   `json:"value"`
	Fee                    Fee                      `json:"fee"`
	GasPrice               string                   `json:"gas_price"`
	Type                   *int                     `json:"type"`
	GasUsed                *uint64                  `json:"gas_used"`
	GasLimit               uint64                   `json:"gas_limit"`
	MaxFeePerGas           *string                  `json:"max_fee_per_gas"`
	MaxPriorityFeePerGas   *string                  `json:"max_priority_fee_per_gas"`
	PriorityFee            *string                  `json:"priority_fee"`
	BaseFeePerGas          *string                  `json:"base_fee_per_gas"`
	TxBurntFee             *string                  `json:"tx_burnt_fee"`
	Nonce                  int                      `json:"nonce"`
	Position               *uint                    `json:"position"`
	RevertReason           *TransactionRevertReason `json:"revert_reason"`
	RawInput               string                   `json:"raw_input"`
	DecodedInput           *DecodedInput            `json:"decoded_input"`
	TokenTransfers         *[]TokenTransfer         `json:"token_transfers"`
	TokenTransfersOverflow bool                     `json:"token_transfers_overflow"`
	ExchangeRate           string                   `json:"exchange_rate"`
	Method                 *string                  `json:"method"`
	TxTypes                []TransactionType        `json:"tx_types"`
	TxTag                  *string                  `json:"tx_tag"`
	Actions                []TxAction               `json:"actions"`
	L1Fee                  *string                  `json:"l1_fee"`
	L1FeeScalar            *string                  `json:"l1_fee_scalar"`
	L1GasPrice             *string                  `json:"l1_gas_price"`
	L1GasUsed              *string                  `json:"l1_gas_used"`
	HasErrorInInternalTxs  *bool                    `json:"has_error_in_internal_txs"`
}

type TransactionRevertReason struct {
	Raw string `json:"raw"`
}

type Fee struct {
	Type  string `json:"type"`
	Value string `json:"value"`
}

type TransactionType string

const (
	TxTypeTokenTransfer    TransactionType = "token_transfer"
	TxTypeContractCreation TransactionType = "contract_creation"
	TxTypeContractCall     TransactionType = "contract_call"
	TxTypeTokenCreation    TransactionType = "token_creation"
	TxTypeCoinTransfer     TransactionType = "coin_transfer"
)

type AddressParam struct {
	UserTags
	Hash               string  `json:"hash"`
	ImplementationName *string `json:"implementation_name"`
	Name               *string `json:"name"`
	IsContract         bool    `json:"is_contract"`
	IsVerified         *bool   `json:"is_verified"`
}

type DecodedInput struct {
	// Define fields as needed
}

type TxAction struct {
	// Define fields as needed
}

type UserTags struct {
	// Define fields as needed
}

type TokenTransfer struct {
	Token     TokenInfo    `json:"token"`
	Total     TokenTotal   `json:"total"`
	Type      string       `json:"type"`
	TxHash    string       `json:"tx_hash"`
	From      AddressParam `json:"from"`
	To        AddressParam `json:"to"`
	Timestamp string       `json:"timestamp"`
	BlockHash string       `json:"block_hash"`
	LogIndex  string       `json:"log_index"`
	Method    *string      `json:"method,omitempty"`
}

type TokenInfo struct {
	Type string `json:"type"`
	// Add other fields as necessary
}

type TokenTotal struct {
	Erc20TotalPayload   *Erc20TotalPayload   `json:"erc20_total_payload,omitempty"`
	Erc721TotalPayload  *Erc721TotalPayload  `json:"erc721_total_payload,omitempty"`
	Erc1155TotalPayload *Erc1155TotalPayload `json:"erc1155_total_payload,omitempty"`
}

type Erc20TotalPayload struct {
	// Define fields as necessary
}

type Erc721TotalPayload struct {
	// Define fields as necessary
}

type Erc1155TotalPayload struct {
	// Define fields as necessary
}
