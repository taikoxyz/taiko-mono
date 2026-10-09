//! [`App::handle`] dispatch of the methods without app logic (spec §5.6).

use tendermint::{
    Hash, Time,
    abci::types::Snapshot,
    account,
    block::Height,
    v0_38::abci::{Request, Response, request, response},
};

use super::*;

/// A fresh, uninitialized fixture app.
fn app(dir: &Path) -> App<MockL1, MockEngine> {
    Fixture::genesis(1).app(dir)
}

#[tokio::test]
async fn echo_and_flush_answer_in_kind() {
    let dir = tempfile::tempdir().unwrap();
    let mut app = app(dir.path());
    let echo = request::Echo { message: "ping".into() };
    assert_eq!(
        app.handle(Request::Echo(echo)).await.unwrap(),
        Response::Echo(response::Echo { message: "ping".into() })
    );
    assert_eq!(app.handle(Request::Flush).await.unwrap(), Response::Flush);
}

#[tokio::test]
async fn vote_extensions_are_empty_and_accepted() {
    let dir = tempfile::tempdir().unwrap();
    let mut app = app(dir.path());
    let extend = request::ExtendVote {
        hash: Hash::None,
        height: Height::from(5u32),
        time: Time::unix_epoch(),
        txs: vec![],
        proposed_last_commit: None,
        misbehavior: vec![],
        next_validators_hash: Hash::None,
        proposer_address: account::Id::new([1; 20]),
    };
    assert_eq!(
        app.handle(Request::ExtendVote(extend)).await.unwrap(),
        Response::ExtendVote(response::ExtendVote { vote_extension: Default::default() })
    );
    let verify = request::VerifyVoteExtension {
        hash: Hash::None,
        validator_address: account::Id::new([2; 20]),
        height: Height::from(5u32),
        vote_extension: vec![1, 2, 3].into(),
    };
    assert_eq!(
        app.handle(Request::VerifyVoteExtension(verify)).await.unwrap(),
        Response::VerifyVoteExtension(response::VerifyVoteExtension::Accept)
    );
}

#[tokio::test]
async fn snapshot_methods_answer_empty_defaults() {
    let dir = tempfile::tempdir().unwrap();
    let mut app = app(dir.path());
    assert_eq!(
        app.handle(Request::ListSnapshots).await.unwrap(),
        Response::ListSnapshots(Default::default())
    );
    let snapshot = Snapshot {
        height: Height::from(9u32),
        format: 1,
        chunks: 1,
        hash: vec![7].into(),
        metadata: Default::default(),
    };
    let offer = request::OfferSnapshot { snapshot, app_hash: Default::default() };
    assert_eq!(
        app.handle(Request::OfferSnapshot(offer)).await.unwrap(),
        Response::OfferSnapshot(Default::default())
    );
    let load = request::LoadSnapshotChunk { height: Height::from(9u32), format: 1, chunk: 0 };
    assert_eq!(
        app.handle(Request::LoadSnapshotChunk(load)).await.unwrap(),
        Response::LoadSnapshotChunk(Default::default())
    );
    let apply =
        request::ApplySnapshotChunk { index: 0, chunk: vec![1].into(), sender: "peer".into() };
    assert_eq!(
        app.handle(Request::ApplySnapshotChunk(apply)).await.unwrap(),
        Response::ApplySnapshotChunk(Default::default())
    );
    assert!(app.engine().calls().is_empty() && app.l1().calls().is_empty());
}
