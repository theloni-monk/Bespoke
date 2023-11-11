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
    output wire [$clog2(InVecLength)-1:0] read_in_req_ptr,
    output logic [$clog2(InVecLength)-1:0] write_out_req_ptr,
    output logic signed [WorkingRegs-1:0][7:0] write_out_data,
    output logic out_vector_valid
);

typedef enum logic[2:0] {WAITING, PROCESSING} mod_state;
mod_state state;
logic [WorkingRegs-1:0][7:0] working_regs;
// assumes single-cycle fifo
logic [$clog2(InVecLength)-1:0] vec_in_idx;
logic [$clog2(InVecLength)-1:0] vec_out_idx; // InVecLength = OutVecLength, one-to-one map

// iterate in incremements of (WorkingRegs) through input ptr space
// ReLU logic is simply a comparison
// we can perform it in (WorkingRegs) pll at a time and write out with our write ptr
always_ff @(posedge clk_in) begin
  if(rst_in) begin
      vec_in_idx <= 0;
      state <= WAITING;
  else begin
      if(state == WAITING) begin
          if(in_data_ready) begin
            vec_in_idx <= WorkingRegs;
            vec_out_idx <= 0;
            working_regs <= in_data;
          end
      end else if (state == PROCESSING) begin
        for(i = 0; i < WorkingRegs; i = i + 1) begin
          write_out_data[i] <= $signed(working_regs[i]) < 0 ? 0: working_regs[i]; //ReLU
        end
        vec_out_ptr <= vec_out_ptr == InVecLength - WorkingRegs ? 0 : vec_out_ptr + WorkingRegs;
        vec_in_ptr <= vec_in_ptr == InVecLength - WorkingRegs ? 0 : vec_in_ptr + WorkingRegs;
        if(vec_out_ptr == InVecLength - WorkingRegs && !in_data_ready) begin
          state <= WAITING;
          vec_in_ptr <= 0;
        end
      end
    end
  end
end

always_comb begin
  read_in_req_ptr = vec_in_idx;
  write_out_req_ptr = vec_out_idx;
  out_vector_valid = vec_out_ptr == 0;
end
endmodule

`default_nettype wire