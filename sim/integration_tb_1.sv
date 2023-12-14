`default_nettype none
`timescale 1ns/1ps

module integration_tb_1();
/**
 [-1 -2 -3 -4 -5 -6], [-7 -8 -9 -10 -11 -12]
 -> MVProd(trunc permutation) [-6 -5 -4 -3] [-12 -11 -10 -9]
 -> Bias(1 2 3 4) [-5 -3 -1 1][-11 -9 -7 -5]
 -> ReLU [0 0 0 1][0 0 0 0 ]
*/
  logic clk_100mhz;
  logic sys_rst;

  logic wr_en_0 = 0;
  logic [7:0] wr_data_0;
  logic rd_en_0 = 0;
  logic [1:0][7:0] rd_data_0;
  logic rd_ptr_rst_0;
  VecFIFO #(.VecElements(6), .BytesPerRead(2), .BytesPerWrite(1), .Depth(2)) fifo_0(
    .clk_in(clk_100mhz),
    .rst_in(sys_rst),
    .wr_en(wr_en_0),
    .wr_data(wr_data_0),
    .rd_en(rd_en_0),
    .rd_data(rd_data_0),
    .wrap_rd(rd_ptr_rst_0)
  );

  logic wr_en_1 = 0;
  logic [7:0] wr_data_1;
  logic rd_en_1 = 0;
  logic [1:0][7:0] rd_data_1;
  VecFIFO #(.VecElements(6), .BytesPerRead(2), .BytesPerWrite(1), .Depth(2)) fifo_1 (
    .clk_in(clk_100mhz),
    .rst_in(sys_rst),
    .wr_en(wr_en_1),
    .wr_data(wr_data_1),
    .rd_en(rd_en_1),
    .rd_data(rd_data_1),
    .wrap_rd(0)
  );

  logic wr_en_2 = 0;
  logic [3:0][7:0] wr_data_2;
  logic rd_en_2 = 0;
  logic [3:0][7:0] rd_data_2;
  VecFIFO #(.VecElements(4), .BytesPerRead(4), .BytesPerWrite(2), .Depth(2)) fifo_2 (
    .clk_in(clk_100mhz),
    .rst_in(sys_rst),
    .wr_en(wr_en_2),
    .wr_data(wr_data_2),
    .rd_en(rd_en_2),
    .rd_data(rd_data_2),
    .wrap_rd(0)
  );

  logic wr_en_3 = 0;
  logic [3:0][7:0] wr_data_3;
  logic rd_en_3 = 0;
  logic [7:0] rd_data_3;
  VecFIFO #(.VecElements(4), .BytesPerRead(1), .BytesPerWrite(4), .Depth(2)) fifo_3 (
    .clk_in(clk_100mhz),
    .rst_in(sys_rst),
    .wr_en(wr_en_3),
    .wr_data(wr_data_3),
    .rd_en(rd_en_3),
    .rd_data(rd_data_3),
    .wrap_rd(0)
  );

  logic mv_data_ready = 0;
  logic mvecvalid;
  MVProd #(.InVecLength(6), .OutVecLength(4), .WorkingRegs(2), .WeightFile("data/int_1_matrix_out.mem")) mprod(
    .clk_in(clk_100mhz),
    .rst_in(sys_rst),
    .in_data_ready(mv_data_ready),
    .in_data(rd_data_0),
    .write_out_data(wr_data_1),
    .req_chunk_in(rd_en_0),
    .req_chunk_out(wr_en_1),
    .req_chunk_ptr_rst(rd_ptr_rst_0),
    .out_vector_valid(mvecvalid)
  );

  logic biasvecvalid;
  Bias #(.InVecLength(4), .WorkingRegs(2), .BiasFile("data/int_1_bias_out.mem")) bias(
    .clk_in(clk_100mhz),
    .rst_in(sys_rst),
    .in_data_ready(mvecvalid),
    .in_data(rd_data_1),
    .write_out_data(wr_data_2),
    .req_chunk_in(rd_en_1),
    .req_chunk_out(wr_en_2),
    .out_vector_valid(biasvecvalid)
  );

  logic reluvecvalid;
  ReLU #(.InVecLength(4), .WorkingRegs(4)) relu(
    .clk_in(clk_100mhz),
    .rst_in(sys_rst),
    .in_data_ready(biasvecvalid),
    .in_data(rd_data_2),
    .write_out_data(wr_data_3),
    .req_chunk_in(rd_en_2),
    .req_chunk_out(wr_en_3),
    .out_vector_valid(reluvecvalid)
  );

  always begin
      #5;  //every 5 ns switch...so period of clock is 10 ns...100 MHz clock
      clk_100mhz = !clk_100mhz;
  end
  //initial block...this is our test simulation
  initial begin
    $dumpfile("integration_tb_1.vcd"); //file to store value change dump (vcd)
    $dumpvars(0, integration_tb_1);
    $display("Starting Sim"); //print nice message at start
    clk_100mhz = 0;
    sys_rst = 0;
    #10;
    sys_rst = 1;
    #10;
    sys_rst = 0;
    #10;
    wr_en_0 = 1;
    for (byte i = 1; i<13; i=i+1)begin
      $display("write chunk %d writing %d", i, $signed(-i));
      wr_data_0 = $signed(-i);
      #10;
    end
    wr_en_0 = 0;
    mv_data_ready = 1;
    #200
    mv_data_ready = 0;
    #200;
    rd_en_3 = 1;
    for (byte i = 0; i<8; i = i+ 1)begin
      $display("read chunk %d read %d", i, $signed(rd_data_3));
      #10;
    end
    rd_en_3 = 0;
    #100;
    $display("Simulation finished, rvecvalid? %b", reluvecvalid);
    $finish;
  end
endmodule

`default_nettype wire