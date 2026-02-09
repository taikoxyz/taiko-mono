use eyre::{Result, eyre};
use serde::Deserialize;
use url::Url;

#[derive(Clone, Debug)]
pub struct BeaconClient {
    pub seconds_per_slot: u64,
    pub genesis_time_sec: u64,
    pub slots_per_epoch: u64,
}

impl BeaconClient {
    // fetches and constructs a BeaconClient from the given base URL
    pub async fn new(base_url: Url) -> Result<Self> {
        let genesis = Self::fetch_genesis(base_url.clone()).await?;

        let spec = Self::fetch_spec(base_url.clone()).await?;

        // Validate beacon spec invariants to prevent divide-by-zero at runtime
        if spec.seconds_per_slot == 0 {
            return Err(eyre!("Invalid beacon spec: seconds_per_slot must be > 0"));
        }
        if spec.slots_per_epoch == 0 {
            return Err(eyre!("Invalid beacon spec: slots_per_epoch must be > 0"));
        }

        Ok(Self {
            seconds_per_slot: spec.seconds_per_slot,
            genesis_time_sec: genesis.genesis_time,
            slots_per_epoch: spec.slots_per_epoch,
        })
    }

    pub fn genesis_time(&self) -> u64 {
        self.genesis_time_sec
    }

    pub fn current_slot(&self) -> u64 {
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .expect("System time before unix epoch")
            .as_secs();

        (now - self.genesis_time_sec) / self.seconds_per_slot
    }

    pub fn current_epoch(&self) -> u64 {
        self.current_slot() / self.slots_per_epoch
    }

    pub fn slot_in_epoch(&self) -> u64 {
        self.current_slot() % self.slots_per_epoch
    }

    pub fn slots_per_epoch(&self) -> u64 {
        self.slots_per_epoch
    }

    async fn fetch_genesis(base_url: Url) -> Result<Genesis> {
        let genesis_url = base_url
            .join("eth/v1/beacon/genesis")
            .map_err(|_| eyre!("Invalid URL for genesis endpoint"))?;

        let http_client = reqwest::Client::new();
        let response = http_client
            .get(genesis_url)
            .send()
            .await
            .map_err(|_| eyre!("Failed to fetch genesis data"))?;

        if !response.status().is_success() {
            return Err(eyre!("Failed to fetch genesis data: {}", response.status()));
        }

        let beacon_response: BeaconApiResponse<Genesis> =
            response.json().await.map_err(|_| eyre!("Failed to parse genesis data"))?;

        Ok(beacon_response.data)
    }

    async fn fetch_spec(base_url: Url) -> Result<Spec> {
        let spec_url = base_url
            .join("eth/v1/config/spec")
            .map_err(|_| eyre!("Invalid URL for spec endpoint"))?;

        let http_client = reqwest::Client::new();
        let response = http_client
            .get(spec_url)
            .send()
            .await
            .map_err(|_| eyre!("Failed to fetch spec data"))?;

        if !response.status().is_success() {
            return Err(eyre!("Failed to fetch spec data: {}", response.status()));
        }

        let beacon_response: BeaconApiResponse<Spec> =
            response.json().await.map_err(|_| eyre!("Failed to parse spec data"))?;

        Ok(beacon_response.data)
    }
}

#[derive(Deserialize)]
struct BeaconApiResponse<T> {
    data: T,
}

#[derive(Deserialize)]
struct Genesis {
    #[serde(with = "alloy_serde::displayfromstr")]
    genesis_time: u64,
}

#[derive(Deserialize)]
#[serde(rename_all = "UPPERCASE")]
struct Spec {
    #[serde(with = "alloy_serde::displayfromstr")]
    seconds_per_slot: u64,
    #[serde(with = "alloy_serde::displayfromstr")]
    slots_per_epoch: u64,
}

#[cfg(test)]
mod tests {
    use serde_json::json;
    use wiremock::{
        Mock, MockServer, ResponseTemplate,
        matchers::{method, path},
    };

    use super::*;

