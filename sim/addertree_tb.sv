`default_nettype none
`timescale 1ns/1ps
module addertree_tb();

  logic clk_in;

  logic signed [7:0][7:0] vec = {8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1};
  logic signed [7:0] out;
  AdderTree #(.Elements(8)) adder (
    .in(vec),
    .out(out)
  );

  always begin
      #5;  //every 5 ns switch...so period of clock is 10 ns...100 MHz clock
      clk_in = !clk_in;
  end
  //initial block...this is our test simulation
  initial begin
    $dumpfile("addertree_tb.vcd"); //file to store value change dump (vcd)
    $dumpvars(0, addertree_tb);
    $display("Starting Sim"); //print nice message at start

    $display("adder tree output: %d | should be 8", out);

    $display("Simulation finished");
    $finish;
  end
endmodule
`default_nettype wire