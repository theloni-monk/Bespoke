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

  logic [7:0] wr_data_0;
  logic [7:0][7:0] rd_data_0;
  logic  wr_en_0 = 0; //TODO: set these in initial
  logic  rd_en_0 = 0;
  logic  vecfifo_0_out_vec_valid_0;
  logic  wrap_rd_0;
  VecFIFO #(
    .VecElements(8),
    .BytesPerRead(8),
    .BytesPerWrite(1),
    .Depth(4)) vecfifo_0 (
    .clk_in(clk_100mhz),
    .rst_in(sys_rst),
    .wr_en(wr_en_0),
    .wr_data(wr_data_0),
    .rd_en(rd_en_0),
    .rd_data(rd_data_0),
    .wrap_rd(wrap_rd_0)
    );

  logic [7:0][7:0] wr_data_3;
  logic [7:0] rd_data_3;
  logic  wr_en_3 = 0;
  logic  rd_en_3 = 0;
  logic  vecfifo_3_out_vec_valid_3;
  logic  wrap_rd_3;
  VecFIFO #(
    .VecElements(8),
    .BytesPerRead(1),
    .BytesPerWrite(8),
    .Depth(4)) vecfifo_3 (
    .clk_in(clk_100mhz),
    .rst_in(sys_rst),
    .wr_en(wr_en_3),
    .wr_data(wr_data_3),
    .rd_en(rd_en_3),
    .rd_data(rd_data_3),
    .wrap_rd(0)
    );
  logic  in_data_ready_master; //FIXME: move in_data_ready_master declaration
  module MLInference(
      input wire clk_in,
      input wire rst_in,
      input wire in_data_ready,
      output logic out_data_ready
  );
  logic [7:0][7:0] wr_data_1;
  logic  wr_en_1;
  logic  mvprod_0_out_vec_valid_0;

  MVProd #(
    .InVecLength(8),
    .OutVecLength(8),
    .WorkingRegs(8),
    .WeightFile("data/mvprod_0_wfile.mem")) mvprod_0(
    .clk_in(clk_in),
    .rst_in(rst_in),
    .in_data_ready(in_data_ready_master),
    .in_data(rd_data_0),
    .write_out_data(wr_data_1),
    .req_chunk_in(rd_en_0),
    .req_chunk_out(wr_en_1),
    .req_chunk_ptr_rst(wrap_rd_0),
    .out_vector_valid(mvprod_0_out_vec_valid_0)
              );


  logic [7:0][7:0] rd_data_1;
  logic  rd_en_1  = 0;
  logic  vecfifo_1_out_vec_valid_1;
  logic  wrap_rd_1;
  VecFIFO #(
    .VecElements(8),
    .BytesPerRead(8),
    .BytesPerWrite(8),
    .Depth(4)) vecfifo_1 (
    .clk_in(clk_in),
    .rst_in(rst_in),
    .wr_en(wr_en_1),
    .wr_data(wr_data_1),
    .rd_en(rd_en_1),
    .rd_data(rd_data_1),
    .wrap_rd(0)
    );


  logic [7:0][7:0] wr_data_2;
  logic  wr_en_2 = 0;
  logic  bias_0_out_vec_valid_0;
  Bias #(
    .InVecLength(8),
    .WorkingRegs(8),
    .BiasFile("data/bias_0_bfile.mem")) bias_0(
    .clk_in(clk_in),
    .rst_in(rst_in),
    .in_data_ready(mvprod_0_out_vec_valid_0),
    .in_data(rd_data_1),
    .write_out_data(wr_data_2),
    .req_chunk_in(rd_en_1),
    .req_chunk_out(wr_en_2),
    .out_vector_valid(bias_0_out_vec_valid_0)
              );


  logic [7:0][7:0] rd_data_2;
  logic  rd_en_2 = 0;
  logic  vecfifo_2_out_vec_valid_2;
  logic  wrap_rd_2;
  VecFIFO #(
    .VecElements(8),
    .BytesPerRead(8),
    .BytesPerWrite(8),
    .Depth(4)) vecfifo_2 (
    .clk_in(clk_in),
    .rst_in(rst_in),
    .wr_en(wr_en_2),
    .wr_data(wr_data_2),
    .rd_en(rd_en_2),
    .rd_data(rd_data_2),
    .wrap_rd(0)
    );

  logic  relu_0_out_vec_valid_0;
  ReLU #(
    .InVecLength(8),
    .WorkingRegs(8)) relu_0 (
    .clk_in(clk_in),
    .rst_in(rst_in),
    .in_data_ready(bias_0_out_vec_valid_0),
    .in_data(rd_data_2),
    .write_out_data(wr_data_3),
    .req_chunk_in(rd_en_2),
    .req_chunk_out(wr_en_3),
    .out_vector_valid(relu_0_out_vec_valid_0)
              );
  endmodule;
  logic ml_inf_valid;
  MLInference ml_inf(
      .clk_in(clk_100mhz),
      .rst_in(sys_rst),
      .in_data_ready(in_data_ready_master),
      .out_data_ready(ml_inf_valid)
  );


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
    #10;
    sys_rst = 1;
    #10;
    sys_rst = 0;
    #10;
    wr_en_0 = 1;
    for (byte i = 0; i<8; i=i+1)begin
      $display("write chunk %d writing %d", i, 0);
      wr_data_0 = 0;
      #10;
    end
    wr_en_0 = 0;
    in_data_ready_master = 1;
    #10
    in_data_ready_master = 0;
    #800;
    rd_en_3 = 1;
    for (byte i = 0; i<8; i = i+ 1)begin
      $display("read chunk %d read %d", i, $signed(rd_data_3));
      #10;
    end
    rd_en_3 = 0;
    #100;
    $display("Simulation finished, rvecvalid? %b", ml_inf_valid);
    $finish;
  end
endmodule

`default_nettype wire