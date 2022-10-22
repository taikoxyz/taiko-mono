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
    base_fee_smoothing: int
    block_and_proof_smoothing: int
    timing: list[Timing]

class Present(NamedTuple):
    title: str
    desc: str
    config: Config

