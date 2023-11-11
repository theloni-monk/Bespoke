`default_nettype none
`timescale 1ns/1ps

module VecFIFO #(
  parameter  VecElements = 4,
  parameter  Depth       = 3 )(
  input  logic clk_in,
  input  logic rst_in,
  input  logic writeEn,
  input  logic [VecElements-1:0][7:0] writeData,
  input  logic readEn,
  output logic [VecElements-1:0][7:0] readData,
  output logic dataValid,
  output logic full,
  output logic empty
);
localparam PtrWidth  = $clog2(Depth)
logic [DataWidth-1:0] mem[Depth];
logic [PtrWidth-1:0] wr_ptr;
logic [PtrWidth-1:0] rd_ptr;


always_ff @(posedge clk_in) begin
    if (rst_in) begin
      wr_ptr <= '0;
      rd_ptr <= '0;
    end else begin
      wr_ptr <= writeEn ? wr_ptr + 1 : wr_ptr;
      rd_ptr <= readEn ? rd_ptr + 1 : rd_ptr;
    end
    mem[wr_ptr[PtrWidth-1:0]] <= writeData;
end

assign readData = mem[rd_ptr[PtrWidth-1:0]];
assign empty = (wr_ptr[PtrWidth] == rd_ptr[PtrWidth]) && (wr_ptr[PtrWidth-1:0] == rd_ptr[PtrWidth-1:0]);
assign full  = (wr_ptr[PtrWidth] != rd_ptr[PtrWidth]) && (wr_ptr[PtrWidth-1:0] == rd_ptr[PtrWidth-1:0]);

endmodule


endmodule


`default_nettype wire