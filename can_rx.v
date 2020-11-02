module can_rx
#(
    parameter CLK_FREQ      = 50_000_000,
    parameter CAN_CLK_FREQ  = 1_000_000,
    parameter QUANTS        = CLK_FREQ/CAN_CLK_FREQ
)(
    input rst_i,
    input clk_i,
    input clk_can_i,
    input rx_start_i,
    input init_i,
    
    output reg          rx_busy_o,
    output reg          can_clk_sync_o,
    output reg          rx_frame_ready_o,
    
    input  [5:0]        local_address,
    
    input               message_type,
    input  [5:0]        rx_local_address,
    output reg [5:0]    remote_address,
    output [1:0]        handshake,
    output [3:0]        expand_count,
    output [7:0]        cmd_data_sign,
    output [3:0]        dlc,
    output reg [63:0]   rx_data,
    
    input  rx_i,
    output tx_o,
    
    //test
    output [7:0]  test_rx_state,
    output [11:0] test_quant_count,
    output [7:0]  test_bit_count,
    output [2:0]  test_bit_pol_count,
    output        test_rx_bit_stuffed,
    
    output [6:0]  test_rx_count,
    output reg    test_sample,
    output reg    test_rx_rx,
    output        test_sample_1
);
// <test>

assign test_rx_state       = RX_STATE;
assign test_quant_count    = quant_count;
assign test_bit_count      = bit_count_reg;
assign test_bit_pol_count  = bit_pol_count;
assign test_rx_bit_stuffed = rx_bit_stuffed;
assign test_rx_count       = count;