    #[tokio::test]
    async fn new_fetches_and_parses_genesis_and_spec() -> Result<()> {
        let server = MockServer::start().await;

        // Mock /genesis
        Mock::given(method("GET"))
            .and(path("/eth/v1/beacon/genesis"))
            .respond_with(ResponseTemplate::new(200).set_body_json(json!({
                "data": { "genesis_time": "1700000000" }
            })))
            .mount(&server)
            .await;

        Mock::given(method("GET"))
            .and(path("/eth/v1/config/spec"))
            .respond_with(ResponseTemplate::new(200).set_body_json(json!({
                "data": {
                    "SECONDS_PER_SLOT": "12",
                    "SLOTS_PER_EPOCH": "32"
                }
            })))
            .mount(&server)
            .await;

        let base = Url::parse(&server.uri()).expect("Invalid mock server URL");
        let bc = BeaconClient::new(base).await?;

        assert_eq!(bc.genesis_time_sec, 1_700_000_000);
        assert_eq!(bc.seconds_per_slot, 12);
        assert_eq!(bc.slots_per_epoch, 32);
        Ok(())
    }

    #[tokio::test]
    async fn new_errors_on_non_200_genesis() {
        let server = MockServer::start().await;

        Mock::given(method("GET"))
            .and(path("/eth/v1/beacon/genesis"))
            .respond_with(ResponseTemplate::new(500))
            .mount(&server)
            .await;

        Mock::given(method("GET"))
            .and(path("/eth/v1/config/spec"))
            .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::json!({ "data": {
                "SECONDS_PER_SLOT": "12", "SLOTS_PER_EPOCH": "32"
            }})))
            .mount(&server)
            .await;

        let base = Url::parse(&server.uri()).expect("Invalid mock server URL");
        let err = match BeaconClient::new(base).await {
            Ok(_) => {
                panic!("BeaconClient::new should fail when the genesis endpoint returns non-200")
            }
            Err(err) => err,
        };
        let msg = format!("{err}");
        assert!(msg.contains("Failed to fetch genesis data"));
    }

    #[tokio::test]
    async fn current_slot_epoch_and_slot_in_epoch_are_consistent() -> Result<()> {
        let server = MockServer::start().await;

        // Capture a stable "now" in seconds for expected math
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .expect("Server is behind unix time")
            .as_secs();

        // Choose friendly numbers to avoid off-by-one from sub-second drift
        let seconds_per_slot = 1000u64;
        let slots_per_epoch = 10u64;
        // Set genesis so that (now - genesis) is clearly within the same slot
        let genesis_time = now - (42_000); // 42 slots * 1000s

        // Mocks
        Mock::given(method("GET"))
            .and(path("/eth/v1/beacon/genesis"))
            .respond_with(
                ResponseTemplate::new(200)
                    .set_body_json(json!({"data": { "genesis_time": genesis_time.to_string() }})),
            )
            .mount(&server)
            .await;

        Mock::given(method("GET"))
            .and(path("/eth/v1/config/spec"))
            .respond_with(ResponseTemplate::new(200).set_body_json(json!({"data": {
                "SECONDS_PER_SLOT": seconds_per_slot.to_string(),
                "SLOTS_PER_EPOCH": slots_per_epoch.to_string()
            }})))
            .mount(&server)
            .await;

        let base = Url::parse(&server.uri()).expect("Invalid mock server URL");
        let bc = BeaconClient::new(base).await?;

        // Recompute expected with a fresh "now" to match what the method will read
        let now2 = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .expect("Server is behind unix time")
            .as_secs();
        let delta = now2 - genesis_time;
        let expected_slot = delta / seconds_per_slot;
        let expected_epoch = expected_slot / slots_per_epoch;
        let expected_slot_in_epoch = expected_slot % slots_per_epoch;

        assert_eq!(bc.current_slot(), expected_slot);
        assert_eq!(bc.current_epoch(), expected_epoch);
        assert_eq!(bc.slot_in_epoch(), expected_slot_in_epoch);
        Ok(())
    }
}
