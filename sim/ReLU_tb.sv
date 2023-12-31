`default_nettype none
`timescale 1ns/1ps

module relu_tb();

  logic clk_100mhz;
  logic sys_rst;

  logic wr_en_0 = 0;
  logic [1:0][7:0] wr_data_0;
  logic rd_en_0 = 0;
  logic [3:0][7:0] rd_data_0;
  VecFIFO #(.VecElements(8), .BytesPerRead(4), .BytesPerWrite(2), .Depth(2)) fifo_0(
    .clk_in(clk_100mhz),
    .rst_in(sys_rst),
    .wr_en(wr_en_0),
    .wr_data(wr_data_0),
    .rd_en(rd_en_0),
    .rd_data(rd_data_0),
    .wrap_rd(0)
  );

  logic wr_en_1 = 0;
  logic [3:0][7:0] wr_data_1;
  logic rd_en_1 = 0;
  logic [3:0][7:0] rd_data_1;
  VecFIFO #(.VecElements(8), .BytesPerRead(4), .BytesPerWrite(4), .Depth(2)) fifo_1 (
    .clk_in(clk_100mhz),
    .rst_in(sys_rst),
    .wr_en(wr_en_1),
    .wr_data(wr_data_1),
    .rd_en(rd_en_1),
    .rd_data(rd_data_1),
    .wrap_rd(0)
  );

  logic relu_data_ready;
  logic outvecvalid;
  ReLU #(.InVecLength(8), .WorkingRegs(4)) uut(
    .clk_in(clk_100mhz),
    .rst_in(sys_rst),
    .in_data_ready(relu_data_ready),
    .in_data(rd_data_0),
    .write_out_data(wr_data_1),
    .req_chunk_in(rd_en_0),
    .req_chunk_out(wr_en_1),
    .out_vector_valid(outvecvalid)
  );

  always begin
      #5;  //every 5 ns switch...so period of clock is 10 ns...100 MHz clock
      clk_100mhz = !clk_100mhz;
  end
  //initial block...this is our test simulation
  initial begin
    $dumpfile("relu_tb.vcd"); //file to store value change dump (vcd)
    $dumpvars(0, relu_tb);
    $display("Starting Sim"); //print nice message at start
    clk_100mhz = 0;
    sys_rst = 0;
    #10;
    sys_rst = 1;
    #10;
    sys_rst = 0;
    #10;
    wr_en_0 = 1;
    for (byte i = 0; i<8; i=i+1) begin
      $display("write chunk %d writing byte %b", i, $signed(-i));
      $display("write chunk %d writing byte %b", i, $signed(i));
      wr_data_0[0] = $signed(-i);
      wr_data_0[1] = $signed(i);
      #10;
    end
    wr_en_0 = 0;
    relu_data_ready = 1;
    #30;
    relu_data_ready = 0;
    #10;
    wr_en_0 = 0;
    rd_en_1 = 1;
    for (byte i = 0; i<4; i= i+ 1)begin
      $display("read chunk %d read byte %d", i, rd_data_1[0]);
      $display("read chunk %d read byte %d", i, rd_data_1[1]);
      $display("read chunk %d read byte %d", i, rd_data_1[2]);
      $display("read chunk %d read byte %d", i, rd_data_1[3]);
      #10;
    end
    rd_en_1 = 0;
    #100
    $display("Simulation finished, outvecvalid? %b", outvecvalid);
    $finish;
  end
endmodule

`default_nettype wire