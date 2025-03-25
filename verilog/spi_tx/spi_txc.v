module spi_txc (
    input wire sclk_tx,
    input wire spi_tx_rstn,
    input wire [31:0] spi_tx_data,
    input wire [1:0] df,
    input wire [12:0] spi_tnum_max,
    input wire lsbf,
    input wire crc_en,

    input wire rxonly,

    input wire [31:0] crc_poly,
    output wire [31:0] tx_crc_data_out,

    output reg tx_start,
    output reg tx_num_max_en,
    output reg tx_crc_en,

    output wire shift_out
);

wire [31:0] shift_reg_pre;
reg [31:0]  shift_reg;

wire [4:0]  shift_num_cnt_pre;
reg [4:0]   shift_num_cnt;
wire [4:0]  shift_num_max;

reg [12:0]  tx_num_cnt;

//---------------------------------------------------------------
// select shift data width
//---------------------------------------------------------------
assign shift_num_max = (df == 2'b00) ? 5'd7 :
                        (df == 2'b01) ? 5'd15 : 5'd31 ;

//---------------------------------------------------------------
// tx data sort (msb or lsb) and crc
//---------------------------------------------------------------
wire [31:0] tx_data;
wire [31:0] tx_data_sort;

assign tx_data = (crc_en & tx_num_max_en) ? tx_crc_data_out : spi_tx_data;
assign tx_data_sort = tx_msb_sort(tx_data, df, lsbf);

//---------------------------------------------------------------
// shift register: data_shift_out
//---------------------------------------------------------------
assign shift_reg_pre = rxonly                ? 32'h0 : 
                       shift_num_cnt == 5'd0 ? tx_data_sort : {1'b0, shift_reg[31:1]};

always @(posedge sclk_tx or negedge spi_tx_rstn) begin
    if (!spi_tx_rstn) begin
        shift_reg <= 32'h0;
    end
    else begin
        shift_reg <= shift_reg_pre;
    end
end

//---------------------------------------------------------------
// shift data counter(use to identify when load new tx_data_sort)
//---------------------------------------------------------------
assign shift_num_cnt_pre = (shift_num_cnt >= shift_num_max) | rxonly ? 5'd0 : (shift_num_cnt + 1'b1);
always @(posedge sclk_tx or negedge spi_tx_rstn) begin
    if (!spi_tx_rstn) begin
        shift_num_cnt <= 5'd0;
    end
    else begin
        shift_num_cnt <= shift_num_cnt_pre;
    end
end

//---------------------------------------------------------------
// transfer data frame counter(only use to crc mode)
//---------------------------------------------------------------
wire [12:0] tx_num_cnt_pre;
assign tx_num_cnt_pre = (rxonly | ~crc_en) ? 13'h0 : 
                        ((shift_num_cnt == 5'd0) & ~tx_num_max_en) ? (tx_num_cnt + 1'b1) : tx_num_cnt;
always @(posedge sclk_tx or negedge spi_tx_rstn) begin
    if (!spi_tx_rstn) begin
        tx_num_cnt <= 13'h0;
    end
    else begin
        tx_num_cnt <= tx_num_cnt_pre;
    end
end

wire tx_num_max_en_pre;
assign tx_num_max_en_pre = (tx_num_cnt_pre >= spi_tnum_max);
always @(posedge sclk_tx or negedge spi_tx_rstn) begin
    if (!spi_tx_rstn) begin
        tx_num_max_en <= 1'b0;
    end
    else begin
        tx_num_max_en <= tx_num_max_en_pre;
    end
end

wire tx_crc_en_pre;
assign tx_crc_en_pre =  ~crc_en ? 1'b0 : 
                        (tx_num_max_en & (shift_num_cnt == 5'd0) ? 1'b1 : tx_crc_en);
always @(posedge sclk_tx or negedge spi_tx_rstn) begin
    if (!spi_tx_rstn) begin
        tx_crc_en <= 1'b0;
    end
    else begin
        tx_crc_en <= tx_crc_en_pre;
    end
end 

//---------------------------------------------------------------
// tx start flag use to clean txe
//---------------------------------------------------------------
always @(posedge sclk_tx or negedge spi_tx_rstn) begin
    if (!spi_tx_rstn) begin
        tx_start <= 1'b0;
    end
    else begin
        tx_start <= (shift_num_cnt == 5'd1);
    end
end
//---------------------------------------------------------------
// serial crc calculation
//---------------------------------------------------------------
wire crc_calc_en;
assign crc_calc_en = crc_en & ~tx_crc_en_pre;

serial_crc_new u_tx_crc (
    .clk(sclk_tx),
    .rst_n(spi_tx_rstn),
    .data_in(shift_reg_pre[0]),
    .data_valid(crc_calc_en),
    .init(~crc_en),
    .crc_mode(df),
    .polynomial(crc_poly),
    .crc_out(tx_crc_data_out)
);

//---------------------------------------------------------------
// shift out data(mstr -->mosi, slv-->miso)
//---------------------------------------------------------------
assign shift_out = shift_reg[0] ;


//---------------------------------------------------------------
// tx data sort (msb or lsb)
//---------------------------------------------------------------
function [31:0] tx_msb_sort;
input [31:0] din    ;
input [1:0]  df     ;
input        lsbf   ;
begin
    if (lsbf) begin
        tx_msb_sort = din;
    end 
    else begin
        if (df == 2'b00) begin
            tx_msb_sort = { din[31], din[30], din[29], din[28], din[27], din[26], din[25], din[24], 
                            din[23], din[22], din[21], din[20], din[19], din[18], din[17], din[16], 
                            din[15], din[14], din[13], din[12], din[11], din[10], din[9] , din[8] , 
                            din[0] , din[1] , din[2] , din[3] , din[4] , din[5] , din[6] , din[7] }; 
        end
        else if (df == 2'b01) begin
            tx_msb_sort = { din[31], din[30], din[29], din[28], din[27], din[26], din[25], din[24], 
                            din[23], din[22], din[21], din[20], din[19], din[18], din[17], din[16], 
                            din[0] , din[1] , din[2] , din[3] , din[4] , din[5] , din[6] , din[7] , 
                            din[8] , din[9] , din[10], din[11], din[12], din[13], din[14], din[15] }; 
        end
        else begin
            tx_msb_sort = { din[0] , din[1] , din[2] , din[3] , din[4] , din[5] , din[6] , din[7] , 
                            din[8] , din[9] , din[10], din[11], din[12], din[13], din[14], din[15] ,
                            din[16], din[17], din[18], din[19], din[20], din[21], din[22], din[23] ,
                            din[24], din[25], din[26], din[27], din[28], din[29], din[30], din[31] };
        end
    end
end
endfunction

endmodule
