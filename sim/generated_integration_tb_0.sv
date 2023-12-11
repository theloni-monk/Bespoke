`default_nettype none
`timescale 1ns/1ps

module generated_integration_tb_0();
/**
 [-1 -2 -3 -4 -5 -6 -7 -8], [-9 -10 -11 -12 -13 -14 -15 -16]
 -> MVProd(permutation) [-8 -7 -6 -5 -4 -3 -2 -1] [-16 -15 -14 -13 -12 -11 -10 -9]
 -> Bias(1 2 3 4 5 6 7 8) [-7 -5 -3 -1 1 3 5 7][-15 -13 -11 -9 -7 -5 -3 -1]
 -> ReLU [0 0 0 0 1 3 5 7][0 0 0 0 0 0 0 0]
*/
  logic clk_100mhz;
  logic sys_rst;
  logic in_data_ready_master;

  `include "dummy_model.sv"

  always begin
      #5;  //every 5 ns switch...so period of clock is 10 ns...100 MHz clock
      clk_100mhz = !clk_100mhz;
  end
  //initial block...this is our test simulation
  initial begin
    $dumpfile("generated_integration_tb_0.vcd"); //file to store value change dump (vcd)
    $dumpvars(0, generated_integration_tb_0);
    $display("Starting Sim"); //print nice message at start
    clk_100mhz = 0;
    sys_rst = 0;
    in_data_ready_master = 0;
    wr_in_master = 0;
    rd_out_master = 0;
    #10;
    sys_rst = 1;
    #10;
    sys_rst = 0;
    #10;
    wr_in_master = 1;
    for (byte i = 0; i<8; i=i+1)begin
      $display("write chunk %d writing %d", i, 0);
      in_data_master = 0;
      #10;
    end
    in_data_ready_master = 1;
    #10
    in_data_ready_master = 0;
    #1500;
    rd_out_master = 1;
    for (byte i = 0; i<8; i = i+ 1)begin
      $display("read chunk %d read %d", i, $signed(out_data_master));
      #10;
    end
    rd_out_master = 0;
    #100;
    $display("Simulation finished, rvecvalid? %b", ml_inf_valid);
    $finish;
  end
endmodule

`default_nettype wire