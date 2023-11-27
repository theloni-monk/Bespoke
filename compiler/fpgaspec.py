from dataclasses import dataclass

@dataclass
class FPGASpec():
    num_dsp48: int
    num_reg: int
    total_bram: int
    max_clock: int
