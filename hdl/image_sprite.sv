`timescale 1ns / 1ps
`default_nettype none

`ifdef SYNTHESIS
`define FPATH(X) `"X`"
`else /* ! SYNTHESIS */
`define FPATH(X) `"data/X`"
`endif  /* ! SYNTHESIS */

module image_sprite #(
  parameter WIDTH=256, HEIGHT=256) (
  input wire pixel_clk_in,
  input wire rst_in,
  input wire [10:0] x_in, hcount_in,
  input wire [9:0]  y_in, vcount_in,
  output logic [7:0] red_out,
  output logic [7:0] green_out,
  output logic [7:0] blue_out
  );

  // calculate rom address
  logic [$clog2(WIDTH*HEIGHT)-1:0] image_addr;
  assign image_addr = (hcount_in - x_in) + ((vcount_in - y_in) * WIDTH);

  logic in_sprite;
  assign in_sprite = ((hcount_in >= x_in && hcount_in < (x_in + WIDTH)) &&
                      (vcount_in >= y_in && vcount_in < (y_in + HEIGHT)));
  logic in_sprite_piped;
  pipeliner #(.WIDTH(1), .DEPTH(4)) insprite_piper (
    .clk_in(pixel_clk_in),
    .rst_in(rst_in),
    .in(in_sprite),
    .out(in_sprite_piped)
  );
  logic[7:0] plt_color;

  xilinx_single_port_ram_read_first #(
    .RAM_WIDTH(8),                       // Specify RAM data width
    .RAM_DEPTH(WIDTH*HEIGHT),                     // Specify RAM depth (number of entries)
    .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
    .INIT_FILE(`FPATH(data/image.mem))          // Specify name/location of RAM initialization file if using one (leave blank if not)
   ) img_ram (
    .addra(image_addr),     // Address bus, width determined from RAM_DEPTH
    .dina(8'd0),       // RAM input data, width determined from RAM_WIDTH
    .clka(pixel_clk_in),       // Clock
    .wea(1'd0),         // Write enable
    .ena(1'd1),         // RAM Enable, for additional power savings, disable port when not in use
    .rsta(rst_in),       // Output reset (does not affect memory contents)
    .regcea(1'd1),   // Output register enable
    .douta(plt_color)      // RAM output data, width determined from RAM_WIDTH
  );

  logic [23:0] true_color;
  xilinx_single_port_ram_read_first #(
    .RAM_WIDTH(24),                       // Specify RAM data width
    .RAM_DEPTH(256),                     // Specify RAM depth (number of entries)
    .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
    .INIT_FILE(`FPATH(data/palette.mem))          // Specify name/location of RAM initialization file if using one (leave blank if not)
   ) palette_ram (
    .addra(plt_color),     // Address bus, width determined from RAM_DEPTH
    .dina(24'd0),       // RAM input data, width determined from RAM_WIDTH
    .clka(pixel_clk_in),       // Clock
    .wea(1'd0),         // Write enable
    .ena(1'd1),         // RAM Enable, for additional power savings, disable port when not in use
    .rsta(rst_in),       // Output reset (does not affect memory contents)
    .regcea(1'd1),   // Output register enable
    .douta(true_color)      // RAM output data, width determined from RAM_WIDTH
  );


  // Modify the module below to use your BRAMs!
  assign red_out =    in_sprite_piped ? true_color[23:16] : 0;
  assign green_out =  in_sprite_piped ? true_color[15:8] : 0;
  assign blue_out =   in_sprite_piped ? true_color[7:0] : 0;
endmodule

`default_nettype none
