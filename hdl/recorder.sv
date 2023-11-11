`timescale 1ns / 1ps
`default_nettype none


module  recorder(
  input wire clk_in,
  input wire rst_in,
  input wire signed [7:0] audio_in,
  input wire record_in,
  input wire audio_valid_in,
  output logic signed [7:0] single_out,
  output logic signed [7:0] echo_out
  );
  
  logic recording;
  logic [15:0] write_ptr;
  logic [15:0] write_end;
  logic [15:0] read_ptrs0;
  logic [15:0] read_ptrs1;
  logic [15:0] read_ptrs2;
  logic signed [7:0] ram_out;

  logic signed [7:0] tap0;
  logic signed [7:0] tap1;
  logic t1valid;
  logic signed [7:0] tap2;
  logic t2valid;

  logic [3:0] loadcycles;

  always_ff @(posedge clk_in) begin
    recording <= record_in;
    if(rst_in)begin
      write_ptr <= 0;
      write_end <= 0;
      read_ptrs0 <= 0;
      read_ptrs1 <= 0;
      read_ptrs2 <= 0;
      loadcycles <= 0;
    end else begin
      if(record_in && ~recording)begin
        write_ptr <= 0;
        read_ptrs0 <= 0;
        read_ptrs1 <= 0;
        read_ptrs2 <= 0;
        t1valid <= 0;
        t2valid <= 0;
      end else if(audio_valid_in) begin
        if(record_in) begin
          write_ptr <= write_ptr + 1;
          write_end <= write_ptr + 1;
          tap1 <= 0;
          tap2 <= 0;
        end else begin
          // only inc deeper ptrs if we've passed 0.125s
          loadcycles <= 0;
          read_ptrs0 <= (read_ptrs0 >= write_end) ? 16'd0 : read_ptrs0 + 1;
          read_ptrs1 <= t1valid ? ((read_ptrs1 >= write_end) ? 16'd0 : read_ptrs1 + 1) : 0;
          read_ptrs2 <= t2valid ? ((read_ptrs2 >= write_end) ? 16'd0 : read_ptrs2 + 1) : 0;
          t1valid <= read_ptrs0 > 1498 || t1valid;
          t2valid <= read_ptrs1 > 1498 || t2valid;
        end
      end else begin
        //single_out <= ram_out;
        if(loadcycles < 10) loadcycles <= loadcycles + 1;
        if(loadcycles == 3) begin
          tap0 <= ram_out;
          single_out <= ram_out;
          read_ptrs0 <= read_ptrs2;
          read_ptrs1 <= read_ptrs0;
          read_ptrs2 <= read_ptrs1;
        end
        if(loadcycles == 6) begin
          tap1 <= ram_out;
          read_ptrs0 <= read_ptrs2;
          read_ptrs1 <= read_ptrs0;
          read_ptrs2 <= read_ptrs1;
        end
        if(loadcycles == 9) begin
          tap2 <= ram_out;
          read_ptrs0 <= read_ptrs2;
          read_ptrs1 <= read_ptrs0;
          read_ptrs2 <= read_ptrs1;
        end
        if(loadcycles == 10) begin
          echo_out <= tap0 + (tap1 >>> 1) + (tap2 >>> 2);
        end
      end
    end
  end
  
  
  xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(8),
    .RAM_DEPTH(65536))
    audio_buffer (
    .addra(write_ptr),
    .clka(clk_in),
    .wea(record_in&&audio_valid_in),
    .dina(audio_in),
    .ena(1'b1),
    .regcea(1'b1),
    .rsta(rst_in),
    .douta(),
    .addrb(read_ptrs0),
    .dinb(8'b0),
    .clkb(clk_in),
    .web(1'b0),
    .enb(1'b1),
    .rstb(rst_in),
    .regceb(1'b1),
    .doutb(ram_out)
  );
endmodule
`default_nettype wire
