//! Websocket notification stream handling.

use axum::extract::ws::{Message, WebSocket};
use futures::StreamExt;
use tokio::sync::broadcast;
use tracing::warn;

use crate::rest::types::EndOfSequencingNotification;

/// Push EOS notifications over a connected websocket until disconnect.
pub(super) async fn serve_websocket_notifications(
    mut websocket: WebSocket,
    mut notifications: broadcast::Receiver<EndOfSequencingNotification>,
) {
    loop {
        tokio::select! {
            notification = notifications.recv() => {
                match notification {
                    Ok(notification) => {
                        match serde_json::to_string(&notification) {
                            Ok(payload) => {
                                if websocket.send(Message::Text(payload)).await.is_err() {
                                    break;
                                }
                            }
                            Err(err) => {
                                warn!(error = %err, "failed to serialize websocket EOS notification");
                            }
                        }
                    }
                    Err(tokio::sync::broadcast::error::RecvError::Lagged(skipped)) => {
                        warn!(skipped, "whitelist websocket subscriber lagged behind EOS notifications");
                    }
                    Err(tokio::sync::broadcast::error::RecvError::Closed) => break,
                }
            }
            incoming = websocket.next() => {
                match incoming {
                    Some(Ok(Message::Close(_))) => break,
                    Some(Ok(Message::Ping(payload))) => {
                        if websocket.send(Message::Pong(payload)).await.is_err() {
                            break;
                        }
                    }
                    Some(Ok(_)) => {}
                    Some(Err(_)) | None => break,
                }
            }
        }
    }
}
