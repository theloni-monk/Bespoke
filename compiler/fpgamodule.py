from typing import List
from dataclasses import dataclass
from functools import reduce

def factors(n):
    return set(reduce(list.__add__,
                ([i, n//i] for i in range(1, int(n**0.5) + 1) if n % i == 0)))
import onnx

from .ml_modules import *

@dataclass
class FPGASpec():
    num_dsp: int
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

def next_smallest_factor(vec_size, max_factor):
    largest_under = 1
    for i in sorted(factors(vec_size)):
        if i < max_factor:
            largest_under = i
        else:
            break
    return largest_under

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
        num_mult_mods = sum(1 if type(mod) == MVProd else 0 for mod in self.modules)
        for mod in self.modules:
            if type(mod) == MVProd:
                mod.working_regs = next_smallest_factor(mod.in_vec_size, self.spec.num_dsp//num_ml_mods)
                mod.write_out_data.num_bytes = 1
            else:
                mod.working_regs = next_smallest_factor(mod.in_vec_size, self.spec.num_reg//num_ml_mods)
                mod.write_out_data.num_bytes = mod.working_regs
            mod.in_data.num_bytes = mod.working_regs

        self.modules[0].bytes_per_read = self.modules[1].working_regs
        self.modules[0].bytes_per_write = 1
        self.modules[0].in_data.num_bytes = 1
        for idx, fifo in enumerate(self.modules):
            if idx == 0 or idx == len(self.modules)-1:
                continue
            if type(fifo) != VecFIFO:
                continue
            fifo.bytes_per_write = 1 if type(self.modules[idx-1]) == MVProd else self.modules[idx-1].working_regs
            if type(self.modules[idx-1]) == MVProd: #HACK
                fifo.in_data.num_bytes = 1
            fifo.bytes_per_read = self.modules[idx+1].working_regs
        self.modules[-1].bytes_per_write = self.modules[-2].working_regs
        self.modules[-1].bytes_per_read = 1
        self.modules[-1].write_out_data.num_bytes = 1

    def make_sv(self):
        input_fifo = self.modules[0]
        input_fifo.req_chunk_in.name = "wr_in_master"
        input_fifo.in_data.name = "in_data_master"
        input_fifo.clk_in = Var("clk_100mhz", True, 0, False)
        input_fifo.rst_in = Var("sys_rst", True, 0, False)

        output_fifo = self.modules[-1]
        output_fifo.req_chunk_out.name = "rd_out_master"
        output_fifo.write_out_data.name = "out_data_master"
        output_fifo.clk_in = Var("clk_100mhz", True, 0, False)
        output_fifo.rst_in = Var("sys_rst", True, 0, False)

        first_proc_node = self.modules[1]
        first_proc_node.in_data_ready.name = "in_data_ready"
        first_proc_node.in_data_ready.defined = True

        last_proc_node = self.modules[-2]
        last_proc_node.out_vec_valid.name = "out_data_ready"
        last_proc_node.out_vec_valid.defined = True
        return f"""
localparam INVECWIDTH = {self.modules[0].in_vec_size};
localparam OUTVECWIDTH = {self.modules[-1].in_vec_size};
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
    .clk_in(clk_100mhz),
    .rst_in(sys_rst),
    .in_data_ready(in_data_ready_master),
    .out_data_ready(ml_inf_valid)
);
"""