`timescale 1ps/1ps
`default_nettype none

module CombAdderTree #(parameter Elements)(
  input wire [Elements-1:0][7:0] in,
  output logic signed [7:0] out
);
generate
  if(Elements == 2) begin
    assign out = in[0] + in[1];
  end else begin
    logic [7:0] right;
    logic [7:0] left;
    CombAdderTree #(.Elements(Elements/2)) ladder (
      .in(in[Elements-1:Elements/2]),
      .out(left)
    );
    CombAdderTree #(.Elements(Elements/2)) radder (
      .in(in[Elements/2-1:0]),
      .out(right)
    );
    assign out = left + right;
  end
endgenerate
endmodule
`default_nettype wire