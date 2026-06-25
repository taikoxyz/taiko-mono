// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title LibL1Addrs
/// @custom:security-contact security@taiko.xyz
library LibL1Addrs {
    address public constant DAO = 0x9CDf589C941ee81D75F34d3755671d614f7cf261;
    address public constant DAO_SIGNER_LIST = 0x0F95E6968EC1B28c794CF1aD99609431de5179c2;
    address public constant DAO_STANDARD_MULTISIG = 0xD7dA1C25E915438720692bC55eb3a7170cA90321;
    address public constant DAO_EMERGENCY_MULTISIG = 0x2AffADEb2ef5e1F2a7F58964ee191F1e88317ECd;
    address public constant DAO_CONTROLLER = 0x75Ba76403b13b26AD1beC70D6eE937314eeaCD0a;
    address public constant DAO_OPTIMISTIC_TOKEN_VOTING_PLUGIN =
        0x989E348275b659d36f8751ea1c10D146211650BE;

    address public constant FORCED_INCLUSION_STORE = 0x05d88855361808fA1d7fc28084Ef3fCa191c4e03;
    address public constant INBOX = 0x6f21C543a4aF5189eBdb0723827577e1EF57ef1f;
    address public constant PRECONF_WHITELIST = 0xFD019460881e6EeC632258222393d5821029b2ac;
    address public constant PROVER_WHITELIST = 0xEa798547d97e345395dA071a0D7ED8144CD612Ae;
    address public constant SHARED_RESOLVER = 0x8Efa01564425692d0a0838DC10E300BD310Cb43e;
    address public constant QUOTA_MANAGER = 0xBaCb003f0B13CeAF09Eb9Baf5915A640BD4Bc6cC;

    address public constant BRIDGE = 0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC;

    address public constant SIGNAL_SERVICE = 0x9e0a24964e5397B566c1ed39258e21aB5E35C77C;
    address public constant ERC20_VAULT = 0x996282cA11E5DEb6B5D122CC3B9A1FcAAD4415Ab;
    address public constant ERC721_VAULT = 0x0b470dd3A0e1C41228856Fb319649E7c08f419Aa;
    address public constant ERC1155_VAULT = 0xaf145913EA4a56BE22E120ED9C24589659881702;
    address public constant BRIDGED_ERC20 = 0x65666141a541423606365123Ed280AB16a09A2e1;
    address public constant BRIDGED_ERC721 = 0xC3310905E2BC9Cfb198695B75EF3e5B69C6A1Bf7;
    address public constant BRIDGED_ERC1155 = 0x3c90963cFBa436400B0F9C46Aa9224cB379c2c40;

    // Proof system verifiers and attesters
    address public constant RISC0_RETH_VERIFIER = 0x059dAF31F571da48Ab4e74Ae12F64f907681Cd8b;
    address public constant SP1_RETH_VERIFIER = 0x96337327648dcFA22b014009cf10A2D5E2F305f6;
    address public constant SGXGETH_ATTESTER = 0x0ffa4A625ED9DB32B70F99180FD00759fc3e9261;
    address public constant SGXRETH_ATTESTER = 0x8d7C954960a36a7596d7eA4945dDf891967ca8A3;

    // admin.taiko.eth multisig
    address public constant MULTISIG_ADMIN_TAIKO_ETH = 0x9CBeE534B5D8a6280e01a14844Ee8aF350399C7F;

    // Third-party addresses
    address public constant ENS_REVERSE_REGISTRAR = 0xa58E81fe9b61B5c3fE2AFD33CF304c454AbFc7Cb;

    // Well known tokens
    address public constant TAIKO_TOKEN = 0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800;
    address public constant WETH_TOKEN = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC_TOKEN = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDT_TOKEN = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
}
