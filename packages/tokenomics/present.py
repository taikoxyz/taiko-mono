from typing import NamedTuple


class Timing(NamedTuple):
    block_time_avg_second: int
    block_time_sd_pctg: int
    proof_time_avg_minute: int
    proof_time_sd_pctg: int


class Config(NamedTuple):
    max_slots: int
    lamda_ratio: float
    base_fee: int
    base_fee_maf: int
    reward_min_ratio: float
    reward_max_ratio: float
    reward_tax_pctg: float
    block_and_proof_time_maf: int
    timing: list[Timing]


class Present(NamedTuple):
    title: str
    desc: str
    days: int
    config: Config
