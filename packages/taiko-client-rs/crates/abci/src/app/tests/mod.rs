//! App handler tests over [`MockL1`], [`MockEngine`] and a tempdir [`Store`], driven by
//! [`Fixture`] genesis setups.

use std::path::Path;

use tendermint::{
    abci::request::InitChain,
    v0_38::abci::{Request, Response, request, response},
};

use super::{AbciError, App, AppOptions};
use crate::{
    config::ChainParams,
    store::Store,
    test_utils::{EngineCall, Fixture, MockEngine, MockL1},
};

mod finalize;
mod handle;
mod info;
mod init;
mod prepare;
mod process;
mod proposal;

/// A fresh app over the given parts with default options and a store in `dir`.
fn app_with(
    l1: MockL1,
    engine: MockEngine,
    params: ChainParams,
    dir: &Path,
    opts: AppOptions,
) -> App<MockL1, MockEngine> {
    App::new(l1, engine, params, Store::new(dir.to_path_buf()), opts).expect("app starts")
}

/// Sends `InitChain` through [`App::handle`].
async fn init_chain(
    app: &mut App<MockL1, MockEngine>,
    req: InitChain,
) -> Result<response::InitChain, AbciError> {
    match app.handle(Request::InitChain(req)).await? {
        Response::InitChain(r) => Ok(r),
        other => panic!("InitChain answered {other:?}"),
    }
}

/// Sends `Info` through [`App::handle`].
async fn info(app: &mut App<MockL1, MockEngine>) -> Result<response::Info, AbciError> {
    let req = request::Info {
        version: "0.40.0".into(),
        block_version: 11,
        p2p_version: 9,
        abci_version: "2.2.0".into(),
    };
    match app.handle(Request::Info(req)).await? {
        Response::Info(r) => Ok(r),
        other => panic!("Info answered {other:?}"),
    }
}

/// Sends `Query(path)` through [`App::handle`].
async fn query(app: &mut App<MockL1, MockEngine>, path: &str) -> response::Query {
    let req = request::Query {
        data: Default::default(),
        path: path.into(),
        height: Default::default(),
        prove: false,
    };
    match app.handle(Request::Query(req)).await.expect("Query never fails") {
        Response::Query(r) => r,
        other => panic!("Query answered {other:?}"),
    }
}

/// Initializes a fixture app in `dir` and returns it.
async fn initialized(fx: &Fixture, dir: &Path) -> App<MockL1, MockEngine> {
    let mut app = fx.app(dir);
    init_chain(&mut app, fx.request.clone()).await.expect("InitChain succeeds");
    app
}

/// Asserts that `app` holds no state and nothing was persisted in `dir`.
fn assert_not_initialized(app: &App<MockL1, MockEngine>, dir: &Path) {
    assert!(app.state().is_none(), "no state after a rejected InitChain");
    assert_eq!(Store::new(dir.to_path_buf()).load().expect("store loads"), None);
}
