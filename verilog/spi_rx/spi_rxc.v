module spi_rxc(
    input wire clk_rx,
    input wire spi_rx_rstn,
    input wire [1:0] df,
    input wire [12:0] spi_tnum_max,
    input wire lsbf,
    input wire crc_en,

    input wire shift_in,

    input wire [31:0] crc_poly,
    output wire [31:0] rx_crc_data_out,
    
    output reg [31:0] spi_rx_data,
    output reg rx_num_max_en,
    output reg rx_crc_en,

    output reg rx_busy
);

wire    [31:0]  shift_reg_pre;
reg     [31:0]  shift_reg;

wire    [4:0]   shift_num_cnt_pre;
reg     [4:0]   shift_num_cnt;
wire    [4:0]   shift_num_max;

wire    [12:0]  rx_num_cnt_pre;
reg     [12:0]  rx_num_cnt;

//---------------------------------------------------------------
// select shift data width
//---------------------------------------------------------------
assign shift_num_max = (df == 2'b00) ? 5'd7 :
                        (df == 2'b01) ? 5'd15 : 5'd31 ;

//---------------------------------------------------------------
// shift register: shift_reg_pre
//---------------------------------------------------------------
assign shift_reg_pre =  {shift_in, shift_reg[31:1]};

always @(posedge clk_rx or negedge spi_rx_rstn) begin
    if (!spi_rx_rstn) begin
        shift_reg <= 32'h0;
    end
    else begin
        shift_reg <= shift_reg_pre;
    end
end

//---------------------------------------------------------------
// shift data counter(use to identify when load new tx_data_sort)
//---------------------------------------------------------------
assign shift_num_cnt_pre = (shift_num_cnt >= shift_num_max) ? 5'd0 : (shift_num_cnt + 1'b1);
always @(posedge clk_rx or negedge spi_rx_rstn) begin
    if (!spi_rx_rstn) begin
        shift_num_cnt <= 5'd0;
    end
    else begin
        shift_num_cnt <= shift_num_cnt_pre;
    end
end

//---------------------------------------------------------------
// transfer data frame counter(data frame and crc frame)
//---------------------------------------------------------------

assign rx_num_cnt_pre = (shift_num_cnt == 5'd0) & ~rx_num_max_en ? (rx_num_cnt + 1'b1) : rx_num_cnt;
always @(posedge clk_rx or negedge spi_rx_rstn) begin
    if (!spi_rx_rstn) begin
        rx_num_cnt <= 13'h0;
    end
    else begin
        rx_num_cnt <= rx_num_cnt_pre;
    end
end

wire rx_num_max_en_pre;
assign rx_num_max_en_pre = (rx_num_cnt_pre >= spi_tnum_max);
always @(posedge clk_rx or negedge spi_rx_rstn) begin
    if (!spi_rx_rstn) begin
        rx_num_max_en <= 1'b0;
    end
    else begin
        rx_num_max_en <= rx_num_max_en_pre;
    end
end

wire rx_crc_en_pre;
assign rx_crc_en_pre =  ~crc_en ? 1'b0 : 
                        (rx_num_max_en & (shift_num_cnt == 5'd0) ? 1'b1 : rx_crc_en);
always @(posedge clk_rx or negedge spi_rx_rstn) begin
    if (!spi_rx_rstn) begin
        rx_crc_en <= 1'b0;
    end
    else begin
        rx_crc_en <= rx_crc_en_pre;
    end
end
//---------------------------------------------------------------
// rx busy flag use to set rxne
//---------------------------------------------------------------
wire rx_busy_pre;
assign rx_busy_pre = (shift_num_cnt_pre != 5'd0);
always @(posedge clk_rx or negedge spi_rx_rstn) begin
    if (!spi_rx_rstn) begin
        rx_busy <= 1'b0;
    end
    else begin
        rx_busy <= rx_busy_pre;
    end
end

//---------------------------------------------------------------
// rx data sort (msb or lsb)
//---------------------------------------------------------------
wire [31:0] rx_data;
assign rx_data = rx_msb_sort(shift_reg_pre, df, lsbf);
always @(posedge clk_rx or negedge spi_rx_rstn) begin
    if (!spi_rx_rstn) begin
        spi_rx_data <= 32'h0;
    end
    else if (shift_num_cnt_pre == 5'd0) begin
        spi_rx_data <= rx_data;
    end
end

//---------------------------------------------------------------
// serial crc calculation
//---------------------------------------------------------------
wire crc_calc_en;
assign crc_calc_en = crc_en & ~rx_crc_en_pre;

serial_crc_new u_rx_crc (
    .clk(clk_rx),
    .rst_n(spi_rx_rstn),
    .data_in(shift_reg_pre[31]),
    .data_valid(crc_calc_en),
    .init(~crc_en),
    .crc_mode(df),
    .polynomial(crc_poly),
    .crc_out(rx_crc_data_out)
);

function [31:0] rx_msb_sort;
input [31:0] din;
input [1:0] df;
input lsbf;
begin   
    if (lsbf) begin
        if (df == 2'b00) begin
            rx_msb_sort = { 24'h0,
                            din[31], din[30], din[29], din[28], din[27], din[26], din[25], din[24]}; 
        end
        else if (df == 2'b01) begin
            rx_msb_sort = { 16'h0,
                            din[31], din[30], din[29], din[28], din[27], din[26], din[25], din[24], 
                            din[23], din[22], din[21], din[20], din[19], din[18], din[17], din[16]}; 
        end
        else begin
            rx_msb_sort = { din[31], din[30], din[29], din[28], din[27], din[26], din[25], din[24], 
                            din[23], din[22], din[21], din[20], din[19], din[18], din[17], din[16], 
                            din[15], din[14], din[13], din[12], din[11], din[10], din[9] , din[8] ,
                            din[7] , din[6] , din[5] , din[4] , din[3] , din[2] , din[1] , din[0] };
        end
    end 
    else begin
        if (df == 2'b00) begin
            rx_msb_sort = { 24'h0,
                            din[24], din[25], din[26], din[27], din[28], din[29], din[30], din[31]}; 
        end
        else if (df == 2'b01) begin
            rx_msb_sort = { 16'h0,
                            din[16], din[17], din[18], din[19], din[20], din[21], din[22], din[23], 
                            din[24], din[25], din[26], din[27], din[28], din[29], din[30], din[31]}; 
        end
        else begin
            rx_msb_sort = { din[0] , din[1] , din[2] , din[3] , din[4] , din[5] , din[6] , din[7] , 
                            din[8] , din[9] , din[10], din[11], din[12], din[13], din[14], din[15] ,
                            din[16], din[17], din[18], din[19], din[20], din[21], din[22], din[23] ,
                            din[24], din[25], din[26], din[27], din[28], din[29], din[30], din[31] };
        end
    end
end
endfunction

endmodule
