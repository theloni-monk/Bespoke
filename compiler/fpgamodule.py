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

class FPGAModule():

    model: onnx.ModelProto

    in_dim: int
    out_dim: int
    spec: FPGASpec

    clk: Var
    rst: Var
    in_data_ready: Var
    modules: List[MLModule]

    def __init__(self, model, in_dim, out_dim, spec):
        self.model = model
        self.clk = Var("clk_in", True, 0, False)
        self.rst = Var("rst_in", True, 0, False)
        self.spec = spec
        self.in_data_ready = Var("in_data_ready_master", False, 0, False)

    def alloc_bram(self):
        for mod in self.modules:
            if type(mod) == MVProd:
                mod.weightfile = f"data/{mod.name}_dummy_wfile.mem"
            elif type(mod) == Bias:
                mod.biasfile = f"data/{mod.name}_dummy_bfile.mem"

    #WRITEME: keep track of initializer matricies and generate bram files
    def gen_bram_files(self):
        pass

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
{self.clk.define()}
{self.rst.define()}
{input_fifo.systemverilog()}
{output_fifo.systemverilog()}
{self.in_data_ready.define()}
module MLInference(
    input wire clk_in,
    input wire rst_in,
    input wire in_data_ready,
    input wire signed [{input_fifo.bytes_per_read-1}:0][7:0] data_in,
    output logic req_chunk_in,
    output logic req_chunk_out,
    output logic signed [{output_fifo.bytes_per_write-1}:0][7:0] data_out,
    output logic out_data_ready,
)
  {'''
'''.join([mod.systemverilog() for mod in self.modules[1:-1]])}
endmodule;
"""
    def make_brams(self, bram_path):
        pass