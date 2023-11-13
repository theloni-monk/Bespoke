`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

module spi_tx
       #(   parameter DATA_WIDTH = 8,
            parameter DATA_PERIOD = 100
        )
        ( input wire clk_in,
          input wire rst_in,
          input wire [DATA_WIDTH-1:0] data_in,
          input wire trigger_in,
          output logic data_out,
          output logic data_clk_out,
          output logic sel_out
        );

  parameter DATA_HALF_PERIOD = DATA_PERIOD>>1; // remove the last one to floor it to a multiple of two then divide by 2

  logic started;
  logic [11:0] cycles;
  logic [$clog2(DATA_WIDTH)-1:0] d_out_idx;

  logic[DATA_WIDTH-1:0] outbits;
  logic outbit;

  logic trigger_flag;
  logic d_clk;
  always_ff @(posedge clk_in) begin
    
    if(rst_in) begin
        d_clk <= 1;
        cycles <= 0;
        d_out_idx <= 0;
        started <= 0;
        outbits <= 0;
        outbit <= 0;
    end
    else begin
        if(trigger_in & (~started)) begin // ignore trigger_in if already started
            outbits <= data_in;
            trigger_flag <= 1;
        end
        // this else makes it work, without it doesn't transmit
        else if(trigger_flag)begin // falling edge of trigger in
            outbit <= outbits[DATA_WIDTH-1];
            d_out_idx <= 0;
            d_clk <= 0;
            cycles <= 0;
            started <= 1;
            trigger_flag <= 0;
        end
        else if(cycles == (DATA_HALF_PERIOD-1) & started) begin
            d_clk <= ~d_clk;
            cycles <= 0;
            if(d_clk) begin // shift buffer falling edge of d_clk
                outbit <= outbits[DATA_WIDTH-1];
                if(d_out_idx == DATA_WIDTH-1) started <= 0;
                else d_out_idx <= d_out_idx + 1;
            end else begin // put out data on rising edge of clock
                outbits <= outbits << 1;
            end
        end else cycles <= cycles + 1;
    end
  end
  assign data_out = outbit;
  assign sel_out = ~started;
  assign data_clk_out = d_clk;
endmodule
`default_nettype wire // prevents system from inferring an undeclared logic (good practice)
