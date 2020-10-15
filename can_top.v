// Extended CAN format
// 1(SOF)+11(Arb1)+2(SRR,IDE)+11(Arb2)+1(RTR)+1(r1)+1(r0)+4(Control)+64(Data)+15(CRC Field)+1(CRC Delimeter)+2(Ack)+7(EoF)+3(Idle)
module can_top
(   
    input  rst_i,
    input  clk_i,
    
    input  rx_i,
    output rx_busy,
    
    
    output tx_o,
    output tx_busy,
    
    // tx fields
    //input             tx_message_type,
    //input [5:0]       tx_address_remote,
    
    //input [63:0]  tx_data_i,
    
    // - output CAN frame LLC/DLC data
    
    
    
    // test
    output test_clk_can,
    output [2:0] test_can_state,
    output [7:0] test_can_tx_state,
    output [7:0] test_bit_count,
    output [3:0] test_bit_pol_count,
    output reg bit_stuffed,
    output test_last_bit,
    
    output [7:0]  test_rx_state,
    output [11:0] test_rx_quant_count,
    output [7:0]  test_rx_bit_count,
    output [3:0]  test_rx_bit_pol_count,
    output        test_rx_bit_stuffed,
    output [6:0]  test_rx_count,
    output test_rx_rx
);




// <test>
assign test_clk_can             = clk_can;
assign test_can_state           = CAN_STATE;
// </test>

wire            clk_can;
reg [63:0]  data_to_send;



//<input>
reg        tx_message_type      = 1'b0;
reg [5:0]  tx_local_address     = 6'b000101;//6'h2A;        
reg [5:0]  tx_remote_address    = 6'b100010;
reg [1:0]  tx_handshake         = 2'b10;
reg [1:0]  tx_atribute          = 2'b10;
reg [3:0]  tx_expand_count      = 4'b1011;
reg [7:0]  tx_cmd_data_sign     = 8'b1111_0101;
reg [3:0]  tx_dlc               = 4'b1001;
reg [63:0] tx_data              = 64'b0011000100110010001100110011010000110101001101100011011100111000;
//</input>

reg      tx_start;
reg      rx_start;

localparam  CAN_IDLE       = 0;
localparam  CAN_START_RX   = 1;
localparam  CAN_RX         = 2;
localparam  CAN_START_TX   = 3;
localparam  CAN_TX         = 4;

reg[3:0]    CAN_STATE;  
        
always @( posedge clk_can or posedge rst_i ) begin
    if ( rst_i ) begin
        CAN_STATE       <= CAN_IDLE;
        tx_start            <= 1'b0;
    end else begin
        case ( CAN_STATE )
        CAN_IDLE:       begin
                                CAN_STATE <= CAN_START_RX;                          
                        end
        CAN_START_RX:   begin
                            rx_start    <= 1'b1;
                            if ( rx_busy == 1'b1 ) begin
                                CAN_STATE   <= CAN_RX;
                            end
                        end
        CAN_RX:         begin                             
                            if ( rx_busy == 0 ) begin
                                rx_start  <= 1'b0;
                            end
                        end
        CAN_START_TX:   begin
                                CAN_STATE   <= CAN_TX;
                                tx_start    <= 1'b1;
                            end
        CAN_TX:         begin
                                
                                tx_start    <= 1'b0;
                            end
        endcase
    end
end




can_tx can_tx_instance
(   
    .rst_i                  (rst_i),
    .clk_can_i              (clk_can),
    .tx_start_i             (tx_start),
    .tx_lost_o              (tx_lost),
    .tx_acknowledged_o  (tx_acknowledged),
    
    .rx_i                       (rx_i),
    .tx_o                   (tx_o),
    
    .message_type           (tx_message_type),
    .local_address          (tx_local_address),
    .remote_address         (tx_remote_address),
    .handshake              (tx_handshake),
    .expand_count           (tx_expand_count),
    .cmd_data_sign          (tx_cmd_data_sign),
    .dlc                    (tx_dlc),
    .tx_data                (tx_data),
    
    //test
    .test_tx_state          (test_can_tx_state),
    .test_bit_count         (test_bit_count),
    .test_bit_pol_count     (test_bit_pol_count)

);

can_rx can_rx_instance
(
    .rst_i          (rst_i),
    .rx_i           (rx_i),
    .clk_i          (clk_i),
    .clk_can_i      (clk_can),
    .can_clk_sync_o (can_clk_sync),
    .rx_start_i     (rx_start),
    .rx_busy_o      (rx_busy),
    
    //test
    .test_rx_state       (test_rx_state),
    .test_quant_count    (test_rx_quant_count),
    .test_bit_count      (test_rx_bit_count),
    .test_bit_pol_count  (test_rx_bit_pol_count),
    .test_rx_bit_stuffed (test_rx_bit_stuffed),
    .test_rx_count       (test_rx_count),
    .test_rx_rx          (test_rx_rx)
);
                            
can_clk can_clk_instance
(
    .rst_i          (rst_i),
    .clk_i          (clk_i),
    .sync_i         (1'b0),
    .can_clk_o      (clk_can)
);
    

endmodule
