`timescale 1ps/1ps
`default_nettype none

module PipeAdderTree #(parameter Elements = 12)(
  input wire clk_in,
  input wire [Elements-1:0][9:0] in,
  output logic signed [9:0] out
);
generate
  if(Elements == 2) begin
    always_ff @(posedge clk_in) out <= in[0] + in[1];
  end else if(Elements == 3) begin
    always_ff @(posedge clk_in) out <= in[0] + in[1] + in[2];
  end else if(Elements == 4) begin
    always_ff @(posedge clk_in) out <= in[0] + in[1] + in[2] + in[3];
  end else begin
    logic [9:0] right;
    logic [9:0] left;
    PipeAdderTree #(.Elements(Elements - Elements/2)) ladder (
      .clk_in(clk_in),
      .in(in[Elements-1:Elements/2]),
      .out(left)
    );
    PipeAdderTree #(.Elements(Elements/2)) radder (
      .clk_in(clk_in),
      .in(in[Elements/2-1:0]),
      .out(right)
    );
    always_ff @(posedge clk_in) out <= left + right;
  end
endgenerate
endmodule
`default_nettype wire