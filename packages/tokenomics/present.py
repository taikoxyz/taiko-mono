from typing import NamedTuple


class Timing(NamedTuple):
    block_time_avg_second: int
    proof_time_avg_minute: int


class Config(NamedTuple):
    max_blocks: int
    lamda: float
    fee_base: int
    fee_maf: int
    reward_multiplier: float
    block_time_sd_pctg: int
    proof_time_sd_pctg: int
    time_avg_maf: int
    timing: list[Timing]


class Present(NamedTuple):
    title: str
    desc: str
    days: int
    config: Config
