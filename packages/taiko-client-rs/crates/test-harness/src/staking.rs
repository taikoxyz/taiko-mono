//! The staking driver: bonds on the L2 `EtnaStaking` predeploy, held by the harness stakers.
//!
//! The harness devnet genesis premints three minStakes of bridged TAIKO to each of anvil's first
//! four dev accounts, the stakers ([`STAKER_KEYS`]). Its L1 TAIKO token and SignalService are
//! placeholders without code, so nothing is bridged: a staker approves the staking contract and
//! registers, tops up or exits straight from that premint. The ELs of a harness chain do not share
//! their pools, so every transaction goes to each EL the driver knows, and the block of whichever
//! proposer builds next carries it. Reads go to the first EL.

use std::time::Duration;

use alloy::{
    consensus::{SignableTransaction, TxEip1559, TxEnvelope},
    rpc::types::{TransactionReceipt, TransactionRequest},
    signers::{SignerSync, local::PrivateKeySigner},
    sol_types::SolCall,
};
use alloy_eips::{BlockId, BlockNumberOrTag, eip2718::Encodable2718};
use alloy_primitives::{Address, B256, Bytes, TxKind, U256, b256, keccak256};
use alloy_provider::{Provider, RootProvider};
use anyhow::{Context, Result, bail, ensure};

use crate::{keys::ValidatorKey, wait::wait_until};

/// The pinned protocol revision's `EtnaStaking` ABI, from the lander fixture its artifacts
/// reproduce. Its event constructors take more arguments than the lint allows.
#[allow(clippy::too_many_arguments)]
mod bindings {
    alloy::sol!(EtnaStaking, "../lander/tests/fixtures/contracts/EtnaStaking.json");
}
pub use bindings::{EtnaStaking, IEtnaStaking};

alloy::sol! {
    /// The bridged TAIKO calls the stakers make.
    interface ITaikoToken {
        function approve(address spender, uint256 amount) external returns (bool);
        function balanceOf(address account) external view returns (uint256);
    }
}

/// Private keys of anvil's first four dev accounts, the stakers the harness genesis premints three
/// minStakes of bridged TAIKO each, in account order (`0xf39F…2266`, `0x7099…79C8`,
/// `0x3C44…93BC`, `0x90F7…b906`). The first is also [`DEV_KEY`](crate::DEV_KEY).
pub const STAKER_KEYS: [B256; 4] = [
    b256!("ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"),
    b256!("59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"),
    b256!("5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a"),
    b256!("7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6"),
];

/// Deadline for a staking transaction's receipt.
const RECEIPT_TIMEOUT: Duration = Duration::from_secs(90);

/// Poll interval of the receipt waits.
const RECEIPT_POLL: Duration = Duration::from_millis(250);

/// Priority fee of the staking transactions: 1 gwei.
const PRIORITY_FEE: u128 = 1_000_000_000;

/// The signer of staker `index` ([`STAKER_KEYS`]).
pub fn staker(index: usize) -> PrivateKeySigner {
    PrivateKeySigner::from_bytes(&STAKER_KEYS[index]).expect("an anvil dev key")
}

/// The deployment values of `EtnaStaking` the scenarios compute with.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct StakingParams {
    /// `minStake`: the least stake that holds a seat.
    pub min_stake: U256,
    /// `vpUnit`: a seated bond's power is its stake divided by it, rounded down.
    pub vp_unit: U256,
    /// `missLimit`: a seat's bond loses `missSlashBps` at every positive multiple of this many
    /// consecutive misses.
    pub miss_limit: u64,
    /// `missSlashBps`: the share of its stake, in basis points, a bond loses per penalty.
    pub miss_slash_bps: U256,
    /// `missReleaseLimit`: the consecutive misses after which a seated bond releases its seat,
    /// whatever its stake, with no exit set.
    pub miss_release_limit: u64,
}

impl StakingParams {
    /// The power of a seated bond of stake `stake`.
    pub fn power(&self, stake: U256) -> Result<u64> {
        u64::try_from(stake / self.vp_unit).context("power above u64")
    }

    /// The missed-signature penalty on a bond of stake `stake`, rounded up.
    pub fn miss_penalty(&self, stake: U256) -> U256 {
        (stake * self.miss_slash_bps).div_ceil(U256::from(10_000))
    }

    /// Whether the block-start call that raises a seat's count to `count` penalizes its bond: at
    /// every positive multiple of `missLimit`. The count is not reset by a penalty, so one run of
    /// misses is penalized again and again.
    pub fn penalizes(&self, count: u64) -> bool {
        count != 0 && count.is_multiple_of(self.miss_limit)
    }

