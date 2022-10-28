from typing import NamedTuple


class Timing(NamedTuple):
    block_time_avg_second: int
    block_time_sd_pctg: int
    proof_time_avg_minute: int
    proof_time_sd_pctg: int


class Config(NamedTuple):
    max_slots: int
    lamda: float
    base_fee: int
    base_fee_maf: int
    block_fee_min_ratio: float
    prover_reward_max_ratio: float
    prover_reward_burn_points: float
    prover_reward_bootstrap: int
    prover_reward_bootstrap_day: int
    block_and_proof_time_maf: int
    timing: list[Timing]


class Present(NamedTuple):
    title: str
    desc: str
    days: int
    config: Config
