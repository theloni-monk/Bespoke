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

  logic [7:0] byte_in;
  logic in_trigger;
  logic prev_in_trigger;
  logic all_in_ready;
  logic prev_all_in_ready;

  logic [7:0] byte_out;
  logic out_trigger;
  logic all_out_ready;
  manta manta_inst (
    .clk(clk_100mhz),
    .rx(uart_rxd),
    .tx(uart_txd),
    .byte_in(byte_in),
    .in_trigger(in_trigger),
    .all_in_ready(all_in_ready),
    .byte_out(byte_out),
    .out_trigger(out_trigger),
    .all_out_read(all_out_ready));

  always_ff @(posedge clk_100mhz) begin
    
  end

endmodule // top_level

`default_nettype wire