    /// Whether the block-start call that raises a seat's count to `count` releases its seat
    /// although its bond still holds `minStake` or more: from `missReleaseLimit` on, after any
    /// penalty due in the same call.
    pub fn releases(&self, count: u64) -> bool {
        count >= self.miss_release_limit
    }
}

/// A registered bond.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Bond {
    /// The bond id `register` returned.
    pub id: U256,
    /// The seat the registration took.
    pub seat: u8,
    /// The L2 block that holds the registration.
    pub block: u64,
}

/// One registration: the staker that owns the bond, the consensus key it registers and the
/// stake.
#[derive(Clone, Debug)]
pub struct Registration<'a> {
    /// The bond's owner, a staker holding the premint.
    pub owner: PrivateKeySigner,
    /// The consensus key, which signs the registration proof.
    pub key: &'a ValidatorKey,
    /// The stake, at least `minStake`.
    pub amount: U256,
}

/// Drives `EtnaStaking` at `address` on an L2 whose ELs are `els` (see the module docs).
#[derive(Clone, Debug)]
pub struct Staking {
    /// Every EL: transactions go to each, reads to the first.
    els: Vec<RootProvider>,
    /// The staking proxy.
    address: Address,
    /// Its immutable staking token, bridged TAIKO.
    token: Address,
    /// The L2 chain id the registration proof binds.
    chain_id: u64,
}

impl Staking {
    /// The driver of the staking proxy `address` over `els`, the first of which serves reads.
    pub async fn new(els: Vec<RootProvider>, address: Address) -> Result<Self> {
        let reader = els.first().context("the staking driver needs an EL")?;
        let chain_id = reader.get_chain_id().await?;
        let mut this = Self { els, address, token: Address::ZERO, chain_id };
        this.token = this.read(EtnaStaking::tokenCall {}, BlockId::latest()).await?;
        ensure!(!this.token.is_zero(), "EtnaStaking at {address} names no staking token");
        Ok(this)
    }

    /// The staking proxy.
    pub fn address(&self) -> Address {
        self.address
    }

    /// The deployment values, read at the latest block.
    pub async fn params(&self) -> Result<StakingParams> {
        let latest = BlockId::latest();
        Ok(StakingParams {
            min_stake: self.read(EtnaStaking::minStakeCall {}, latest).await?,
            vp_unit: self.read(EtnaStaking::vpUnitCall {}, latest).await?,
            miss_limit: u64::try_from(self.read(EtnaStaking::missLimitCall {}, latest).await?)?,
            miss_slash_bps: self.read(EtnaStaking::missSlashBpsCall {}, latest).await?,
            miss_release_limit: u64::try_from(
                self.read(EtnaStaking::missReleaseLimitCall {}, latest).await?,
            )?,
        })
    }

    /// The bridged TAIKO balance of `account` at the latest block.
    pub async fn balance(&self, account: Address) -> Result<U256> {
        let call = ITaikoToken::balanceOfCall { account };
        read_at(&self.els[0], self.token, call, BlockId::latest()).await
    }

    /// The registration proof of `key` for bonds owned by `owner`: its 65-byte recoverable
    /// signature of the [`registration_preimage`], after checking that the contract's
    /// `registerDigest(owner)` is that preimage's hash.
    pub async fn registration_proof(&self, owner: Address, key: &ValidatorKey) -> Result<Bytes> {
        let preimage = registration_preimage(self.chain_id, self.address, owner);
        let digest =
            self.read(EtnaStaking::registerDigestCall { _owner: owner }, BlockId::latest()).await?;
        ensure!(
            keccak256(&preimage) == digest,
            "EtnaStaking's registration digest {digest} for {owner} is not the EIP-712 Register \
             digest {}",
            keccak256(&preimage)
        );
        Ok(key.sign_native_message(&preimage).into())
    }

