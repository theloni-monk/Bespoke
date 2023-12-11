`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

module VecFIFO #(
  parameter  VecElements,
  parameter  BytesPerWrite,
  parameter  BytesPerRead,
  parameter  Depth )(
  input  wire clk_in,
  input wire rst_in,
  input wire wr_en,
  input wire [BytesPerWrite-1:0][7:0] wr_data,
  input wire wrap_rd,
  input wire rd_en,
  output logic [BytesPerRead-1:0][7:0] rd_data
);

logic [Depth*VecElements*8-1:0] mem;
logic [$clog2(Depth*VecElements*8)-1:0] wr_ptr;
logic [$clog2(Depth*VecElements*8)-1:0] rd_ptr;

always_ff @(posedge clk_in) begin
    if (rst_in) begin
      wr_ptr <= 0;
      rd_ptr <= 0;
      for(int i = 0; i<Depth*VecElements; i=i+1) mem[8*i +: 8] <= 0;
    end else begin
      wr_ptr <= wr_en ? wr_ptr + (8*BytesPerWrite) : wr_ptr;
      rd_ptr <= wrap_rd ? rd_ptr - (VecElements * 8) : (rd_en ? rd_ptr + (8*BytesPerRead) : rd_ptr);
    end
    if(wr_en) mem[wr_ptr +: 8*BytesPerWrite] <= wr_data;
end

assign rd_data = mem[rd_ptr +: 8*BytesPerRead];

endmodule

`default_nettype wire