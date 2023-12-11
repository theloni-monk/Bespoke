`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

module top_level(
  input wire clk_100mhz,
  input wire [3:0] btn,
  input wire [15:0] sw, //all 16 input slide switches
  output logic [15:0] led, //16 green output LEDs (located right above switches)
  input wire uart_rxd,
  output logic uart_txd
  );
  assign led = sw; //for debugging

  logic sys_rst;
  assign sys_rst = btn[0];

  logic in_data_ready_master;

  `include "dummy_model.sv"

  manta manta_inst (
    .clk(clk_100mhz),
    .rx(uart_rxd),
    .tx(uart_txd),
    .byte_in(in_data_master),
    .pc_data_put(wr_in_master),
    .all_in_ready(in_data_ready_master),
    .byte_out(out_data_master),
    .pc_data_req(rd_out_master),
    .all_out_ready(ml_inf_valid));
  
endmodule // top_level

`default_nettype wire