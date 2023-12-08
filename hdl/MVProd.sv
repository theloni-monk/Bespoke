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

typedef enum logic [2:0] {WAITING, INIT, ACCUMULATING, FLUSHING} mvprod_state;
mvprod_state state;

logic [$clog2(InVecLength*OutVecLength/WorkingRegs)-1:0] weight_ptr;
logic signed [WorkingRegs-1:0][7:0] vector_regs;
logic signed [WorkingRegs-1:0][7:0] product_regs;
logic signed [7:0] dot;
logic signed [7:0] accumulator;
logic signed [WorkingRegs-1:0][7:0] weight_regs;
// assumes single-cycle fifo
logic [$clog2(InVecLength)-1:0] vec_in_idx;
logic [$clog2(OutVecLength)-1:0] vec_out_idx;
logic row_op_complete;
assign row_op_complete = vec_in_idx == 0;
logic all_op_complete;
assign all_op_complete = vec_out_idx == 0;
//assign out_vector_valid = all_op_complete;
xilinx_single_port_ram_read_first #(
  .RAM_WIDTH(WorkingRegs*8),
  .RAM_DEPTH(InVecLength*OutVecLength/WorkingRegs),
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
generate
if(InVecLength & (InVecLength-1) == 0)
AdderTree #(.Elements(WorkingRegs)) atree (
  .in(product_regs),
  .out(dot)
);
else begin
  always_comb begin
    dot = product_regs[0];
    for (integer i = 1; i<WorkingRegs; i = i+1 ) dot = dot + product_regs[i];
  end
end
endgenerate
always_ff @(posedge clk_in) begin
  if(rst_in) begin
    vec_in_idx <= 0;
    vec_out_idx <= 1;
    weight_ptr <= 0;
    accumulator <= 0;
    out_vector_valid <= 0;
    state <= WAITING;
    req_chunk_ptr_rst <= 0;
  end else begin
    if(state == WAITING) begin
      if(in_data_ready) begin
        vec_in_idx <= 0;
        vec_out_idx <= 1;
        vector_regs <= 0;
        req_chunk_in <= 0;
        weight_ptr <= 0;
        state <= INIT;
      end else begin
        weight_ptr <= 0;
        vec_out_idx <= 1;
        req_chunk_in <= 0;
        req_chunk_out <= 0;
        for(int i = 0; i<WorkingRegs; i=i+1) begin
          vector_regs[i] = -8'sd1; // sentinal value
        end
      end
      out_vector_valid <= 0;
    end else if(state == INIT) begin
      out_vector_valid <= 0;
      vec_in_idx <= WorkingRegs;
      vec_out_idx <= 1;
      weight_ptr <= 0;
      vector_regs <= in_data;
      req_chunk_ptr_rst <= 0;
      req_chunk_in <=  InVecLength > WorkingRegs;
      req_chunk_out <= 0;
      accumulator <= 0;
      state <= ACCUMULATING;
    end else if(state == ACCUMULATING) begin
      req_chunk_out <= 0;
      req_chunk_ptr_rst <= 0;
      vector_regs <= in_data;
      weight_ptr <= weight_ptr + 1 >= InVecLength*OutVecLength/WorkingRegs ? 0 : weight_ptr + 1;
      if(row_op_complete) begin
        req_chunk_in <= 0;
        req_chunk_ptr_rst <= ~all_op_complete;
        state <= FLUSHING;
      end else begin
        req_chunk_in <= 1;
        req_chunk_ptr_rst <= 0;
        vec_in_idx <= vec_in_idx + WorkingRegs >= InVecLength ? 0 : vec_in_idx + WorkingRegs;
      end
      accumulator <= accumulator + dot;
    end else if(state==FLUSHING) begin
      vector_regs <= 0;
      req_chunk_ptr_rst <= 0;
      req_chunk_out <= 1; 
      write_out_data <= accumulator + dot;
      if(all_op_complete) begin
        out_vector_valid <= 1;
        if(in_data_ready)begin
          vec_in_idx <= 0;
          vec_out_idx <= 1;
          vector_regs <= 0;
          req_chunk_in <= 0;
          weight_ptr <= 0;
          state <= INIT;
        end else state <= WAITING;
      end
      else begin
        state <= ACCUMULATING;
        accumulator <= 0;
        req_chunk_in <= 1;
        vec_out_idx <= vec_out_idx + 1;
        vec_in_idx <= WorkingRegs;
      end
    end
  end
end

endmodule
`default_nettype wire