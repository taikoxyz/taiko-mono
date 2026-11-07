//! Deployment and generation domain for stock CometBFT consensus signatures.

use alloy_primitives::{Address, B256, U256, keccak256};
use base64::{Engine as _, engine::general_purpose::URL_SAFE_NO_PAD};
use serde::{Deserialize, Serialize};

/// Complete deployment identity; EVM chain identifiers are never narrowed for signing.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct DeploymentDomain {
    /// Full L1 EVM chain identifier.
    pub l1_chain_id: U256,
    /// Full L2 EVM chain identifier.
    pub l2_chain_id: U256,
    /// Inbox proxy, not its implementation.
    pub inbox: Address,
    /// Recovery generation, constrained to uint48 before use.
    pub generation: u64,
}

/// A deployment cannot be represented by the protocol signing domain.
#[derive(Clone, Copy, Debug, PartialEq, Eq, thiserror::Error)]
pub enum DomainError {
    /// Recovery generation would be truncated by extraData or Solidity uint48.
    #[error("generation {0} exceeds uint48")]
    Generation(u64),
}

/// Returns the canonical 48-byte `etna-` chain id for the full deployment domain.
pub fn chain_id(domain: &DeploymentDomain) -> Result<String, DomainError> {
    if domain.generation > crate::schedule::UINT48_MAX {
        return Err(DomainError::Generation(domain.generation));
    }
    let mut tag = [0u8; 32];
    tag[..20].copy_from_slice(b"ETNA_COMET_DOMAIN_V1");
    let hash = keccak256(
        [
            B256::from(tag),
            B256::from(domain.l1_chain_id),
            B256::from(domain.l2_chain_id),
            B256::from(U256::from_be_slice(domain.inbox.as_slice())),
            B256::from(U256::from(domain.generation)),
        ]
        .concat(),
    );
    Ok(format!("etna-{}", URL_SAFE_NO_PAD.encode(hash)))
}

#[cfg(test)]
mod tests {
    use super::*;
    use alloy_primitives::address;

    fn domain() -> DeploymentDomain {
        DeploymentDomain {
            l1_chain_id: U256::from(1),
            l2_chain_id: U256::from(167001),
            inbox: address!("1111111111111111111111111111111111111111"),
            generation: 0,
        }
    }

    #[test]
    fn domain_binds_every_full_width_identifier() {
        let base = domain();
        let original = chain_id(&base).expect("valid domain");
        assert_eq!(original.len(), 48);
        for altered in [
            DeploymentDomain { l1_chain_id: base.l1_chain_id + (U256::from(1) << 200), ..base },
            DeploymentDomain { l2_chain_id: base.l2_chain_id + (U256::from(1) << 200), ..base },
            DeploymentDomain { inbox: Address::repeat_byte(0x22), ..base },
            DeploymentDomain { generation: 1, ..base },
        ] {
            assert_ne!(chain_id(&altered).unwrap(), original);
        }
    }

    #[test]
    fn domain_accepts_uint48_max_and_rejects_overflow() {
        assert!(chain_id(&DeploymentDomain { generation: (1 << 48) - 1, ..domain() }).is_ok());
        assert!(matches!(
            chain_id(&DeploymentDomain { generation: 1 << 48, ..domain() }),
            Err(DomainError::Generation(_))
        ));
    }
}

#[cfg(test)]
mod protocol_vectors {
    use super::*;
    #[test]
    fn schema4_deployment_domains() {
        for case in crate::test_utils::vectors::at("/chain_domains").as_array().unwrap() {
            let domain = DeploymentDomain {
                l1_chain_id: case["l1_chain_id"].as_str().unwrap().parse().unwrap(),
                l2_chain_id: case["l2_chain_id"].as_str().unwrap().parse().unwrap(),
                inbox: case["inbox"].as_str().unwrap().parse().unwrap(),
                generation: case["generation"].as_str().unwrap().parse().unwrap(),
            };
            assert_eq!(chain_id(&domain).unwrap(), case["chain_id"].as_str().unwrap());
        }
    }
}
