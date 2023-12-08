from typing import List
from dataclasses import dataclass

import onnx

from .ml_modules import *

@dataclass
class FPGASpec():
    num_dsp48: int
    num_reg: int
    total_bram: int
    max_clock: int

def gen_bram_file(path, read_bytes, data):
    with open(path, 'w') as f:
        if(len(data.shape) > 1):
            for x in range(data.shape[0]): # row major
                for y in range(data.shape[1] // read_bytes):
                    for i in range(read_bytes):
                        f.write(f'{int(data[x, y*read_bytes+i]):02x}')
                    f.write('\n')
        else:
            for x in range(data.shape[0] // read_bytes):
                for i in range(read_bytes):
                    f.write(f'{int(data[x*read_bytes+i]):02x}')

class FPGAModule():

    model: onnx.ModelProto

    in_dim: int
    out_dim: int
    spec: FPGASpec
    avail_bram: int

    clk: Var
    rst: Var
    in_data_ready: Var
    modules: List[MLModule]

    def __init__(self, model, spec):
        self.model = model
        self.clk = Var("clk_in", True, 0, False)
        self.rst = Var("rst_in", True, 0, False)
        self.spec = spec
        self.avail_bram = spec.total_bram
        self.in_data_ready = Var("in_data_ready", True, 0, False)

    def alloc_bram(self):
        for mod in self.modules:
            if type(mod) == MVProd:
                mod.weightfile = f"data/{mod.name}_wfile.mem"
                gen_bram_file(f"data/{mod.name}_wfile.mem", mod.working_regs, mod.bram)
                self.avail_bram -= mod.bram.size * 8
            elif type(mod) == Bias:
                mod.biasfile = f"data/{mod.name}_bfile.mem"
                gen_bram_file(f"data/{mod.name}_bfile.mem", mod.working_regs, mod.bram)
                self.avail_bram -= mod.bram.size * 8
        assert self.avail_bram > 0, "Insufficient BRAM"

    def alloc_regs(self):
        num_ml_mods = (len(self.modules)-1)//2
        for mod in self.modules:
            mod.working_regs = min(mod.in_vec_size, self.spec.num_reg//num_ml_mods)
            mod.in_data.num_bytes = mod.working_regs
            mod.write_out_data.num_bytes = min(mod.working_regs, mod.out_vec_size if type(mod) == MVProd else mod.working_regs)
        self.modules[0].bytes_per_read = self.modules[1].working_regs
        self.modules[0].bytes_per_write = 1
        for idx, fifo in enumerate(self.modules[1:-2]):
            if type(fifo) != VecFIFO:
                continue
            fifo.bytes_per_write = min(self.modules[idx-1].working_regs, mod.out_vec_size if type(mod) == MVProd else mod.working_regs)
            fifo.bytes_per_read = self.modules[idx+1].working_regs
        self.modules[-1].bytes_per_write = self.modules[-2].working_regs
        self.modules[-1].bytes_per_read = 1

    def make_sv(self):
        input_fifo = self.modules[0]
        output_fifo = self.modules[-1]
        return f"""
{input_fifo.systemverilog()}
{output_fifo.systemverilog()}
module MLInference(
    input wire clk_in,
    input wire rst_in,
    input wire in_data_ready,
    output logic out_data_ready
);
  {'''
'''.join([mod.systemverilog() for mod in self.modules[1:-1]])}
endmodule;
logic ml_inf_valid;
MLInference ml_inf(
    .clk_in(),
    .rst_in(),
    .in_data_ready(),
    .out_data_ready(ml_inf_valid)
);
"""