from abc import ABC
from dataclasses import dataclass
from typing import List

@dataclass
class Var:
    name: str
    defined: bool
    num_bytes: int # 0 bytes indicates that it is a logic
    tie_zero: bool

    def define(self):
        self.defined = True
        return f"logic {f'[{self.num_bytes-1}:0][7:0]' if self.num_bytes else ''} {self.name};"

    def __repr__(self):
        return "0" if self.tie_zero else self.name

class MLModule(ABC):
    name: str
    instance_num: int
    in_nodes: list
    out_nodes: list
    visited: bool # for dfs traversal

    in_vec_size: int
    working_regs: int

    clk_in: Var
    rst_in: Var

    in_data_ready: Var
    write_out_data: Var
    in_data: Var
    req_chunk_in: Var
    req_chunk_out: Var
    out_vec_valid: Var

    def __init__(self, in_nodes:list, out_nodes:list, instance_num:int):
        self.name = f"{self.__class__.__name__.lower()}_{instance_num}"
        self.in_nodes = in_nodes
        self.out_nodes = out_nodes
        self.instance_num = instance_num
        self.visited = False
        self.out_vec_valid = Var(f"{self.name}_out_vec_valid_{instance_num}", False, 0, False)

    def __repr__(self):
        return f"{self.name}:{list(v for v in self.variables)}"

    def systemverilog(self):
        raise NotImplementedError

    @property
    def variables(self):
        return [self.in_data_ready, self.in_data, self.write_out_data, self.req_chunk_in, self.req_chunk_out,self.out_vec_valid]

    @property
    def is_source(self):
        return self.in_nodes is []

    @property
    def is_sink(self):
        # handles recurrent relations by defining a node with already visited outputs as terminal
        if self.out_nodes is []:
            return True
        onodes_visited = True
        for node in self.out_nodes:
            onodes_visited &= node.visited
        return onodes_visited

class VecFIFO(MLModule):
    bytes_per_read: int
    bytes_per_write: int
    depth: int

    wrap_rd: Var

    def __init__(self, i_nodes, o_nodes, instance_num, vec_size, bytes_per_read, bytes_per_write, depth, clk_in, rst_in):
        super().__init__(i_nodes,o_nodes, instance_num)
        self.in_vec_size = vec_size
        self.bytes_per_read = bytes_per_read
        self.bytes_per_write = bytes_per_write
        self.depth = depth

        self.clk_in = clk_in
        self.rst_in = rst_in

        self.in_data_ready = Var("dummy_fifo_in_data_ready", True, 0, True)

        self.req_chunk_in = Var(f"wr_en_{instance_num}", False, 0, False)
        self.in_data = Var(f"wr_data_{instance_num}", False, bytes_per_write, False)
        self.req_chunk_out = Var(f"rd_en_{instance_num}", False, 0, False)
        self.write_out_data = Var(f"rd_data_{instance_num}", False, bytes_per_write, False)

        self.wrap_rd = Var(f"wrap_rd_{instance_num}", False, 0, False)

    @property
    def variables(self):
        return super().variables + [self.wrap_rd]

    def systemverilog(self):
        # define captured vars
        defs = [v.define() for v in self.variables]
        defs.append(f"""VecFIFO #(
  .VecElements({self.in_vec_size}),
  .BytesPerRead({self.bytes_per_read}),
  .BytesPerWrite({self.bytes_per_write}),
  .Depth({self.depth})) {self.name} (
  .clk_in({self.clk_in}),
  .rst_in({self.rst_in}),
  .wr_en({self.req_chunk_in}),
  .wr_data({self.in_data}),
  .rd_en({self.req_chunk_out}),
  .rd_data({self.write_out_data}),
  .wrap_rd({self.wrap_rd})
  );""")

        # write instantiation
        return "\n".join(defs)

class MVProd(MLModule):

    out_vec_size: int
    weightfile: str

    req_chunk_ptr_rst: Var

    def __init__(self, inodes, onodes, instance_num):
        super().__init__(inodes, onodes, instance_num)

    @property
    def variables(self):
        return super().variables + [self.req_chunk_ptr_rst]

    def systemverilog(self):
        defs = [v.define() for v in self.variables]
        defs.append(f"""MVProd #(
  .InVecLength({self.in_vec_size}),
  .OutVecLength({self.out_vec_size}),
  .WorkingRegs({self.working_regs}),
  .WeightFile("{self.weightfile}")) {self.name}(
  .clk_in({self.clk_in}),
  .rst_in({self.rst_in}),
  .in_data_ready({self.in_data_ready}),
  .in_data({self.in_data}),
  .write_out_data({self.write_out_data}),
  .req_chunk_in({self.req_chunk_in}),
  .req_chunk_out({self.req_chunk_out}),
  .req_chunk_ptr_rst({self.req_chunk_ptr_rst}),
  .out_vector_valid({self.out_vec_valid})
            );""")
        return "\n".join(defs)

class Bias(MLModule):

    biasfile: str

    def __init__(self, inodes, onodes, instance_num):
        super().__init__(inodes, onodes, instance_num)

    def systemverilog(self):
        defs = [v.define() for v in self.variables]
        defs.append(f"""Bias #(
  .InVecLength({self.in_vec_size}),
  .WorkingRegs({self.working_regs}),
  .BiasFile("{self.biasfile}")) {self.name}(
  .clk_in({self.clk_in}),
  .rst_in({self.rst_in}),
  .in_data_ready({self.in_data_ready}),
  .in_data({self.in_data}),
  .write_out_data({self.write_out_data}),
  .req_chunk_in({self.req_chunk_in}),
  .req_chunk_out({self.req_chunk_out}),
  .out_vector_valid({self.out_vec_valid})
            );""")
        return "\n".join(defs)

class ReLU(MLModule):

    def __init__(self, inodes, onodes, instance_num):
        super().__init__(inodes, onodes, instance_num)

    def systemverilog(self):
        defs = [v.define() for v in self.variables]
        defs.append(f"""ReLU #(
  .InVecLength({self.in_vec_size}),
  .WorkingRegs({self.working_regs})) {self.name} (
  .clk_in({self.clk_in}),
  .rst_in({self.rst_in}),
  .in_data_ready({self.in_data_ready}),
  .in_data({self.in_data}),
  .write_out_data({self.write_out_data}),
  .req_chunk_in({self.req_chunk_in}),
  .req_chunk_out({self.req_chunk_out}),
  .out_vector_valid({self.out_vec_valid})
            );""")
        return "\n".join(defs)