reg test_reg_on;
reg [6:0] test_count;
always @( posedge clk_can_i or negedge rst_i ) begin
    if ( rst_i == 1'b0 ) begin
        test_count  <= 7'd0;
        test_sample <= 1'b1;
    end else begin
        if ( test_reg_on == 1'b1 ) begin
            if ( test_count == 7'd15 ) begin
                test_sample <= 1'b1;
            end else begin
                test_sample <= crc_calc[7'd14 - test_count];
                test_count  <= test_count + 1'b1;
            end
        end else begin
            test_sample <= 1'b1;
            test_count  <= 7'd0;
        end
    end
end

always @( posedge clk_i or negedge rst_i ) begin
    if ( rst_i == 1'b0 ) begin
        test_rx_rx <= 1'b1;
    end else begin
        if ( RX_STATE != RX_IDLE ) begin
            if ( quant_count == SAMPLE ) begin
                test_rx_rx <= rx_i;
            end
        end else begin
            test_rx_rx <= 1'b1;
        end
    end
end
assign test_sample_1 = tx_o;	
// </test>

reg [5:0] local_adress_reg;
wire [5:0] local_adress;
// <init>
always @( posedge clk_i or negedge rst_i ) begin
    if ( rst_i == 1'b0 ) begin
        local_adress_reg <= 6'h0;
    end else begin
        if ( init_i == 1'b1 ) begin
            local_adress_reg <= local_adress;
        end
    end
end
// </init>

// <ACK>
reg acknowledged_aux;
assign tx_o = ( RX_STATE == RX_ACK_SLOT && acknowledged_aux ) ? 1'b0 : 1'b1;

always @( posedge clk_i or negedge rst_i ) begin
    if ( rst_i == 1'b0 ) begin
        acknowledged_aux    <= 1'b0;
    end else begin
        if ( RX_STATE == RX_HANDSHAKING_P ) begin
            if ( rx_address_remote == local_adress_reg ) begin
                acknowledged_aux <= 1'b1;
            end
        end else begin
            if ( RX_STATE == RX_IDLE ) begin
                acknowledged_aux <= 1'b0;
            end 
        end
    end
end
// </ACK>

//<CRC>
reg  [14:0] crc_calc;
wire [14:0] crc;
wire crc_en;
wire crc_clk;
assign crc_en = ( RX_STATE == RX_IDLE 		     || 
				  RX_STATE == RX_START_OF_FRAME  ||
				  RX_STATE == RX_BIT_STUFF 		 ||
                  RX_STATE == RX_ACK_SLOT 		 ||
                  RX_STATE == RX_ACK_DELIMITER   ||
                  RX_STATE == RX_END_OF_FRAME    ||
                  RX_STATE == RX_CRC_DELIMITER   ||
				  RX_STATE == RX_CRC ) ? 1'b0 : 1'b1;
assign crc_clk = ( quant_count == SAMPLE ) ? 1'b1 : 1'b0;					
reg crc_rst_i;
can_crc can_crc_instance
(
	.crc_clk_i	(crc_clk),
	.rst_i		(rst_i),
	.data_i		(rx_i),
	.en_i       (crc_en),
	.crc_reg_o	(crc),
	.crc_rst_i  (crc_rst_i)
);
//</CRC>

// <frame regs>
reg         rx_message_type;
reg [5:0]   rx_address_local;
reg [5:0]   rx_address_remote;
reg [1:0]   rx_handshaking_p;
reg [1:0]   rx_atribute_reserved;
reg [3:0]   rx_expand_count;
reg [7:0]   rx_cmd_data_sign;
reg [3:0]   rx_dlc;
reg [14:0]  rx_crc;
// </frame regs>

// <count and aux>
reg [7:0] bit_count_reg ;
reg [6:0] count; 
reg [2:0] bit_pol_count;
reg 	  last_bit;
reg 	  bit_stuff_bit; 
reg       rx_bit_stuffed;

reg rx_i_last;
reg aux_count;

reg [11:0] quant_count;
// </count and aux>

localparam SAMPLE = QUANTS/2;
localparam STATE_RES = 12'd0;

// 0xAx - MAC, 0xB-x - LLC
localparam RX_IDLE                  = 8'h00;
localparam RX_BIT_STUFF             = 8'h0B;
 
localparam RX_START_OF_FRAME        = 8'hA1;
localparam RX_MESSAGE_TYPE          = 8'hB1;
localparam RX_ADDRESS_LOCAL         = 8'hB2;
localparam RX_ADDRESS_REMOTE        = 8'hB3;
localparam RX_SRR                   = 8'hA2;
localparam RX_IDE                   = 8'hA3;
localparam RX_HANDSHAKING_P         = 8'hB4;
localparam RX_ATRIBUTE_RESERVED     = 8'hB5;
localparam RX_EXPAND_COUNT          = 8'hB6;
localparam RX_CMD_DATA_SIGN         = 8'hB7;
localparam RX_RTR                   = 8'hA4;
localparam RX_RESERVED              = 8'hA5;
localparam RX_DLC                   = 8'hB8;
localparam RX_DATA                  = 8'hB9;
localparam RX_CRC                   = 8'hA6;
localparam RX_CRC_DELIMITER         = 8'hA7;
localparam RX_ACK_SLOT              = 8'hA8;
localparam RX_ACK_DELIMITER         = 8'hA9;
localparam RX_END_OF_FRAME          = 8'hAA;

reg[7:0] RX_STATE;
reg[7:0] NEXT_RX_STATE;

always @( posedge clk_i or negedge rst_i ) begin
    if ( rst_i == 1'b0 ) begin
        RX_STATE                <= RX_IDLE;
        NEXT_RX_STATE           <= RX_IDLE;
        //<test>
        test_reg_on             <= 1'b0;
        //</test>
        rx_address_local        <= 6'd0;
        rx_address_remote       <= 6'd0;
        rx_handshaking_p        <= 2'd0;
        rx_atribute_reserved    <= 2'd0;
        rx_expand_count         <= 4'd0;
        rx_cmd_data_sign        <= 8'd0;
        rx_dlc                  <= 4'd0;
        rx_crc                  <= 15'd0;
        rx_data                 <= 64'd0;
        
        bit_count_reg           <= 8'd0;        
        count                   <= 7'd0;    
        bit_stuff_bit           <= 1'b0;
        last_bit                <= 1'b0;
        crc_rst_i               <= 1'b0;
        quant_count             <= 12'd1;
        rx_busy_o               <= 1'b0;
        aux_count               <= 1'b0;
        crc_calc                <= 15'd0;
        rx_i_last               <= 1'b0;
        aux_count               <= 1'b0;
        rx_frame_ready_o        <= 1'b0;
    end else begin
    if ( rx_start_i ) begin
        if ( RX_STATE != RX_IDLE ) begin
            quant_count      <= quant_count + 1'b1;
        end
        case ( RX_STATE )
        RX_IDLE:            begin
                                crc_rst_i <= 1'b0;    
                                bit_count_reg       <= 8'd0;
                                test_reg_on         <= 1'b0;
                                rx_frame_ready_o    <= 1'b0;                
                                if ( rx_i == 1'b0 && rx_i_last == 1'b1 ) begin
                                    RX_STATE        <= RX_START_OF_FRAME;
                                    quant_count     <= 12'd1;
                                    rx_busy_o       <= 1'b1;                           
                                end
                            end                                                                     
        // <MAC-level>
        
        // every 5 consequent same polarity bit add one reversed(not for CRC delimiter, ACK field and EOF)
        // 1 bit
        RX_BIT_STUFF:       begin
                                if ( aux_count == 1'b1 ) begin
                                    if ( quant_count == 12'd0 ) begin
                                        RX_STATE            <= NEXT_RX_STATE;
                                        aux_count <= 1'b0;
                                    end
                                end else begin
                                    if ( quant_count == SAMPLE ) begin
                                        aux_count <= 1'b1;
                                    end 
                                end
                            end             
        // 1 bit 
        RX_START_OF_FRAME:  begin
                                if ( aux_count == 1'b1 ) begin  
                                    if ( quant_count == STATE_RES ) begin
                                        RX_STATE        <= RX_MESSAGE_TYPE;
                                        NEXT_RX_STATE   <= RX_MESSAGE_TYPE;
                                        aux_count       <= 1'b0;
                                    end
                                end else begin
                                    if ( quant_count == SAMPLE ) begin
                                        aux_count <= 1'b1;
                                    end 
                                end
                            end               
        
        //  IDE and SRR are placed between 18 and 17 bit of 29 bit extended arbitration field
        // 1 bit
        RX_SRR:             begin
                                if ( aux_count == 1'b1 ) begin
                                     if ( quant_count == STATE_RES ) begin
                                        RX_STATE        <= RX_IDE;
                                        NEXT_RX_STATE   <= RX_IDE;
                                        aux_count       <= 1'b0;
                                     end
                                end else begin
                                    if ( quant_count == SAMPLE ) begin
                                        aux_count       <= 1'b1;
                                    end 
                                end
                            end
        // 1 bit
        RX_IDE:             begin
                                if ( aux_count == 1'b1 ) begin
                                    if ( quant_count == STATE_RES ) begin
                                        RX_STATE        <= RX_ADDRESS_REMOTE;
                                        NEXT_RX_STATE   <= RX_ADDRESS_REMOTE;
                                        aux_count       <= 1'b0;
                                    end
                                end else begin
                                    if ( quant_count == SAMPLE ) begin
                                        aux_count       <= 1'b1;
                                    end 
                                end
                            end
        // -- RTR-bit is 0 in the Data Frame, in the Remote Frame is 1 there and there is no Data Field 
        // in Remote Frame The DLC field indicates the data length of the requested message (not the transmitted one)
        // 1 bit
        RX_RTR:             begin
                                if ( aux_count == 1'b1 ) begin
                                    if ( quant_count == STATE_RES ) begin
                                        RX_STATE        <= RX_RESERVED;
                                        NEXT_RX_STATE   <= RX_RESERVED;
                                        aux_count       <= 1'b0;
                                    end
                                end else begin
                                    if ( quant_count == SAMPLE ) begin
                                        aux_count       <= 1'b1;
                                    end 
                                end
                            end
        // -- r1, r0 Reserved bits which must be set dominant (0), but accepted as either dominant or recessive 
        RX_RESERVED:        begin
                                if ( count == 7'd2 ) begin
                                    if ( quant_count == STATE_RES ) begin             
                                        RX_STATE        <= RX_DLC;
                                        NEXT_RX_STATE   <= RX_DLC;
                                        count           <= 7'd0;
                                    end
                                end else begin
                                    if ( quant_count == SAMPLE ) begin
                                        count           <= count + 1'b1;
                                    end
                                end
                            end
        // -- exclude start of the frame bit
        // 15 bit
        RX_CRC:             begin
                                if ( count == 7'd15 ) begin
                                    if ( quant_count == STATE_RES ) begin  
                                        count           <= 7'd0;
                                        RX_STATE        <= RX_CRC_DELIMITER;
                                        
                                        //
                                        test_reg_on <= 1'b1;
                                        //
                                    end
                                end else begin
                                    if ( quant_count == SAMPLE ) begin 
                                        rx_crc[7'd14 - count]   <= rx_i;
                                        count                   <= count + 1'b1;
                                    end
                                end     
                            end
        // -- must be 1
        // 1 bit
        RX_CRC_DELIMITER:   begin
                                if ( aux_count == 1'b1 ) begin
                                    if ( quant_count == STATE_RES ) begin
                                        RX_STATE        <= RX_ACK_SLOT;
                                        aux_count       <= 1'b0;
                                    end
                                end else begin
                                    if ( quant_count == SAMPLE ) begin
                                        aux_count       <= 1'b1;
                                    end 
                                end
                            end
        // -- Each node that receives the frame, without an error, transmits a 0 and thus overrides the 1 of the transmitter. 
        // If a transmitter detects a recessive level in the ACK slot, it knows that no receiver found a valid frame. 
        // A receiving node may transmit a recessive to indicate that it did not receive a valid frame, 
        // but another node that did receive a valid frame may override this with a dominant.
        // 1 bit
        RX_ACK_SLOT:        begin
                                if ( aux_count == 1'b1 ) begin
                                    if ( quant_count == STATE_RES ) begin
                                        RX_STATE        <= RX_ACK_DELIMITER;
                                        aux_count       <= 1'b0;
                                    end
                                end else begin
                                    if ( quant_count == SAMPLE ) begin
                                        aux_count       <= 1'b1;
                                    end 
                                end
                            end
        // 1 bit(1)
        RX_ACK_DELIMITER:   begin
                                if ( aux_count == 1'b1 ) begin
                                    if ( quant_count == STATE_RES ) begin
                                        RX_STATE        <= RX_END_OF_FRAME;
                                        aux_count       <= 1'b0;
                                    end
                                end else begin
                                    if ( quant_count == SAMPLE ) begin
                                        aux_count       <= 1'b1;
                                    end 
                                end
                            end
        // 7 bits(1)
        RX_END_OF_FRAME:    begin   
                                rx_frame_ready_o <= 1'b1;
                                if ( count == 7'd7 ) begin
                                    if ( quant_count == STATE_RES ) begin        
                                        RX_STATE        <= RX_IDLE;
                                        crc_rst_i       <= 1'b1;
                                        count           <= 7'd0;
                                        rx_busy_o       <= 1'b0;
                                    end
                                end else begin
                                    if ( quant_count == SAMPLE ) begin
                                        count           <= count + 1'b1;
                                    end
                                end 
                            end                             
        // </MAC-level>                 
           
        // <LLC-level>
        //      <Identificator>
        //      C/D 1 bit
        RX_MESSAGE_TYPE:    begin
                                if ( count == 7'd1 ) begin
                                    if ( quant_count == STATE_RES ) begin
                                        RX_STATE        <= RX_ADDRESS_LOCAL;
                                        NEXT_RX_STATE   <= RX_ADDRESS_LOCAL;
                                        count           <= 7'd0;
                                    end
                                end else begin
                                    if ( quant_count == SAMPLE ) begin
                                        rx_message_type  <= rx_i;
                                        count            <= count + 1'b1;
                                    end
                                end  
                            end
        //      Address local 6 bit
        RX_ADDRESS_LOCAL:   begin                              
                                if ( count == 7'd6 ) begin
                                    if ( quant_count == STATE_RES ) begin
                                        RX_STATE        <= RX_ADDRESS_REMOTE;
                                        NEXT_RX_STATE   <= RX_ADDRESS_REMOTE;
                                        count           <= 7'd0;   
                                    end 
                                end else begin
                                    if ( quant_count == SAMPLE ) begin
                                        rx_address_local[7'd5 - count]  <= rx_i;
                                        count                           <= count + 1'b1;
                                    end
                                end
                            end
        //      Address remote 6 bit                
        RX_ADDRESS_REMOTE:  begin
                                if ( count == 7'd6 ) begin
                                    if ( quant_count == STATE_RES) begin  
                                        RX_STATE            <= RX_HANDSHAKING_P;
                                        NEXT_RX_STATE       <= RX_HANDSHAKING_P;
                                        count               <= 7'd0;    
                                    end 
                                end else begin
                                    if ( count == 7'd4 ) begin
                                        if ( quant_count == STATE_RES ) begin  
                                            RX_STATE        <= RX_SRR;
                                            NEXT_RX_STATE   <= RX_SRR;
                                        end else begin
                                            if ( quant_count == SAMPLE ) begin
                                                rx_address_remote[7'd5 - count]  <= rx_i;
                                                count                            <= count + 1'b1;
                                            end                                           
                                        end
                                    end else begin 
                                        if ( quant_count == SAMPLE ) begin
                                            rx_address_remote[7'd5 - count]  <= rx_i;
                                            count                            <= count + 1'b1;               
                                        end 
                                    end
                                end
                            end
        //      </Identificator>
        //  <Atribute>      
        //      DataFrame: pointer, CommandFrame: handshaking 2 bit
        RX_HANDSHAKING_P:       begin
                                    if ( count == 7'd2 ) begin
                                        if ( quant_count == STATE_RES ) begin
                                            RX_STATE            <= RX_ATRIBUTE_RESERVED;
                                            NEXT_RX_STATE       <= RX_ATRIBUTE_RESERVED;
                                            count               <= 7'd0;
                                        end    
                                    end else begin
                                        if ( quant_count == SAMPLE ) begin
                                            rx_handshaking_p[7'd1 - count]  <= rx_i;
                                            count                           <= count + 1'b1;
                                        end
                                    end
                                end
        //      DataFrame: reserved 2'b00, CommandFrame: 2'b10 2 bit
        RX_ATRIBUTE_RESERVED:begin
                                if ( count == 7'd2 ) begin
                                    if ( quant_count == STATE_RES ) begin                                   
                                        RX_STATE            <= RX_EXPAND_COUNT;
                                        NEXT_RX_STATE       <= RX_EXPAND_COUNT;
                                        count               <= 7'd0;
                                    end 
                                end else begin
                                    if ( quant_count == SAMPLE ) begin
                                        rx_atribute_reserved[7'd1 - count]  <= rx_i;
                                        count                               <= count + 1'b1;
                                    end
                                end                                     
                            end 
        //      DataFrame: frame count, CommandFrame: expand command field 4 bit        
        RX_EXPAND_COUNT:    begin
                                if ( count == 7'd4 ) begin
                                    if ( quant_count == STATE_RES ) begin                                           
                                        RX_STATE            <= RX_CMD_DATA_SIGN;
                                        NEXT_RX_STATE       <= RX_CMD_DATA_SIGN;
                                        count               <= 7'd0;
                                    end    
                                end else begin
                                    if ( quant_count == SAMPLE ) begin
                                        rx_expand_count[7'd3 - count]   <= rx_i;
                                        count                           <= count + 1'b1;
                                    end
                                end
                            end
        //      DataFrame: type of data, CommandFrame: type of command 8 bit
        RX_CMD_DATA_SIGN:   begin
                                if ( count == 7'd8 ) begin
                                    if ( quant_count == STATE_RES ) begin 
                                        RX_STATE            <= RX_RTR;
                                        NEXT_RX_STATE       <= RX_RTR;
                                        count               <= 7'd0;
                                    end  
                                end else begin
                                    if ( quant_count == SAMPLE ) begin
                                        rx_cmd_data_sign[7'd7 - count]  <= rx_i;
                                        count                           <= count + 1'b1;
                                    end
                                end                                     
                            end
        //      DLC 4 bit
        RX_DLC:             begin
                                if ( count == 7'd4 ) begin
                                    if ( quant_count == STATE_RES ) begin                                         
                                        RX_STATE            <= RX_DATA;
                                        NEXT_RX_STATE       <= RX_DATA;
                                        count               <= 7'd0;
                                    end 
                                end else begin
                                    if ( quant_count == SAMPLE ) begin
                                        rx_dlc[7'd3 - count]    <= rx_i;
                                        count                   <= count + 1'b1;
                                    end
                                end                                         
                             end
        //          Data 0 or 64 bit
        RX_DATA:             begin
                                if ( count == 7'd64 ) begin
                                    if ( quant_count == STATE_RES ) begin                                        
                                        RX_STATE            <= RX_CRC;
                                        NEXT_RX_STATE       <= RX_CRC;
                                        count               <= 7'd0;
                                        //
                                        crc_calc <= crc;
                                     end
                                end else begin
                                    if ( quant_count == SAMPLE ) begin
                                        rx_data[7'd63 - count]  <= rx_i;
                                        count                   <= count + 1'b1;
                                    end
                                end     
                            end
    // </LLC-level>
        endcase     
        
        // <can clk sync>
        if ( rx_i == 1'b0 && rx_i_last == 1'b1 ) begin
            can_clk_sync_o  <= 1'b1; 
        end else begin
            can_clk_sync_o  <= 1'b0;
        end
        // </can clk sync>
        
        // <bit stuff check>
        if ( quant_count == STATE_RES ) begin
            if ( rx_bit_stuffed ) begin
                RX_STATE    <= RX_BIT_STUFF;                   
            end
         end       
        // </bit stuff check>
        
        // <bit count>
        if ( RX_STATE != RX_IDLE  ) begin
            if ( quant_count == SAMPLE ) begin
                last_bit        <= rx_i;
                bit_count_reg   <= bit_count_reg + 1'b1;
            end
        end
        // </bit count>
        
        // <quant count>
        if ( quant_count == QUANTS ) begin
            quant_count     <= STATE_RES;
        end
        // </quant count>
        
        // <quant sync>
        if ( rx_i != rx_i_last && RX_STATE != RX_IDLE ) begin
            quant_count     <= STATE_RES;
        end
        // </quant sync>
        
        rx_i_last <= rx_i; 
        
        end
    end
        
end

// <bit_stuffing>
always @( posedge clk_i or negedge rst_i ) begin
        if ( rst_i == 1'b0 ) begin
            rx_bit_stuffed <= 1'b0;
            bit_pol_count  <= 1'b0;
        end else begin
            if ( quant_count == SAMPLE ) begin
                if (  RX_STATE != RX_IDLE           && 
                      RX_STATE != RX_CRC_DELIMITER  && 
                      RX_STATE != RX_ACK_SLOT       && 
                      RX_STATE != RX_ACK_DELIMITER  && 
                      RX_STATE != RX_END_OF_FRAME ) begin
                    if ( rx_i == last_bit ) begin   
                        bit_pol_count       <= bit_pol_count + 1'b1;
                        if ( bit_pol_count == 3'd5 ) begin                       
                            bit_pol_count   <= 3'd1;
                        end                    
                    end else begin                      
                        bit_pol_count   <= 3'd1;                                
                    end
                end
            end else begin 
                if ( quant_count == STATE_RES ) begin
                     rx_bit_stuffed  <= 1'b0;
            end else begin
                if ( bit_pol_count == 3'd5 && RX_STATE != RX_BIT_STUFF ) begin                       
                    rx_bit_stuffed  <= 1'b1;
                end
            end
        end
    end
end
// </bit stuffing>

endmodule 