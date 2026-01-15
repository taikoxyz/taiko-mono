# Merge BlobServer into BeaconStubServer

## Problem

The test harness has two separate HTTP servers for mocking beacon-related APIs:

1. **BeaconStubServer** - Serves `/eth/v1/beacon/genesis`, `/eth/v1/config/spec`, `/eth/v2/beacon/blocks/{slot}`
2. **BlobServer** - Serves `/blobs/{hash}` (custom blob server format)

In production, `BlobDataSource` first tries the standard Beacon API (`/eth/v1/beacon/blob_sidecars/{slot}`) and only falls back to the blob server endpoint. Since `BeaconStubServer` lacks the blob sidecar endpoint, tests only exercise the fallback path.

## Solution

Merge blob sidecar functionality into `BeaconStubServer` using the standard Beacon API endpoint format. Support runtime injection of sidecar data.

## API Design

```rust
// Start server (no blob data needed)
let beacon = BeaconStubServer::start().await?;

// Inject sidecars at runtime (can call multiple times)
beacon.add_blob_sidecar(slot, sidecar1);
beacon.add_blob_sidecar(slot, sidecar2);  // same slot, multiple blobs
beacon.add_blob_sidecar(other_slot, sidecar3);  // different slot
```

## New Endpoint

`GET /eth/v1/beacon/blob_sidecars/{slot}`

Response format (matches standard Beacon API):

```json
{
  "data": [
    {
      "blob": "0x...",
      "kzg_commitment": "0x...",
      "kzg_proof": "0x..."
    }
  ]
}
```

## Implementation Steps

### 1. Modify `beacon_stub.rs`

Add shared state for blob sidecars:

```rust
pub struct BeaconStubServer {
    endpoint: Url,
    shutdown: Arc<Notify>,
    handle: JoinHandle<()>,
    blob_sidecars: Arc<RwLock<HashMap<u64, Vec<BlobSidecarData>>>>,
}

struct BlobSidecarData {
    blob: String,       // hex-encoded
    commitment: String, // hex-encoded
    proof: String,      // hex-encoded
}
```

Add injection method:

```rust
impl BeaconStubServer {
    pub fn add_blob_sidecar(&self, slot: u64, sidecar: BlobTransactionSidecar) {
        // Convert sidecar to BlobSidecarData and insert into map
    }
}
```

Add route in `handle_beacon_request`:

```rust
_ if path.starts_with("/eth/v1/beacon/blob_sidecars/") => {
    let slot = parse_slot_from_path(path);
    let sidecars = store.get(&slot).unwrap_or_default();
    // Return JSON response
}
```

### 2. Delete `blob_server.rs`

Remove the entire file.

### 3. Modify `lib.rs`

```diff
 mod beacon_stub;
-mod blob_server;
 mod helper;
 pub mod shasta;

 pub use beacon_stub::BeaconStubServer;
-pub use blob_server::BlobServer;
 pub use helper::{PRIORITY_FEE_GWEI, evm_mine, mine_l1_block};
```

### 4. Modify `shasta/env.rs`

Remove `BlobServer` usage:

```diff
-use crate::BlobServer;

 pub struct ShastaEnv {
     // ...
-    blob_server: Option<BlobServer>,
+    // blob sidecars now managed via BeaconStubServer
 }
```

Remove related methods:

- `start_blob_server()`
- `blob_server_url()`
- `blob_server_endpoint()`

Update `shutdown()` to not handle BlobServer.

### 5. Update Test Files

For any test using `BlobServer`, migrate to:

```rust
let beacon = BeaconStubServer::start().await?;
beacon.add_blob_sidecar(slot, sidecar);
// Use beacon.endpoint() for both beacon and blob data
```

Files to check:

- `crates/driver/tests/proposer_driver_e2e.rs`
- `crates/driver/tests/dual_driver_e2e.rs`
- `crates/driver/tests/preconf_e2e.rs`

## Benefits

1. Tests exercise the primary code path (Beacon API) instead of fallback
2. Simpler test setup (one server instead of two)
3. Reduced code duplication (HTTP server boilerplate)
4. Better alignment between test and production behavior
