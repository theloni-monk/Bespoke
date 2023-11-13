//WRITEME: ReLU
`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

module ReLU 
#(  parameter InVecLength, 
    parameter WorkingRegs ) (
    input wire clk_in,
    input wire rst_in,
    input wire in_data_ready,
    input wire signed [WorkingRegs-1:0][7:0] in_data,
    output logic signed [WorkingRegs-1:0][7:0] write_out_data,
    output logic req_chunk_in,
    output logic req_chunk_out,
    output logic out_vector_valid
);

typedef enum logic [1:0] {WAITING, LOADING, PROCESSING} relu_state;
relu_state state;
logic [WorkingRegs-1:0][7:0] working_regs;
// assumes single-cycle fifo
logic [$clog2(InVecLength)-1:0] vec_in_idx;
logic [$clog2(InVecLength)-1:0] vec_out_idx; // InVecLength = OutVecLength, one-to-one map
logic vec_op_complete;
assign vec_op_complete = vec_out_idx == InVecLength-1;
// iterate in incremements of (WorkingRegs) through input ptr space
// ReLU logic is simply a comparison
// we can perform it in (WorkingRegs) pll at a time and write out with our write ptr
always_ff @(posedge clk_in) begin
  if(rst_in) begin
      vec_in_idx <= 0;
      vec_out_idx <= 0;
      state <= WAITING;
  end else begin
    if(state == WAITING) begin
        if(in_data_ready) begin
          vec_in_idx <= 1;
          vec_out_idx <= 0;
          working_regs <= 0;
          req_chunk_in <= 1;
          state <= LOADING;
        end else begin
          req_chunk_in <= 0;
          req_chunk_out <= 0;
          for(int i = 0; i<WorkingRegs; i=i+1) begin
            working_regs[i] = -8'sd1; // sentinal value
          end
        end
    end else if (state == LOADING) begin
      working_regs <= in_data;
      req_chunk_out <= 0;
      state <= PROCESSING;
    end else if (state == PROCESSING) begin
      working_regs <= in_data;
      for(integer i = 0; i < WorkingRegs; i = i + 1) begin
        write_out_data[i] <= $signed(working_regs[i]) < 0 ? 0: working_regs[i]; //ReLU
      end
      req_chunk_out <= 1;
      vec_in_idx <= vec_in_idx + 1;
      vec_out_idx <= vec_out_idx + 1;
      if(vec_op_complete) begin
        state <= in_data_ready ? LOADING : WAITING;
      end
    end
  end
end

assign out_vector_valid = vec_out_idx == 0;

endmodule

`default_nettype wire