    /// Registers each of `registrations`, approving the stakes first; returns the bonds in the
    /// same order. Each round of transactions is sent before any is awaited, so independent
    /// stakers' registrations can share a block.
    pub async fn register_all(&self, registrations: &[Registration<'_>]) -> Result<Vec<Bond>> {
        let mut approvals = Vec::with_capacity(registrations.len());
        for r in registrations {
            let call = ITaikoToken::approveCall { spender: self.address, amount: r.amount };
            approvals.push(self.send(&r.owner, self.token, call.abi_encode()).await?);
        }
        for hash in approvals {
            self.receipt(hash, "approve").await?;
        }
        let mut sent = Vec::with_capacity(registrations.len());
        for r in registrations {
            let call = EtnaStaking::registerCall {
                _publicKey: Bytes::copy_from_slice(r.key.pubkey().as_bytes()),
                _amount: r.amount,
                _popSig: self.registration_proof(r.owner.address(), r.key).await?,
            };
            sent.push(self.send(&r.owner, self.address, call.abi_encode()).await?);
        }
        let mut bonds = Vec::with_capacity(sent.len());
        for (hash, r) in sent.into_iter().zip(registrations) {
            let receipt = self.receipt(hash, "register").await?;
            let registered = receipt
                .decoded_log::<EtnaStaking::Registered>()
                .context("register emitted no Registered event")?;
            ensure!(
                registered.data.ckAddr == r.key.pubkey().address(),
                "registered {} for the key of {}",
                registered.data.ckAddr,
                r.key.pubkey().address()
            );
            bonds.push(Bond {
                id: registered.data.bondId,
                seat: registered.data.seat,
                block: receipt.block_number.context("register receipt without a block")?,
            });
        }
        Ok(bonds)
    }

    /// Registers `key` with stake `amount` owned by `owner` (see [`Staking::register_all`]).
    pub async fn register(
        &self,
        owner: &PrivateKeySigner,
        key: &ValidatorKey,
        amount: U256,
    ) -> Result<Bond> {
        let registration = Registration { owner: owner.clone(), key, amount };
        Ok(self.register_all(&[registration]).await?.remove(0))
    }

    /// Adds `amount` to bond `bond`, owned by `owner`, approving it first; returns the block of
    /// the top-up.
    pub async fn top_up(&self, owner: &PrivateKeySigner, bond: U256, amount: U256) -> Result<u64> {
        let approve = ITaikoToken::approveCall { spender: self.address, amount };
        let hash = self.send(owner, self.token, approve.abi_encode()).await?;
        self.receipt(hash, "approve").await?;
        let call = EtnaStaking::topUpCall { _bondId: bond, _amount: amount };
        let hash = self.send(owner, self.address, call.abi_encode()).await?;
        self.mined(hash, "topUp").await
    }

    /// Requests the exit of bond `bond`, owned by `owner`; returns the block of the request,
    /// whose call releases the bond's seat.
    pub async fn request_exit(&self, owner: &PrivateKeySigner, bond: U256) -> Result<u64> {
        let call = EtnaStaking::requestExitCall { _bondId: bond };
        let hash = self.send(owner, self.address, call.abi_encode()).await?;
        self.mined(hash, "requestExit").await
    }

    /// Bond `bond` in the post-state of block `at`.
    pub async fn bond(&self, bond: U256, at: BlockId) -> Result<IEtnaStaking::Bond> {
        self.read(EtnaStaking::bondAtCall { _bondId: bond }, at).await
    }

    /// The seat bond `bond` holds in the post-state of block `at`, if any.
    pub async fn seat_of_bond(&self, bond: U256, at: BlockId) -> Result<Option<u8>> {
        let seat = self.read(EtnaStaking::seatOfBondCall { _bondId: bond }, at).await?;
        Ok(seat.holdsSeat_.then_some(seat.seat_))
    }

    /// The candidate snapshot in the post-state of block `at`: its height, its total stake and
    /// its occupied seat records in seat order.
    pub async fn snapshot(
        &self,
        at: BlockId,
    ) -> Result<(U256, U256, Vec<IEtnaStaking::SeatMember>)> {
        let snapshot = self.read(EtnaStaking::snapshotCall {}, at).await?;
        Ok((snapshot.height_, snapshot.totalStake_, snapshot.members_))
    }

    /// The consecutive misses of seat `seat` in the post-state of block `at`.
    pub async fn miss_count(&self, seat: u8, at: BlockId) -> Result<u16> {
        self.read(EtnaStaking::missCountCall { _seat: seat }, at).await
    }

    /// The live key-to-seat word of the consensus key address `key` in the post-state of block
    /// `at`, the word nodes read for the `missBitmap`: zero for a key that holds no seat.
    pub async fn key_seat_word(&self, key: Address, at: BlockId) -> Result<U256> {
        let slot = U256::from_be_bytes(abci::staking::key_to_seat_slot(key).0);
        let word = self.els[0]
            .get_storage_at(self.address, slot)
            .block_id(at)
            .await
            .with_context(|| format!("eth_getStorageAt {} {slot:#x}", self.address))?;
        Ok(word)
    }

    /// `call` on the staking proxy at block `at`.
    async fn read<C: SolCall>(&self, call: C, at: BlockId) -> Result<C::Return> {
        read_at(&self.els[0], self.address, call, at).await
    }

    /// Signs an EIP-1559 call of `input` to `to` from `owner` at its next pending nonce, with
    /// the estimated gas plus a margin and a max fee of twice the latest base fee plus 1 gwei,
    /// and sends it to every EL; returns its hash. An EL refusing it is logged: another may
    /// still carry it, and [`Staking::receipt`] waits for it on the first.
    async fn send(&self, owner: &PrivateKeySigner, to: Address, input: Vec<u8>) -> Result<B256> {
        let reader = &self.els[0];
        let from = owner.address();
        let nonce = reader.get_transaction_count(from).pending().await?;
        let request = TransactionRequest::default().from(from).to(to).input(input.clone().into());
        let selector = alloy_primitives::hex::encode(input.get(..4).unwrap_or(&input));
        let estimate = reader
            .estimate_gas(request)
            .await
            .with_context(|| format!("estimating {to} selector {selector} from {from}"))?;
        let latest = reader
            .get_block_by_number(BlockNumberOrTag::Latest)
            .await?
            .context("L2 has no latest block")?;
        let base_fee = u128::from(latest.header.base_fee_per_gas.context("no base fee")?);
        let tx = TxEip1559 {
            chain_id: self.chain_id,
            nonce,
            gas_limit: estimate + estimate / 2,
            max_fee_per_gas: 2 * base_fee + PRIORITY_FEE,
            max_priority_fee_per_gas: PRIORITY_FEE,
            to: TxKind::Call(to),
            input: input.into(),
            ..Default::default()
        };
        let signature = owner.sign_hash_sync(&tx.signature_hash())?;
        let raw = TxEnvelope::Eip1559(tx.into_signed(signature)).encoded_2718();
        let hash = keccak256(&raw);
        let mut accepted = 0;
        for (i, el) in self.els.iter().enumerate() {
            match el.send_raw_transaction(&raw).await {
                Ok(_) => accepted += 1,
                Err(e) => tracing::debug!(el = i, %hash, error = %e, "EL refused a staking tx"),
            }
        }
        ensure!(accepted > 0, "no EL accepted staking transaction {hash} (selector {selector})");
        Ok(hash)
    }

    /// Waits for `hash`'s receipt on the first EL and requires success.
    async fn receipt(&self, hash: B256, what: &str) -> Result<TransactionReceipt> {
        let reader = &self.els[0];
        let receipt = wait_until(
            &format!("the {what} receipt {hash}"),
            RECEIPT_TIMEOUT,
            RECEIPT_POLL,
            || async move { Ok(reader.get_transaction_receipt(hash).await?) },
        )
        .await?;
        if !receipt.status() {
            bail!("{what} transaction {hash} reverted");
        }
        Ok(receipt)
    }

    /// The block of `hash`'s successful receipt ([`Staking::receipt`]).
    async fn mined(&self, hash: B256, what: &str) -> Result<u64> {
        let receipt = self.receipt(hash, what).await?;
        receipt.block_number.with_context(|| format!("{what} receipt without a block"))
    }
}

/// The registration proof's preimage for bonds of the staking proxy `staking` on the L2 chain
/// `chain_id` owned by `owner`, `0x1901 ‖ domainSeparator ‖ structHash`: the EIP-712 domain is
/// name "EtnaStaking", version "1", the chain id and the proxy, and the struct is
/// `Register(address owner)`. The consensus key signs its Keccak-256 hash.
pub fn registration_preimage(chain_id: u64, staking: Address, owner: Address) -> Vec<u8> {
    let domain = keccak256(
        [
            keccak256(
                "EIP712Domain(string name,string version,uint256 chainId,address \
                 verifyingContract)",
            ),
            keccak256("EtnaStaking"),
            keccak256("1"),
            B256::from(U256::from(chain_id)),
            staking.into_word(),
        ]
        .concat(),
    );
    let structure = keccak256([keccak256("Register(address owner)"), owner.into_word()].concat());
    [&[0x19, 0x01][..], domain.as_slice(), structure.as_slice()].concat()
}

/// `call` on `to` through `el` at block `at`, decoded.
async fn read_at<C: SolCall>(
    el: &RootProvider,
    to: Address,
    call: C,
    at: BlockId,
) -> Result<C::Return> {
    let request = TransactionRequest::default().to(to).input(call.abi_encode().into());
    let output = el.call(request).block(at).await.with_context(|| format!("eth_call {to}"))?;
    Ok(C::abi_decode_returns(&output)?)
}

#[cfg(test)]
mod tests {
    use alloy_primitives::address;

