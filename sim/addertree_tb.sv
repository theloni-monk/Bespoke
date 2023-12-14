`default_nettype none
`timescale 1ns/1ps
module addertree_tb();

  logic clk_100mhz = 0;

  logic signed [7:0][9:0] vec = {10'd1, 10'd1, 10'd1, 10'd1, 10'd1, 10'd1, 10'd1, 10'd1};
  logic signed [9:0] out;
  PipeAdderTree #(.Elements(7)) adder (
    .clk_in(clk_100mhz),
    .in(vec),
    .out(out)
  );

  always begin
      #5;  //every 5 ns switch...so period of clock is 10 ns...100 MHz clock
      clk_100mhz = !clk_100mhz;
  end
  //initial block...this is our test simulation
  initial begin
    $dumpfile("addertree_tb.vcd"); //file to store value change dump (vcd)
    $dumpvars(0, addertree_tb);
    $display("Starting Sim"); //print nice message at start
    #30;
    $display("adder tree output: %d | should be 7", out);
    $display("Simulation finished");
    $finish;
  end
endmodule
`default_nettype wire