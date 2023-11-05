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

  always_ff @(posedge clk_100mhz) begin
  end

  manta intf (
    .clk(clk_100mhz),
    .tx(uart_txd),
    .rx(uart_rxd),
    .val3_out(y),
    .val4_out(x),
    .val1_in(sw[0] ? fsos : quot),
    .val2_in(sw[0] ? finvsqrt : rem)
  );

endmodule // top_level

`default_nettype wire