    use super::*;

    /// The stakers are the four premint holders the harness genesis funds.
    #[test]
    fn stakers_are_the_premint_holders() {
        let holders = [
            address!("f39Fd6e51aad88F6F4ce6aB8827279cffFb92266"),
            address!("70997970C51812dc3A010C7d01b50e0d17dc79C8"),
            address!("3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"),
            address!("90F79bf6EB2c4f870365E785982E1f101E93b906"),
        ];
        for (i, holder) in holders.into_iter().enumerate() {
            assert_eq!(staker(i).address(), holder);
        }
        assert_eq!(STAKER_KEYS[0], crate::DEV_KEY);
    }

    /// A penalty rounds up and a power rounds down, as the staking contract computes them.
    #[test]
    fn penalty_rounds_up_and_power_rounds_down() {
        let params = StakingParams {
            min_stake: U256::from(100),
            vp_unit: U256::from(7),
            miss_limit: 10,
            miss_slash_bps: U256::from(1_000),
            miss_release_limit: 30,
        };
        assert_eq!(params.miss_penalty(U256::from(200)), U256::from(20));
        assert_eq!(params.miss_penalty(U256::from(201)), U256::from(21));
        assert_eq!(params.power(U256::from(20)).unwrap(), 2);
    }

    /// A run of misses is penalized at every multiple of `missLimit`, its count kept, and its seat
    /// is released at `missReleaseLimit`, in the call that also penalizes it there.
    #[test]
    fn penalties_repeat_at_every_miss_limit_until_the_release() {
        let params = StakingParams {
            min_stake: U256::from(100),
            vp_unit: U256::from(7),
            miss_limit: 10,
            miss_slash_bps: U256::from(1_000),
            miss_release_limit: 30,
        };
        let penalized: Vec<_> = (0..=30).filter(|&count| params.penalizes(count)).collect();
        assert_eq!(penalized, [10, 20, 30]);
        let released: Vec<_> = (0..=30).filter(|&count| params.releases(count)).collect();
        assert_eq!(released, [30]);
        let off_multiple = StakingParams { miss_release_limit: 25, ..params };
        assert!(off_multiple.releases(25) && !off_multiple.penalizes(25));
    }

