use std::env;

use self::rindexer_lib::indexers::all_handlers::register_all_handlers;
use rindexer::{
    event::callback_registry::TraceCallbackRegistry, start_rindexer, GraphqlOverrideSettings,
    IndexingDetails, StartDetails,
};

mod decoder;
mod rindexer_lib;

#[tokio::main]
async fn main() {
    let args: Vec<String> = env::args().collect();

    let mut enable_graphql = false;
    let mut enable_indexer = false;

    let mut port: Option<u16> = None;

    let args = args.iter();
    if args.len() == 0 {
        enable_graphql = true;
        enable_indexer = true;
    }

    for arg in args {
        match arg.as_str() {
            "--graphql" => enable_graphql = true,
            "--indexer" => enable_indexer = true,
            _ if arg.starts_with("--port=") || arg.starts_with("--p") => {
                if let Some(value) = arg.split('=').nth(1) {
                    let overridden_port = value.parse::<u16>();
                    match overridden_port {
                        Ok(overridden_port) => port = Some(overridden_port),
                        Err(_) => {
                            println!("Invalid port number");
                            return;
                        }
                    }
                }
            }
            _ => {}
        }
    }

    let path = env::current_dir();
    match path {
        Ok(path) => {
            let manifest_path = path.join("rindexer.yaml");
            let result = start_rindexer(StartDetails {
                manifest_path: &manifest_path,
                indexing_details: if enable_indexer {
                    Some(IndexingDetails {
                        registry: register_all_handlers(&manifest_path).await,
                        trace_registry: TraceCallbackRegistry { events: vec![] },
                    })
                } else {
                    None
                },
                graphql_details: GraphqlOverrideSettings {
                    enabled: enable_graphql,
                    override_port: port,
                },
            })
            .await;

            match result {
                Ok(_) => {}
                Err(e) => {
                    println!("Error starting rindexer: {:?}", e);
                }
            }
        }
        Err(e) => {
            println!("Error getting current directory: {:?}", e);
        }
    }
}
