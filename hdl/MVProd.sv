`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)
module MVProd
#(  parameter InVecLength,
    parameter OutVecLength,
    parameter WorkingRegs,
    parameter WeightFile ) (
    input wire clk_in,
    input wire rst_in,
    input wire in_data_ready,
    input wire signed [WorkingRegs-1:0][7:0] in_data,
    output logic signed [7:0] write_out_data,
    output logic req_chunk_in,
    output logic req_chunk_ptr_rst,
    output logic req_chunk_out,
    output logic out_vector_valid
);

typedef enum logic [2:0] {WAITING, ACCUMULATING, FLUSHING} mvprod_state;
mvprod_state state;
localparam WeightEls = InVecLength*OutVecLength/WorkingRegs;
localparam WeightDepth = $clog2(WeightEls);
logic [WeightDepth-1:0] weight_ptr;
logic signed [WorkingRegs-1:0][7:0] vector_regs;
(* use_dsp = "yes"*) logic signed [WorkingRegs-1:0][7:0] product_regs;
logic signed [7:0] dot;
logic signed [7:0] accumulator;
logic signed [WorkingRegs-1:0][7:0] weight_regs;
// assumes single-cycle fifo
logic [$clog2(InVecLength):0] vec_in_idx;
logic [$clog2(OutVecLength):0] vec_out_idx;
logic row_op_complete;
assign row_op_complete = vec_in_idx == 0;
logic all_op_complete;
assign all_op_complete = vec_out_idx == 0;
//assign out_vector_valid = all_op_complete;
xilinx_single_port_ram_read_first #(
  .RAM_WIDTH(WorkingRegs*8),
  .RAM_DEPTH(WeightEls),
  .RAM_PERFORMANCE("LOW_LATENCY"),
  .INIT_FILE(WeightFile)) weight_ram (
  .addra(weight_ptr),
  .dina(0),
  .clka(clk_in),
  .wea(1'd0),
  .ena(1'd1),
  .rsta(rst_in),
  .regcea(1'd1),
  .douta(weight_regs)
);

always_comb begin
  for(integer i = 0; i < WorkingRegs; i = i+1) product_regs[i] = (vector_regs[WorkingRegs-1-i] * weight_regs[i]);
end

localparam DotWaitCycles = $clog2(WorkingRegs);
logic [DotWaitCycles:0] dot_cycles;
PipeAdderTree #(.Elements(WorkingRegs)) atree (
  .clk_in(clk_in),
  .in(product_regs),
  .out(dot)
);

always_ff @(posedge clk_in) begin
  if(rst_in) begin
    vec_in_idx <= 0;
    vec_out_idx <= 1;
    weight_ptr <= 0;
    accumulator <= 0;
    out_vector_valid <= 0;
    state <= WAITING;
    req_chunk_in <= 0;
    req_chunk_out <= 0;
    req_chunk_ptr_rst <= 0;
    dot_cycles <= 0;
  end else if(state == WAITING) begin
    if(in_data_ready) begin
      state <= ACCUMULATING;
      req_chunk_in <= InVecLength > WorkingRegs; //
      // for(integer i = 0; i< WorkingRegs; i= i+1) vector_regs[i] <= in_data[i]; //
    end else begin
      req_chunk_in <= 0;
      for(int i = 0; i<WorkingRegs; i=i+1) vector_regs[i] = 0;
    end
    vec_in_idx <= WorkingRegs >= InVecLength ? 0 : WorkingRegs; //
    vec_out_idx <= 1;
    req_chunk_out <= 0;
    req_chunk_ptr_rst <= 0;
    weight_ptr <= 0;
    dot_cycles <= 0;
    accumulator <= 0;
    out_vector_valid <= 0;
  end else if(state == ACCUMULATING) begin
    out_vector_valid <= 0;
    req_chunk_out <= 0;
    req_chunk_ptr_rst <= 0;
    for(integer i = 0; i< WorkingRegs; i= i+1) vector_regs[i] <= in_data[i];
    weight_ptr <= weight_ptr + 1 >= InVecLength*OutVecLength/WorkingRegs ? 0 : weight_ptr + 1;
    if(row_op_complete) begin
      req_chunk_in <= ~((~all_op_complete) & WorkingRegs < InVecLength) & WorkingRegs < InVecLength;
      req_chunk_ptr_rst <= (~all_op_complete) & WorkingRegs < InVecLength;
      dot_cycles <= 1;
      state <= FLUSHING;
    end else begin
      req_chunk_in <= vec_in_idx < InVecLength - WorkingRegs;
      req_chunk_ptr_rst <= 0;
      vec_in_idx <= vec_in_idx + WorkingRegs >= InVecLength ? 0 : vec_in_idx + WorkingRegs;
      dot_cycles <= 0;
    end
    accumulator <= accumulator + dot;
  end else if(state==FLUSHING) begin
    if(dot_cycles == DotWaitCycles) begin
      dot_cycles <= 0;
      req_chunk_out <= 1;
      write_out_data <= accumulator + dot;//;
      if(all_op_complete) begin
        out_vector_valid <= 1;
        if(in_data_ready)begin
          vec_in_idx <= WorkingRegs >= InVecLength ? 0 : WorkingRegs;
          vec_out_idx <= 1;
          req_chunk_in <= WorkingRegs < InVecLength;
          vector_regs <= 0;
          weight_ptr <= 0;
          state <= ACCUMULATING;
        end else state <= WAITING;
      end
      else begin
        state <= ACCUMULATING;
        accumulator <= 0;
        req_chunk_in <= WorkingRegs < InVecLength;
        vec_out_idx <= vec_out_idx + 1 >= OutVecLength ? 0 : vec_out_idx + 1;
        vec_in_idx <= WorkingRegs >= InVecLength ? 0 : WorkingRegs;
      end
    end else begin
      req_chunk_in <= 0;
      vector_regs <= 0;
      req_chunk_ptr_rst <= 0;
      accumulator <= accumulator + dot;
      dot_cycles <= dot_cycles + 1;
    end
  end
end
endmodule;


`default_nettype wire