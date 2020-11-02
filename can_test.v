module can_test
(
    input clk_i,
    input rx_i,
    input rst_i,
    output tx_o,
    
    output tx_busy,
    output rx_busy,
    
    
    output test_rx_rx,
    output test_sample
    
);

reg tx_send = 1'b1;

reg [63:0] tx_data              = 64'b0011000100110010001100110011010000110101001101100011011100111000;


can_top can_top_inst 
(
    .rst_i      (rst_i),
    .clk_i      (clk_i),
    
    .rx_i       (rx_i),
    .rx_busy    (rx_busy),
    
    .tx_o       (tx_o),
    .tx_busy    (tx_busy),
    .tx_send_i  (1'b1),
    
    
    .tx_data_i   (tx_data),
    
    
    .data_wr    (data_wr),
    .addr_wr    (addr_wr),
    .wr_en      (wr_en),
    .wr_done    (wr_done),
    .wr_busy    (wr_busy)
);

localparam addr_width = 20;
localparam data_width = 32;

localparam [19:0] addr_data_send    = 20'hA0001;
localparam [19:0] addr_setting_send = 20'hA0002;


PMRAMIF # (
    .DATA_WIDTH        (data_width),
    .ADDR_WIDTH        (addr_width),
    .CLK_FREQUENCY     (50_000_000),
    .OP_CYCLE_NS       (35)
) PMRAMIF_inst
(
    .clk        (clk_i),
    .rst        (rst_i),
    
    .data_wr    (),
    .addr_wr    (),
    .wr_en      (),
    .wr_done    (),
    .wr_busy    (),

    .data_rd    (),
    .addr_rd    (),
    .rd_en      (),
    .rd_done    (),
    .rd_busy    ()
);

endmodule
    
