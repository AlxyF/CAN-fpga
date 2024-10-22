// Extended CAN format
// 1(SOF)+11(Arb1)+2(SRR,IDE)+11(Arb2)+1(RTR)+1(r1)+1(r0)+4(Control)+64(Data)+15(CRC Field)+1(CRC Delimeter)+2(Ack)+7(EoF)+3(Idle)
module can_top
#(
    parameter CLK_FREQ      = 50_000_000,
    parameter CAN_CLK_FREQ  = 100_000,
    
    // DMA
    parameter DATA_WIDTH        = 32,
    parameter ADDR_WIDTH        = 20,
    parameter CLK_FREQUENCY     = 200_000_000,
    parameter OP_CYCLE_NS       = 35,
    
    //
    parameter [5:0]  LOCAL_ADDRESS = 6'b000101,
    
    parameter [19:0] ADDR_SETTING_SEND      = 20'hA0001,
    parameter [19:0] ADDR_DATA_SEND_1       = 20'hA0002,
    parameter [19:0] ADDR_DATA_SEND_2       = 20'hA0003,
    
    parameter [19:0] addr_setting_recieved  = 20'hB0001,
    parameter [19:0] addr_data_recieved_1   = 20'hB0002,
    parameter [19:0] addr_data_recieved_2   = 20'hB0003
)(   
    input  rst_i,
    input  clk_i,
    
    input  rx_i,
    output rx_busy,
    output rx_received,
    
    output tx_o,
    output tx_busy,
    input  tx_send_i,
   
    // <DMA>
    output reg [DATA_WIDTH-1 : 0] data_wr,
    output reg [ADDR_WIDTH-1 : 0] addr_wr,
    output reg                    wr_en,
    input                         wr_done,
    input                         wr_busy,
    
    input      [DATA_WIDTH-1 : 0] data_rd,
    output reg [ADDR_WIDTH-1 : 0] addr_rd,
    output reg                    rd_en,
    input                         rd_done,
    input                         rd_busy,
    // </DMA>
    
    // tx fields
    //input             tx_message_type,
    //input [5:0]       tx_address_remote,
    
    input [63:0]  tx_data_i,
    
    // - output CAN frame LLC/DLC data
         
    // <test>
    output test_clk_can,
    output [2:0]  test_can_state,
    output [7:0]  test_can_tx_state,
    output [7:0]  test_bit_count,
    output [3:0]  test_bit_pol_count,
    output reg    bit_stuffed,
    output        test_last_bit,
    
    output [7:0]  test_rx_state,
    output [11:0] test_rx_quant_count,
    output [7:0]  test_rx_bit_count,
    output [3:0]  test_rx_bit_pol_count,
    output        test_rx_bit_stuffed,
    output [6:0]  test_rx_count,
    output test_rx_rx,
    output test_sample
    // </test>
);

// <test>
wire test_arbi;
reg count_rst;
assign test_sample              = ( CAN_STATE == CAN_PAUSE ) ? 1'b0 : 1'b1;
assign test_can_state           = CAN_STATE;
// </test>

wire        clk_can;
reg [63:0]  data_to_send;

//<input>
reg        tx_message_type      = 1'b0;
reg [5:0]  local_address        = 6'b000101;//6'h2A;        
reg [5:0]  remote_address       = 6'b100010;
reg [1:0]  tx_handshake         = 2'b10;
reg [1:0]  tx_atribute          = 2'b10;
reg [3:0]  tx_expand_count      = 4'b1011;
reg [7:0]  tx_cmd_data_sign     = 8'b1111_0101;
reg [3:0]  tx_dlc               = 4'b1001;

reg [63:0] tx_data;
reg [31:0] can_send_setting;
//</input>

//<output>
reg  [63:0] rx_data_reg;
wire [63:0] rx_data;
//</output>

reg  tx_start;
reg  rx_start;
reg  tx_pending;
reg  init;

wire tx_o_tx;
wire tx_o_rx;

wire frame_sent;
wire can_is_free;
wire rx_frame_ready;