    /// The preimage hashes to the shared vectors' registration digests, which the contracts'
    /// `registerDigest` and the signer's `pop` reproduce.
    #[test]
    fn registration_preimage_matches_the_shared_digests() {
        let vectors: serde_json::Value =
            serde_json::from_str(include_str!("../../../../../testdata/etna_vectors/vectors.json"))
                .unwrap();
        let cases = vectors["register_digests"].as_array().unwrap();
        assert!(cases.len() >= 3, "too few registration digest vectors");
        for case in cases {
            let field = |name: &str| case[name].as_str().unwrap();
            let preimage = registration_preimage(
                field("l2_chain_id").parse().unwrap(),
                field("staking").parse().unwrap(),
                field("owner").parse().unwrap(),
            );
            assert_eq!(&preimage[..2], &[0x19, 0x01]);
            assert_eq!(
                B256::from_slice(&preimage[2..34]),
                field("domain_separator").parse::<B256>().unwrap()
            );
            assert_eq!(
                B256::from_slice(&preimage[34..]),
                field("struct_hash").parse::<B256>().unwrap()
            );
            assert_eq!(
                keccak256(&preimage),
                field("digest").parse::<B256>().unwrap(),
                "{}",
                field("name")
            );
        }
    }

    /// A harness key's registration proof is the 65-byte `R ‖ S ‖ V` form the contract takes:
    /// `V` is 0 or 1, `s` is low, and it recovers the key's address over the preimage's hash.
    #[test]
    fn registration_proof_recovers_the_key_address() {
        let key = crate::keys::validator_keys(3).remove(2);
        let preimage = registration_preimage(
            167001,
            address!("1670010000000000000000000000000000010003"),
            staker(1).address(),
        );
        let proof = key.sign_native_message(&preimage);
        assert_eq!(proof.len(), 65);
        assert!(proof[64] <= 1, "V must be 0 or 1");
        let signature = alloy_primitives::Signature::from_raw(&proof).unwrap();
        assert!(signature.normalize_s().is_none(), "s must be low");
        let recovered = signature.recover_address_from_prehash(&keccak256(&preimage)).unwrap();
        assert_eq!(recovered, key.pubkey().address());
    }
}
