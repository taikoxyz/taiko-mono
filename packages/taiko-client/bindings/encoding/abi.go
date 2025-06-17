package encoding

import (
	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/log"

	ontakeBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/ontake"
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
)

// Contract ABIs.
var (
	// Ontake fork
	TaikoL1ABI          *abi.ABI
	TaikoL2ABI          *abi.ABI
	TaikoTokenABI       *abi.ABI
	GuardianProverABI   *abi.ABI
	LibProposingABI     *abi.ABI
	LibProvingABI       *abi.ABI
	LibUtilsABI         *abi.ABI
	LibVerifyingABI     *abi.ABI
	SGXVerifierABI      *abi.ABI
	GuardianVerifierABI *abi.ABI
	ProverSetABI        *abi.ABI
	ForkRouterABI       *abi.ABI

	// Pacaya fork
	TaikoInboxPacayaABI           *abi.ABI
	TaikoWrapperPacayaABI         *abi.ABI
	ForcedInclusionStorePacayaABI *abi.ABI
	TaikoAnchorPacayaABI          *abi.ABI
	ResolverBasePacayaABI         *abi.ABI
	ComposeVerifierPacayaABI      *abi.ABI
	ForkRouterPacayaABI           *abi.ABI
	TaikoTokenPacayaABI           *abi.ABI
	ProverSetPacayaABI            *abi.ABI

	// Shasta fork
	TaikoInboxShastaABI           *abi.ABI
	TaikoWrapperShastaABI         *abi.ABI
	ForcedInclusionStoreShastaABI *abi.ABI
	TaikoAnchorShastaABI          *abi.ABI
	ResolverBaseShastaABI         *abi.ABI
	ComposeVerifierShastaABI      *abi.ABI
	ForkRouterShastaABI           *abi.ABI
	TaikoTokenShastaABI           *abi.ABI
	ProverSetShastaABI            *abi.ABI

	customErrorMaps []map[string]abi.Error
)

func init() {
	customErrorMaps = append(initOntakeABIs(), append(initPacayaABIs(), initShastaABIs()...)...)
}

// initOntakeABIs initializes the Ontake contract ABIs and returns a slice of error maps.
func initOntakeABIs() []map[string]abi.Error {
	var err error
	if TaikoL1ABI, err = ontakeBindings.TaikoL1ClientMetaData.GetAbi(); err != nil {
		log.Crit("Get TaikoL1 ABI error", "error", err)
	}

	if TaikoL2ABI, err = ontakeBindings.TaikoL2ClientMetaData.GetAbi(); err != nil {
		log.Crit("Get TaikoL2 ABI error", "error", err)
	}

	if TaikoTokenABI, err = ontakeBindings.TaikoTokenMetaData.GetAbi(); err != nil {
		log.Crit("Get TaikoToken ABI error", "error", err)
	}

	if GuardianProverABI, err = ontakeBindings.GuardianProverMetaData.GetAbi(); err != nil {
		log.Crit("Get GuardianProver ABI error", "error", err)
	}

	if LibProposingABI, err = ontakeBindings.LibProposingMetaData.GetAbi(); err != nil {
		log.Crit("Get LibProposing ABI error", "error", err)
	}

	if LibProvingABI, err = ontakeBindings.LibProvingMetaData.GetAbi(); err != nil {
		log.Crit("Get LibProving ABI error", "error", err)
	}

	if LibUtilsABI, err = ontakeBindings.LibUtilsMetaData.GetAbi(); err != nil {
		log.Crit("Get LibUtils ABI error", "error", err)
	}

	if LibVerifyingABI, err = ontakeBindings.LibVerifyingMetaData.GetAbi(); err != nil {
		log.Crit("Get LibVerifying ABI error", "error", err)
	}

	if SGXVerifierABI, err = ontakeBindings.SgxVerifierMetaData.GetAbi(); err != nil {
		log.Crit("Get SGXVerifier ABI error", err)
	}

	if GuardianVerifierABI, err = ontakeBindings.GuardianVerifierMetaData.GetAbi(); err != nil {
		log.Crit("Get GuardianVerifier ABI error", "error", err)
	}

	if ProverSetABI, err = ontakeBindings.ProverSetMetaData.GetAbi(); err != nil {
		log.Crit("Get ProverSet ABI error", "error", err)
	}

	if ForkRouterABI, err = ontakeBindings.ForkRouterMetaData.GetAbi(); err != nil {
		log.Crit("Get ForkRouter ABI error", "error", err)
	}

	return []map[string]abi.Error{
		TaikoL1ABI.Errors,
		TaikoL2ABI.Errors,
		GuardianProverABI.Errors,
		LibProposingABI.Errors,
		LibProvingABI.Errors,
		LibUtilsABI.Errors,
		LibVerifyingABI.Errors,
		SGXVerifierABI.Errors,
		GuardianVerifierABI.Errors,
		ProverSetABI.Errors,
		ForkRouterABI.Errors,
	}
}

