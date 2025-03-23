module serial_crc_new (
    input wire clk,
    input wire rst_n,
    input wire data_in,    // serial data input
    input wire data_valid, // data valid signal
    input wire init,       // initialize signal
    input wire [1:0] crc_mode, // CRC mode selection: 00-CRC8, 01-CRC16, 10-CRC32
    input wire [31:0] polynomial, // CRC polynomial, according to mode use different width
    output reg [31:0] crc_out    // CRC calculation result, according to mode use different width
);

wire    crc_max;
assign crc_max = (crc_mode == 2'b00) ?  crc_out[7]  :
                 (crc_mode == 2'b01) ?  crc_out[15] :
                                        crc_out[31] ;
wire    [31:0] crc_mask;
assign  crc_mask = (crc_mode == 2'b00) ? 32'h0000_00ff :
                   (crc_mode == 2'b01) ? 32'h0000_ffff :
                                         32'hffff_ffff ;

wire    roll_back ;
assign  roll_back = crc_max ^ data_in;

wire    [31:0] crc_out_next;
assign crc_out_next[0] = polynomial[0] ? roll_back : data_in;

genvar i;
generate
    for (i = 1; i < 32; i = i + 1) begin : crc_out_next_gen
        assign crc_out_next[i] = polynomial[i] ? crc_out[i-1] ^ roll_back : crc_out[i-1];
    end
endgenerate


always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        crc_out <= 32'hffff_ffff;
    end
    else if (init) begin
        crc_out <= 32'hffff_ffff;
    end
    else if (data_valid) begin
        crc_out <= crc_out_next & crc_mask;
    end
end


endmodule
