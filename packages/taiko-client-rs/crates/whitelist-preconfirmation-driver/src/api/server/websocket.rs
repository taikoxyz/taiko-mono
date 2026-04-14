//! Websocket notification stream handling.

use axum::extract::ws::{Message, WebSocket};
use futures::StreamExt;
use tokio::sync::broadcast;
use tracing::warn;

use crate::api::types::EndOfSequencingNotification;

/// Push EOS notifications over a connected websocket until disconnect.
pub(super) async fn serve_websocket_notifications(
    mut websocket: WebSocket,
    mut notifications: broadcast::Receiver<EndOfSequencingNotification>,
) {
    loop {
        tokio::select! {
            result = notifications.recv() => {
                if !handle_notification(&mut websocket, result).await {
                    break;
                }
            }
            incoming = websocket.next() => {
                if !handle_incoming(&mut websocket, incoming).await {
                    break;
                }
            }
        }
    }
}

/// Process one broadcast notification. Returns `false` when the loop should exit.
async fn handle_notification(
    websocket: &mut WebSocket,
    result: std::result::Result<EndOfSequencingNotification, broadcast::error::RecvError>,
) -> bool {
    match result {
        Ok(notification) => {
            let payload = match serde_json::to_string(&notification) {
                Ok(p) => p,
                Err(err) => {
                    warn!(error = %err, "failed to serialize websocket EOS notification");
                    return true; // skip this message, keep going
                }
            };
            websocket.send(Message::Text(payload)).await.is_ok()
        }
        Err(broadcast::error::RecvError::Lagged(skipped)) => {
            warn!(skipped, "whitelist websocket subscriber lagged behind EOS notifications");
            true
        }
        Err(broadcast::error::RecvError::Closed) => false,
    }
}

/// Process one incoming websocket frame. Returns `false` when the loop should exit.
async fn handle_incoming(
    websocket: &mut WebSocket,
    incoming: Option<std::result::Result<Message, axum::Error>>,
) -> bool {
    match incoming {
        Some(Ok(Message::Ping(payload))) => websocket.send(Message::Pong(payload)).await.is_ok(),
        Some(Ok(Message::Close(_))) | Some(Err(_)) | None => false,
        Some(Ok(_)) => true,
    }
}