// initPacayaABIs initializes the Pacaya contract ABIs and returns a slice of error maps.
func initPacayaABIs() []map[string]abi.Error {
	var err error
	if TaikoInboxPacayaABI, err = pacayaBindings.TaikoInboxClientMetaData.GetAbi(); err != nil {
		log.Crit("Get TaikoInbox ABI error", "error", err)
	}

	if TaikoWrapperPacayaABI, err = pacayaBindings.TaikoWrapperClientMetaData.GetAbi(); err != nil {
		log.Crit("Get TaikoWrapper ABI error", "error", err)
	}

	if ForcedInclusionStorePacayaABI, err = pacayaBindings.ForcedInclusionStoreMetaData.GetAbi(); err != nil {
		log.Crit("Get ForcedInclusionStore ABI error", "error", err)
	}

	if TaikoAnchorPacayaABI, err = pacayaBindings.TaikoAnchorClientMetaData.GetAbi(); err != nil {
		log.Crit("Get TaikoAnchor ABI error", "error", err)
	}

	if ResolverBasePacayaABI, err = pacayaBindings.ResolverBaseMetaData.GetAbi(); err != nil {
		log.Crit("Get ResolverBase ABI error", "error", err)
	}

	if ComposeVerifierPacayaABI, err = pacayaBindings.ComposeVerifierMetaData.GetAbi(); err != nil {
		log.Crit("Get ComposeVerifier ABI error", "error", err)
	}

	if ForkRouterPacayaABI, err = pacayaBindings.ForkRouterMetaData.GetAbi(); err != nil {
		log.Crit("Get ForkRouter ABI error", "error", err)
	}

	if TaikoTokenPacayaABI, err = pacayaBindings.TaikoTokenMetaData.GetAbi(); err != nil {
		log.Crit("Get TaikoToken ABI error", "error", err)
	}

	if ProverSetPacayaABI, err = pacayaBindings.ProverSetMetaData.GetAbi(); err != nil {
		log.Crit("Get ProverSet ABI error", "error", err)
	}

	return []map[string]abi.Error{
		TaikoInboxPacayaABI.Errors,
		TaikoWrapperPacayaABI.Errors,
		ForcedInclusionStorePacayaABI.Errors,
		TaikoAnchorPacayaABI.Errors,
		ResolverBasePacayaABI.Errors,
		ComposeVerifierPacayaABI.Errors,
		ForkRouterPacayaABI.Errors,
		TaikoTokenPacayaABI.Errors,
		ProverSetPacayaABI.Errors,
	}
}

// initShastaABIs initializes the Shasta contract ABIs and returns a slice of error maps.
func initShastaABIs() []map[string]abi.Error {
	var err error
	if TaikoInboxShastaABI, err = shastaBindings.TaikoInboxClientMetaData.GetAbi(); err != nil {
		log.Crit("Get TaikoInbox ABI error", "error", err)
	}

	if TaikoWrapperShastaABI, err = shastaBindings.TaikoWrapperClientMetaData.GetAbi(); err != nil {
		log.Crit("Get TaikoWrapper ABI error", "error", err)
	}

	if ForcedInclusionStoreShastaABI, err = shastaBindings.ForcedInclusionStoreMetaData.GetAbi(); err != nil {
		log.Crit("Get ForcedInclusionStore ABI error", "error", err)
	}

	if TaikoAnchorShastaABI, err = shastaBindings.TaikoAnchorClientMetaData.GetAbi(); err != nil {
		log.Crit("Get TaikoAnchor ABI error", "error", err)
	}

	if ResolverBaseShastaABI, err = shastaBindings.ResolverBaseMetaData.GetAbi(); err != nil {
		log.Crit("Get ResolverBase ABI error", "error", err)
	}

	if ComposeVerifierShastaABI, err = shastaBindings.ComposeVerifierMetaData.GetAbi(); err != nil {
		log.Crit("Get ComposeVerifier ABI error", "error", err)
	}

	if ForkRouterShastaABI, err = shastaBindings.ForkRouterMetaData.GetAbi(); err != nil {
		log.Crit("Get ForkRouter ABI error", "error", err)
	}

	if TaikoTokenShastaABI, err = shastaBindings.TaikoTokenMetaData.GetAbi(); err != nil {
		log.Crit("Get TaikoToken ABI error", "error", err)
	}

	if ProverSetShastaABI, err = shastaBindings.ProverSetMetaData.GetAbi(); err != nil {
		log.Crit("Get ProverSet ABI error", "error", err)
	}

	return []map[string]abi.Error{
		TaikoInboxShastaABI.Errors,
		TaikoWrapperShastaABI.Errors,
		ForcedInclusionStoreShastaABI.Errors,
		TaikoAnchorShastaABI.Errors,
		ResolverBaseShastaABI.Errors,
		ComposeVerifierShastaABI.Errors,
		ForkRouterShastaABI.Errors,
		TaikoTokenShastaABI.Errors,
		ProverSetShastaABI.Errors,
	}
}
