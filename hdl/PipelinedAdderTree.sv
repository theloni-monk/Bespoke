`timescale 1ps/1ps
`default_nettype none
//FIXME: calc exactly how many cycles for correct result
module PipeAdderTree #(parameter Elements = 12)(
  input wire clk_in,
  input wire [Elements-1:0][7:0] in,
  output logic signed [7:0] out
);
generate
  if(Elements == 1) begin
    always_ff @(posedge clk_in) out <= in;
  end else if(Elements == 2) begin
    always_ff @(posedge clk_in) out <= in[0] + in[1];
  end else begin
    always_ff @(posedge clk_in) begin
      leftin <= in[Elements-1:Elements/2];
      rightin <= in[Elements/2-1:0];
    end
    logic [Elements-(Elements/2)-1:0][7:0] leftin;
    logic [(Elements/2)-1:0][7:0] rightin;
    logic [7:0] leftout;
    logic [7:0] rightout;
    PipeAdderTree #(.Elements(Elements - Elements/2)) ladder (
      .clk_in(clk_in),
      .in(leftin),
      .out(leftout)
    );
    PipeAdderTree #(.Elements(Elements/2)) radder (
      .clk_in(clk_in),
      .in(rightin),
      .out(rightout)
    );
    assign out = leftout + rightout;
  end
endgenerate
endmodule
`default_nettype wire