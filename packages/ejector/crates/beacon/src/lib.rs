use eyre::{Result, eyre};
use serde::Deserialize;
use url::Url;

#[derive(Clone)]
pub struct BeaconClient {
    pub seconds_per_slot: u64,
    pub genesis_time_sec: u64,
    pub slots_per_epoch: u64,
}

impl BeaconClient {
    pub async fn new(base_url: Url) -> Result<Self> {
        let genesis = Self::fetch_genesis(base_url.clone()).await?;

        let spec = Self::fetch_spec(base_url.clone()).await?;

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
        let now =
            std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_secs();

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