//<CAN MAIN FLOW>
assign tx_o = CAN_STATE == CAN_TX ? tx_o_tx :
            ( CAN_STATE == CAN_RX ? tx_o_rx : 1'b1 );

localparam  CAN_START_INIT = 0;
localparam  CAN_INIT       = 1;
localparam  CAN_IDLE       = 2;
localparam  CAN_PAUSE      = 3;
localparam  CAN_START_RX   = 4;
localparam  CAN_RX         = 5;
localparam  CAN_START_TX   = 6;
localparam  CAN_TX         = 7;
localparam  CAN_TEST_START = 8;
localparam  CAN_TEST       = 9;

reg [3:0] CAN_STATE;  
reg [10:0] count;

always @( posedge clk_can or negedge rst_i ) begin
    if ( rst_i == 1'b0 ) begin
        
    end else begin
        if ( count_rst == 1'b1 ) begin
            count <= 11'd0;
        end else begin
            count <= count + 1'b1;
        end
    end
end
        
always @( posedge clk_i or negedge rst_i ) begin
    if ( rst_i == 1'b0 ) begin
        CAN_STATE       <= CAN_IDLE;
        tx_start        <= 1'b0;
        rx_start        <= 1'b0;
        count_rst       <= 1'b0;
        init            <= 1'b0;
    end else begin
        case ( CAN_STATE )
        CAN_START_INIT: begin
                            init        <= 1'b1;
                            CAN_STATE   <= CAN_INIT;
                        end
        CAN_INIT:       begin
                            init        <= 1'b0;
                            CAN_STATE   <= CAN_IDLE;
                        end
        CAN_IDLE:       begin                              
                            if ( tx_pending == 1'b1 ) begin
                                CAN_STATE   <= CAN_START_TX;
                                tx_start    <= 1'b1;
                                rx_start    <= 1'b0;
                            end else begin
                                CAN_STATE   <= CAN_START_RX;
                                rx_start    <= 1'b1;
                            end
                        end
        CAN_PAUSE:      begin                           
                            if ( tx_pending == 1'b1 ) begin
                                if ( tx_lost_arbitrage == 1'b1 ) begin
                                    if ( count == 11'd11 ) begin
                                        count_rst <= 1'b1;
                                        CAN_STATE <= CAN_START_TX;
                                    end
                                end else begin
                                    if ( count == 11'd2 ) begin
                                        count_rst <= 1'b1;
                                        CAN_STATE <= CAN_START_TX;
                                    end
                                end
                            end else begin
                                if ( count == 11'd2 ) begin
                                    CAN_STATE <= CAN_START_RX;
                                end
                            end
                        end
        CAN_START_RX:   begin                            
                            if ( rx_busy == 1'b1 ) begin
                                CAN_STATE   <= CAN_RX;
                            end else begin 
                                CAN_STATE   <= CAN_IDLE;
                            end
                        end
        CAN_RX:         begin                             
                            if ( rx_busy == 1'b0 ) begin
                                rx_start    <= 1'b0;
                                count_rst   <= 1'b0;
                                CAN_STATE   <= CAN_PAUSE;   
                            end
                        end
        CAN_START_TX:   begin                               
                            if ( tx_busy == 1'b1 ) begin
                                CAN_STATE   <= CAN_TX;
                            end
                        end
        CAN_TX:         begin
                            if ( frame_sent == 1'b1 ) begin
                                tx_start    <= 1'b0;
                                count_rst   <= 1'b1;
                                CAN_STATE   <= CAN_PAUSE;
                            end
                        end
        CAN_TEST_START: begin                        
                            tx_start    <= 1'b1;
                            if ( rx_busy == 1'b1 ) begin
                                CAN_STATE   <= CAN_TEST;
                            end
                        end
        CAN_TEST:       begin
                            tx_start    <= 1'b0;
                            if ( rx_busy == 0 ) begin
                                rx_start  <= 1'b0;
                            end
                        end
        endcase
    end
end
//</CAN MAIN FLOW>

//<TX DATA DMA READ>
localparam  TX_READ_IDLE            = 0; 
localparam  TX_START_READ_SETTING   = 1;
localparam  TX_READ_SETTING         = 2;
localparam  TX_START_READ_DATA_1    = 3;
localparam  TX_READ_DATA_1          = 4;
localparam  TX_START_READ_DATA_2    = 5;
localparam  TX_READ_DATA_2          = 6;
localparam  TX_START_SEND_DATA      = 7;
localparam  TX_SEND_DATA            = 8;

reg [3:0] TX_DMA_STATE;  

always @( posedge clk_i or negedge rst_i ) begin
    if ( rst_i == 1'b0 ) begin
        can_send_setting    <= 32'd0;
        tx_data             <= 64'h0;
        tx_pending          <= 1'b0;       
    end else begin
        case ( TX_DMA_STATE ) 
        TX_READ_IDLE:           begin
                                    if ( tx_send_i == 1'b1  ) begin
                                         TX_DMA_STATE <= TX_START_READ_SETTING;
                                    end
                                end
        TX_START_READ_SETTING:  begin
                                    addr_rd           <= ADDR_SETTING_SEND;
                                    can_send_setting  <= data_rd;
                                    rd_en             <= 1'b1;
                                    TX_DMA_STATE      <= TX_READ_SETTING;
                                end
        TX_READ_SETTING:        begin
                                    rd_en             <= 1'b0;
                                    TX_DMA_STATE      <= TX_START_READ_DATA_1;
                                end
        TX_START_READ_DATA_1:   begin
                                    addr_rd           <= ADDR_DATA_SEND_1;
                                    tx_data[63:32]    <= data_rd;
                                    rd_en             <= 1'b1;
                                    TX_DMA_STATE      <= TX_READ_DATA_1;    
                                end
        TX_READ_DATA_1:         begin
                                    rd_en             <= 1'b0;
                                    TX_DMA_STATE      <= TX_START_READ_DATA_2;
                                end
        TX_START_READ_DATA_2:   begin
                                    addr_rd           <= ADDR_DATA_SEND_2;
                                    tx_data[31:0]     <= data_rd;
                                    rd_en             <= 1'b1;
                                    TX_DMA_STATE      <= TX_START_READ_DATA_2;  
                                end
        TX_READ_DATA_2:         begin
                                    rd_en             <= 1'b0;
                                    TX_DMA_STATE      <= TX_START_SEND_DATA;  
                                end
        TX_START_SEND_DATA:     begin
                                    tx_pending        <= 1'b1;
                                    TX_DMA_STATE      <= TX_SEND_DATA;
                                end
        TX_SEND_DATA:           begin
                                    if ( tx_busy ) begin
                                        tx_pending    <= 1'b0;
                                        TX_DMA_STATE  <= TX_READ_IDLE;
                                    end
                                end
        endcase                       
    end
end
//</TX DATA DMA READ>

//<RX DATA DMA READ>
localparam  RX_WRITE_IDLE            = 0; 
localparam  RX_START_WRITE_SETTING   = 1;
localparam  RX_WRITE_SETTING         = 2;
localparam  RX_START_WRITE_DATA_1    = 3;
localparam  RX_WRITE_DATA_1          = 4;
localparam  RX_START_WRITE_DATA_2    = 5;
localparam  RX_WRITE_DATA_2          = 6;
localparam  RX_START_SEND_DATA       = 7;
localparam  RX_SEND_DATA             = 8;

reg [3:0] RX_DMA_STATE;

always @( posedge clk_i or negedge rst_i ) begin
    if ( rst_i == 1'b0 ) begin
        rx_data_reg <= 64'h0;
    end else begin
        case ( TX_DMA_STATE ) 
        RX_WRITE_IDLE:          begin
                                    if ( tx_send_i == 1'b1  ) begin
                                         RX_DMA_STATE <= RX_START_READ_SETTING;
                                    end
                                end
        RX_START_WRITE_SETTING: begin
                                    addr_rd           <= ADDR_SETTING_SEND;
                                    can_send_setting  <= data_rd;
                                    rd_en             <= 1'b1;
                                    RX_DMA_STATE      <= RX_READ_SETTING;
                                end
        RX_WRITE_SETTING:       begin
                                    rd_en             <= 1'b0;
                                    RX_DMA_STATE      <= RX_START_READ_DATA_1;
                                end
        RX_START_WRITE_DATA_1:  begin
                                    addr_rd           <= ADDR_DATA_SEND_1;
                                    tx_data[63:32]    <= data_rd;
                                    rd_en             <= 1'b1;
                                    RX_DMA_STATE      <= RX_READ_DATA_1;    
                                end
        RX_WRITE_DATA_1:        begin
                                    rd_en             <= 1'b0;
                                    RX_DMA_STATE      <= RX_START_READ_DATA_2;
                                end
        RX_START_WRITE_DATA_2:  begin
                                    addr_rd           <= ADDR_DATA_SEND_2;
                                    tx_data[31:0]     <= data_rd;
                                    rd_en             <= 1'b1;
                                    RX_DMA_STATE      <= RX_START_READ_DATA_2;  
                                end
        RX_WRITE_DATA_2:        begin
                                    rd_en             <= 1'b0;
                                    RX_DMA_STATE      <= RX_START_SEND_DATA;  
                                end

        endcase                       

    end
end
//</RX DATA DMA READ>

can_tx #(
    .CLK_FREQ               (CLK_FREQ),
    .CAN_CLK_FREQ           (CAN_CLK_FREQ)
)can_tx_instance
(   
    .rst_i                  (rst_i),
    .clk_i                  (clk_i),
    .clk_can_i              (clk_can),
    .tx_start_i             (tx_start),
    .tx_lost_arbitrage_o    (tx_lost_arbitrage),
    .tx_acknowledged_o      (tx_acknowledged),
    .frame_sent_o           (frame_sent),
    
    .rx_i                   (rx_i),
    .tx_o                   (tx_o_tx),
    .tx_busy_o              (tx_busy),
    
    .message_type           (tx_message_type),
    .local_address          (local_address),
    .remote_address         (remote_address),
    .handshake              (tx_handshake),
    .expand_count           (tx_expand_count),
    .cmd_data_sign          (tx_cmd_data_sign),
    .dlc                    (tx_dlc),
    .tx_data                (tx_data),
    
    //test
    .test_tx_state          (test_can_tx_state),
    .test_bit_count         (test_bit_count),
    .test_bit_pol_count     (test_bit_pol_count),
    .test_arbi              (test_arbi)

);

can_rx #(
    .CLK_FREQ               (CLK_FREQ),
    .CAN_CLK_FREQ           (CAN_CLK_FREQ)
) can_rx_instance
(
    .rst_i                  (rst_i),
    .rx_i                   (rx_i),
    .tx_o                   (tx_o_rx),
    .clk_i                  (clk_i),
    .clk_can_i              (clk_can),
    .can_clk_sync_o         (can_clk_sync),
    .rx_start_i             (rx_start),
    .rx_busy_o              (rx_busy),
    .init_i                 (init),
    .rx_frame_ready_o       (rx_frame_ready),
    
    .local_address           (LOCAL_ADDRESS),
    
    
    //<data_out>
    .rx_data             (rx_data),
    
    //</data_out>
    
    //test
    .test_rx_state       (test_rx_state),
    .test_quant_count    (test_rx_quant_count),
    .test_bit_count      (test_rx_bit_count),
    .test_bit_pol_count  (test_rx_bit_pol_count),
    .test_rx_bit_stuffed (test_rx_bit_stuffed),
    .test_rx_count       (test_rx_count),
    .test_rx_rx          (test_rx_rx)
    //.test_sample_1       (test_sample)
);
                            
can_clk #(  
    .FREQ_I         (CLK_FREQ),
    .FREQ_O         (CAN_CLK_FREQ)
) can_clk_instance
(   
    .rst_i          (rst_i),
    .clk_i          (clk_i),
    .sync_i         (can_clk_sync),
    .can_clk_o      (clk_can) 
);
    
endmodule
