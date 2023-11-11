`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)
module ReLU 
#(  parameter InVecLength, 
    parameter OutVecLength,
    parameter WorkingRegs,
    parameter WeightFile ) (
    input wire clk_in,
    input wire rst_in,
    input wire in_data_ready,
    input wire [WorkingRegs-1:0][7:0] in_data,
    output wire [$clog2(InVecLength)-1:0] read_in_req_ptr,
    output logic [$clog2(InVecLength)-1:0] write_out_req_ptr,
    output logic [WorkingRegs-1:0][7:0] write_out_data,
    output logic out_vector_valid
);
localparam WeightPtrBits = $clog2(InVecLength*OutVecLength);
logic [] weight_ptr;

logic [$clog2(InVecLength)-1:0] vec_in_idx;
logic [$clog2(OutVecLength)-1:0] vec_out_idx;

xilinx_single_port_ram_read_first #(
    .RAM_WIDTH(WorkingRegs*8),                       // Specify RAM data width
    .RAM_DEPTH(256),                     // Specify RAM depth (number of entries)
    .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
    .INIT_FILE(`FPATH(WeightFile))          // Specify name/location of RAM initialization file if using one (leave blank if not)
   ) palette_ram (
    .addra(weight_ptr),     // Address bus, width determined from RAM_DEPTH
    .dina(24'd0),       // RAM input data, width determined from RAM_WIDTH
    .clka(clk_in),       // Clock
    .wea(1'd0),         // Write enable
    .ena(1'd1),         // RAM Enable, for additional power savings, disable port when not in use
    .rsta(rst_in),       // Output reset (does not affect memory contents)
    .regcea(1'd1),   // Output register enable
    .douta(true_color)      // RAM output data, width determined from RAM_WIDTH
  );

endmodule
`default_nettype wire