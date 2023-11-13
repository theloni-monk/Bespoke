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
    output logic signed [WorkingRegs-1:0][7:0] write_out_data,
    output logic req_chunk_in,
    output logic req_chunk_out,
    output logic out_vector_valid
);

typedef enum logic [1:0] {WAITING, INIT, INIT2,  PROCESSING} mvprod_state;
mvprod_state state;

logic [$clog2(InVecLength*OutVecLength/WorkingRegs)] weight_ptr;
logic signed [WorkingRegs-1:0][7:0] working_regs;
logic signed [7:0] dot;
logic signed [7:0] accumulator;
logic signed [WorkingRegs-1:0][7:0] weight_regs;
// assumes single-cycle fifo
logic [$clog2(InVecLength)-1:0] vec_in_idx;
logic [$clog2(OutVecLength)-1:0] vec_out_idx;
logic row_op_complete;
assign row_op_complete = vec_in_idx == InVecLength-1;
logic all_op_complete;
assign all_op_complete = vec_out_idx == OutVecLength-1;

xilinx_single_port_ram_read_first #(
  .RAM_WIDTH(WorkingRegs*8),                       
  .RAM_DEPTH(InVecLength*OutVecLength/WorkingRegs),
  .RAM_PERFORMANCE("HIGH_PERFORMANCE"), 
  .INIT_FILE(`FPATH(WeightFile))) ( 
  .addra(weight_ptr),
  .dina(24'd0),
  .clka(clk_in),
  .wea(1'd0),
  .ena(1'd1),
  .rsta(rst_in),
  .regcea(1'd1),
  .douta(weight_regs)
);

//TODO: optimize with adder tree
always_comb begin
  dot = working_regs[0] * weight_regs[0];
  for(integer i = 1; i< WorkingRegs; i = i+1) dot = dot + (working_regs[i]*weight_regs[i]);
end

always_ff @(posedge clk_in) begin
  if(rst_in) begin
    vec_in_idx <= 0;
    vec_out_idx <= 0;
    weight_ptr <= 0;
    state <= WAITING;
  end else begin
    if(state == WAITING) begin
      if(in_data_ready) begin
          vec_in_idx <= 1;
          vec_out_idx <= 0;
          working_regs <= 0;
          req_chunk_in <= 1;
          weight_ptr <= 0;
          state <= INIT;
        end else begin
          weight_ptr <= 0;
          req_chunk_in <= 0;
          req_chunk_out <= 0;
          for(int i = 0; i<WorkingRegs; i=i+1) begin
            working_regs[i] = -8'sd1; // sentinal value
          end
        end
    end else if(state == INIT) begin
      weight_ptr <= 0;
      working_regs <= in_data;
      req_chunk_in <= 0;
      req_chunk_out <= 0;
      state <= PROCESSING;
    end else if(state == INIT2) begin // this stage waits for pipelined weight ptr to be updated
      weight_ptr <= 1;
      req_chunk_in <= 1;
      req_chunk_out <= 0;
      state <= PROCESSING;
    end else if(state == PROCESSING) begin
      weight_ptr <= weight_ptr + 1;
      if(all_op_complete) begin
        state <= in_data_ready ? INIT : WAITING;
        accumulator <= 0;
      end else if(row_op_complete) begin
        accumulator <= 0;
        write_out_data <= accumulator;
        vec_out_idx <= vec_out_idx + 1;
      end else begin
        accumulator <= accumulator + dot;
      end
      req_chunk_out <= 1;
    end
  end
end

endmodule
`default_nettype wire