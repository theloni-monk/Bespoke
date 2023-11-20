`default_nettype none
`timescale 1ns/1ps
module fifo_tb();

  logic clk_in;
  logic rst_in;
  logic wr_en = 0;
  logic [1:0][7:0] wr_data;
  logic rd_en = 0;
  logic [3:0][7:0] rd_data;

  //defaults: 8 vec elements, 2 bytes per write, 4 bytes per read, depth of 16
  VecFIFO #(.VecElements(8), .BytesPerRead(4), .BytesPerWrite(2), .Depth(16)) uut(
    .clk_in(clk_in),
    .rst_in(rst_in),
    .wr_en(wr_en),
    .wr_data(wr_data),
    .rd_en(rd_en),
    .rd_data(rd_data)
  );

  always begin
      #5;  //every 5 ns switch...so period of clock is 10 ns...100 MHz clock
      clk_in = !clk_in;
  end
  //initial block...this is our test simulation
  initial begin
    $dumpfile("fifo_tb.vcd"); //file to store value change dump (vcd)
    $dumpvars(0, fifo_tb);
    $display("Starting Sim"); //print nice message at start
    clk_in = 0;
    rst_in = 0;
    #10;
    rst_in = 1;
    #10;
    rst_in = 0;
    wr_en = 1;
    for (byte i = 0; i<64; i=i+1)begin
      $display("write chunk %d writing byte %b", i, $signed(-i));
      $display("write chunk %d writing byte %b", i, $signed(i));
      wr_data[0] = $signed(-i);
      wr_data[1] = $signed(i);
      #10;
    end
    wr_en = 0;
    rd_en = 1;
    for (byte i = 0; i<32; i= i+ 1)begin
      $display("read chunk %d read byte %b", i, rd_data[0]);
      $display("read chunk %d read byte %b", i, rd_data[1]);
      $display("read chunk %d read byte %b", i, rd_data[2]);
      $display("read chunk %d read byte %b", i, rd_data[3]);
      #10;
    end
    rd_en = 0;
    $display("Simulation finished");
    $finish;
  end
endmodule
`default_nettype wire