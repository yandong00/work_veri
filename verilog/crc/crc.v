//-------------------------------------------
//Author  : Nguyen Hung Quan
//Website : https://nguyenquanicd.blogspot.com/
// Project:	Configurated CRC
// Function:
// -- calculate the CRC sequence
//-------------------------------------------
`include "crc_define.h"

`define DLY #1
`define CRC_CTRL_POLY

module crc (/*AUTOARG*/
   // Outputs
   crc_seq,
   `ifdef CRC_CHECKER
     crc_error,
   `endif
   // Inputs
   `ifdef CRC_CTRL_POLY
     ctrl_poly_en,
   `endif
   `ifdef CRC_CHECKER
     chk_en,
   `endif
   clk, rst_n, data_in, ctrl_en
   );

localparam CRC_GPW_MAX    = 4;
//
//Inputs
//
input clk;
input rst_n;
input ctrl_en;
input data_in;
input [CRC_GPW_MAX-1:0] ctrl_poly_en;

`ifdef CRC_CHECKER
  input chk_en;
`endif
//
//Outputs
//
output reg [CRC_GPW_MAX-1:0] crc_seq;
`ifdef CRC_CHECKER
  output wire crc_error;
`endif
//
//Internal signals
//
wire [CRC_GPW_MAX-1:0] crc_next;

assign crc_next[0] = ctrl_poly_en[0]? data_in ^ crc_seq[CRC_GPW_MAX-1]: data_in;
//
genvar i;
generate
  for (i = 1; i < CRC_GPW_MAX; i = i + 1) begin: CRCNXT
    assign crc_next[i] = ctrl_poly_en[i]? crc_seq[i-1] ^ crc_seq[CRC_GPW_MAX-1]: crc_seq[i-1];
  end
endgenerate
//
always @ (posedge clk) begin
  if (~rst_n) crc_seq[CRC_GPW_MAX-1:0] <= `DLY {CRC_GPW_MAX{1'b0}};
  else if (ctrl_en) crc_seq[CRC_GPW_MAX-1:0] <= `DLY crc_next[CRC_GPW_MAX-1:0];
  else crc_seq[CRC_GPW_MAX-1:0] <= `DLY {CRC_GPW_MAX{1'b0}};
end
//
`ifdef CRC_CHECKER
  assign crc_error = (chk_en & ~ctrl_en)? |crc_seq[CRC_GPW_MAX-1:0]: 1'b0;
`endif
endmodule