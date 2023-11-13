`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)
module spi_rx
       #(  parameter DATA_WIDTH = 8
        )
        ( input wire clk_in,
          input wire rst_in,
          input wire data_in,
          input wire data_clk_in,
          input wire sel_in,
          output logic [DATA_WIDTH-1:0] data_out,
          output logic new_data_out
        );
    parameter NUM_OUT_BITS = $clog2(DATA_WIDTH)-1;
    logic[DATA_WIDTH-1:0] buffer;
    logic[NUM_OUT_BITS:0] idx;
    logic prev_data_clk;
    logic write_flag;
    always_ff @(posedge clk_in)begin
        if(rst_in) begin
            idx <= DATA_WIDTH-1;
            write_flag <= 0;
            buffer <= 0;
            prev_data_clk <= data_clk_in;
        end
        else begin
            if(write_flag) write_flag <= 0;
            if(data_clk_in & (~prev_data_clk) & (~sel_in)) begin // selected and falling edge of data_clk
                if(idx == 0) begin
                    write_flag <= 1;
                    idx <= DATA_WIDTH - 1;
                    buffer[idx] = data_in;
                    data_out <= buffer;
                end else begin
                    buffer[idx] = data_in;
                    idx <= idx-1;
                end
            end
        end
        prev_data_clk <= data_clk_in;
    end
    assign new_data_out = write_flag;
endmodule
`default_nettype wire // prevents system from inferring an undeclared logic (good practice)
