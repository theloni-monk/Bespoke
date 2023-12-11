import onnx
from collections import Counter
import numpy as np
from .fpgamodule import FPGAModule
from . import ml_modules

def to_ml_module(nodename):
    # Translates from onnx op_type to corresponding fpga module class
    return {"MatMulInteger": ml_modules.MVProd,
            "Relu": ml_modules.ReLU,
            "Add": ml_modules.Bias }[nodename]

def parse_model(onnx_model, initdim,  spec):
    weights = onnx_model.graph.initializer
    wnames = map(lambda w: w.name, weights)
    wdict = dict(zip(wnames, weights))

    instancecounter = Counter()

    fpga_module = FPGAModule(onnx_model, spec)
    currdim = initdim

    # shitty non-recursive construction
    fpga_module.modules = [ml_modules.VecFIFO([], [], 0, initdim, -1, -1, 4, fpga_module.clk, fpga_module.rst)]
    num_fifos = 1
    for idx, node in enumerate(onnx_model.graph.node):
        try:
            mod = to_ml_module(node.op_type)([fpga_module.modules[-1]], [], instancecounter[node.op_type])
        except KeyError: # the node has no systemverilog representation
            continue

        instancecounter[node.op_type] += 1
        mod.in_vec_size = currdim

        if node.op_type == "Add" or node.op_type == "MatMulInteger":
            mod.bram = onnx.numpy_helper.to_array(wdict[node.input[1]]).astype(np.int8).view(np.uint8)
        if node.op_type == "MatMulInteger":
            newdim = wdict[node.input[1]].dims[-1]
            mod.out_vec_size = newdim
            mod.req_chunk_ptr_rst = fpga_module.modules[-1].wrap_rd
            currdim = newdim
        else:
            fpga_module.modules[-1].wrap_rd.tie_zero = True

        mod.clk_in = fpga_module.clk
        mod.rst_in = fpga_module.rst
        mod.in_data = fpga_module.modules[-1].write_out_data
        mod.req_chunk_in = fpga_module.modules[-1].req_chunk_out

        fpga_module.modules[-1].out_nodes.append(mod)
        fpga_module.modules.append(mod)
        fifo = ml_modules.VecFIFO([mod], [], num_fifos, currdim, -1, -1, 2, fpga_module.clk, fpga_module.rst)
        num_fifos += 1
        mod.req_chunk_out = fifo.req_chunk_in
        mod.write_out_data = fifo.in_data

        fpga_module.modules.append(fifo)
        if idx > 0:
            fpga_module.modules[-2].in_data_ready = fpga_module.modules[-4].out_vec_valid
        else:
            fpga_module.modules[-2].in_data_ready = fpga_module.in_data_ready
    fpga_module.modules[-1].wrap_rd.tie_zero = True
    return fpga_module