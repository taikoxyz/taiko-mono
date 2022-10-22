from typing import NamedTuple

class SimConfig(NamedTuple):
    duration_days: int
    max_slots: int
    lamda_ratio: float
    base_fee: int
    base_fee_smoothing: int
    block_and_proof_smoothing: int
    block_time_avg_second: int
    block_time_sd_ptcg: int
    proof_time_avg_minute: int
    proof_time_sd_pctg: int

class Present(NamedTuple):
    title: str
    desc: str
    config: SimConfig

