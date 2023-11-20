`default_nettype none
`timescale 1ns/1ps
//TODO: make sure it works for consecutive vectors
module mvprod_tb();

  logic clk_100mhz;
  logic sys_rst;

  logic wr_en_0 = 0;
  logic [7:0] wr_data_0;
  logic rd_en_0 = 0;
  logic [1:0][7:0] rd_data_0;
  logic rd_ptr_rst;
  VecFIFO #(.VecElements(8), .BytesPerRead(2), .BytesPerWrite(1), .Depth(3)) fifo_0(
    .clk_in(clk_100mhz),
    .rst_in(sys_rst),
    .wr_en(wr_en_0),
    .wr_data(wr_data_0),
    .rd_en(rd_en_0),
    .rd_data(rd_data_0),
    .wrap_rd(rd_ptr_rst)
  );

  logic wr_en_1 = 0;
  logic [7:0] wr_data_1;
  logic rd_en_1 = 0;
  logic [7:0] rd_data_1;
  VecFIFO #(.VecElements(8), .BytesPerRead(1), .BytesPerWrite(1), .Depth(2)) fifo_1 (
    .clk_in(clk_100mhz),
    .rst_in(sys_rst),
    .wr_en(wr_en_1),
    .wr_data(wr_data_1),
    .rd_en(rd_en_1),
    .rd_data(rd_data_1),
    .wrap_rd(0)
  );

  logic mv_data_ready = 0;
  logic outvecvalid;
  MVProd #(.InVecLength(8), .OutVecLength(8), .WorkingRegs(2), .WeightFile("data/matrix_out.mem")) uut(
    .clk_in(clk_100mhz),
    .rst_in(sys_rst),
    .in_data_ready(mv_data_ready),
    .in_data(rd_data_0),
    .write_out_data(wr_data_1),
    .req_chunk_in(rd_en_0),
    .req_chunk_out(wr_en_1),
    .req_chunk_ptr_rst(rd_ptr_rst),
    .out_vector_valid(outvecvalid)
  );

  always begin
      #5;  //every 5 ns switch...so period of clock is 10 ns...100 MHz clock
      clk_100mhz = !clk_100mhz;
  end
  //initial block...this is our test simulation
  initial begin
    $dumpfile("mvprod_tb.vcd"); //file to store value change dump (vcd)
    $dumpvars(0, mvprod_tb);
    $display("Starting Sim"); //print nice message at start
    clk_100mhz = 0;
    sys_rst = 0;
    #10;
    sys_rst = 1;
    #10;
    sys_rst = 0;
    #10;
    wr_en_0 = 1;
    for (byte i = 0; i<16; i=i+1)begin
      $display("write chunk %d writing %d", i, $signed(i));
      wr_data_0 = $signed(i);
      #10;
    end
    wr_en_0 = 0;
    mv_data_ready = 1;
    #500
    mv_data_ready = 0;
    #440;
    rd_en_1 = 0;
    #10;
    rd_en_1 = 1;
    for (byte i = 0; i<16; i = i+ 1)begin
      $display("read chunk %d read %d", i, $signed(rd_data_1));
      #10;
    end
    rd_en_1 = 0;
    #100;
    $display("Simulation finished, outvecvalid? %b", outvecvalid);
    $finish;
  end
endmodule

`default_nettype wire