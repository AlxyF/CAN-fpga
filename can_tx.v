module can_tx
#(
	parameter smth = 0
)(
	input rst_i,
	input clk_can_i,
	input tx_start_i,
	
	output tx_lost_o,
	output tx_acknowledged_o,
	
	input message_type,
	input [5:0] local_address,
	input [5:0] remote_address,
	input [1:0] handshake,
	input [3:0] expand_count,
	input [7:0] cmd_data_sign,
	input [3:0] dlc,
	input [63:0] tx_data,
	
	input  rx_i,
	output tx_o,
	
	//test
	output [7:0] test_tx_state,
	output [7:0] test_bit_count,
	output [2:0] test_bit_pol_count
);
//test
assign test_tx_state      = TX_STATE;
assign test_bit_count     = bit_count_reg;  
assign test_bit_pol_count = bit_pol_count;

reg [6:0] count;
//<CRC>
wire [14:0] crc;
wire crc_en;
assign crc_en = ( TX_STATE == TX_IDLE 		    || 
                TX_STATE == TX_START_OF_FRAME   ||
                TX_STATE == TX_BIT_STUFF 	    ||
                TX_STATE == TX_CRC ) ? 1'b0 : 1'b1;
						
reg crc_rst_i;
can_crc can_crc_instance
(
	.clk_can_i	(clk_can_i),
	.rst_i		(rst_i),
	.data_i		(tx_o),
	.en_i		(crc_en),
	.crc_reg_o	(crc),
	.crc_rst_i  (crc_rst_i)
);
//</CRC>

//<bit stuff>
reg [7:0] 	bit_count_reg;					
reg [2:0] 	bit_pol_count;
reg 		last_bit;
reg 		bit_stuff_bit; 
//</bit stuff>

// <arbitrage>
reg 	tx_lost_o_reg;
assign  tx_lost_o = tx_lost_o_reg;
// </arbitrage>

// 0xAx - MAC-lvl, 0xB-x - LLC-lvl
localparam TX_IDLE          		= 8'h00;
localparam TX_BIT_STUFF    		    = 8'h0B;
 
localparam TX_START_OF_FRAME  	    = 8'hA1;
localparam TX_MESSAGE_TYPE  		= 8'hB1;
localparam TX_ADDRESS_LOCAL     	= 8'hB2;
localparam TX_ADDRESS_REMOTE        = 8'hB3;
localparam TX_SRR    		 		= 8'hA2;
localparam TX_IDE  		    		= 8'hA3;
localparam TX_HANDSHAKING_P 		= 8'hB4;
localparam TX_ATRIBUTE_RESERVED	    = 8'hB5;
localparam TX_EXPAND_COUNT  		= 8'hB6;
localparam TX_CMD_DATA_SIGN 		= 8'hB7;
localparam TX_RTR				    = 8'hA4;
localparam TX_RESERVED				= 8'hA5;
localparam TX_DLC				 	= 8'hB8;
localparam TX_DATA			 		= 8'hB9;
localparam TX_CRC 					= 8'hA6;
localparam TX_CRC_DELIMITER		    = 8'hA7;
localparam TX_ACK_SLOT				= 8'hA8;
localparam TX_ACK_DELIMITER		    = 8'hA9;
localparam TX_END_OF_FRAME			= 8'hAA;

reg[7:0] TX_STATE;
reg[7:0] NEXT_TX_STATE;
						
always @( posedge clk_can_i or posedge rst_i ) begin
	if ( rst_i ) begin
		TX_STATE                <= TX_IDLE;
		NEXT_TX_STATE 			<= TX_IDLE;
		tx_lost_o_reg			<= 1'b0;
		bit_count_reg 			<= 8'd0;		
		count 					<= 7'd0;	
        bit_pol_count 			<= 3'd1;
		bit_stuff_bit			<= 1'b0;
        last_bit			    <= 1'b0;
		crc_rst_i 				<= 1'b0;
	end else begin
		if ( TX_STATE != TX_IDLE  ) begin
			last_bit 		<= tx_o;
			bit_count_reg   <= bit_count_reg + 1'b1;		
		end
		case ( TX_STATE )
		TX_IDLE: 			begin	
                                count 			<= 3'd0;
                                bit_count_reg 	<= 8'd0;
                                if ( tx_start_i ) begin									
                                    TX_STATE		<= TX_START_OF_FRAME;                                                                               
                                end
							end																		
		// <MAC-level>
		
		// every 5 consequent same polarity bit add one reversed(not for CRC delimiter, ACK field and EOF)
		// 1 bit
		TX_BIT_STUFF: 		begin		
									TX_STATE 		<= NEXT_TX_STATE;	
							end				
		// 1 bit 
		TX_START_OF_FRAME:  begin											
									TX_STATE 	  	<= TX_MESSAGE_TYPE;
									NEXT_TX_STATE 	<= TX_MESSAGE_TYPE;
									crc_rst_i       <= 1'b0;							
							end					
		
		//	IDE and SRR are placed between 18 and 17 bit of 29 bit extended arbitration field
		// 1 bit
		TX_SRR:				begin
									TX_STATE 		<= TX_IDE;
									NEXT_TX_STATE 	<= TX_IDE;
							end
		// 1 bit
		TX_IDE:				begin
									TX_STATE 		<= TX_ADDRESS_REMOTE;
									NEXT_TX_STATE 	<= TX_ADDRESS_REMOTE;
							end
		// -- RTR-bit is 0 in the Data Frame, in the Remote Frame is 1 there and there is no Data Field 
		// in Remote Frame The DLC field indicates the data length of the requested message (not the transmitted one)
		// 1 bit
		TX_RTR:				begin
									TX_STATE 		<= TX_RESERVED;
									NEXT_TX_STATE 	<= TX_RESERVED;
							end
		// -- r1, r0 Reserved bits which must be set dominant (0), but accepted as either dominant or recessive 
		TX_RESERVED:		begin
                                if ( count == 7'd1 ) begin
                                    count 			<= 7'd0;
                                    TX_STATE 		<= TX_DLC;
                                    NEXT_TX_STATE 	<= TX_DLC;
                                end else begin
                                    count 			<= count + 1'b1;
                                end
							end
		// -- exclude start of the frame bit
		// 15 bit
		TX_CRC:				begin
                                if ( count == 7'd14 ) begin
                                    count 			<= 7'd0;
                                    TX_STATE 		<= TX_CRC_DELIMITER;
                                    crc_rst_i      <= 1'b1;
                                end else begin
                                    count 			<= count + 1'b1;
                                end		
							end
		// -- must be 1
		// 1 bit
		TX_CRC_DELIMITER:	begin
                                    TX_STATE 		<= TX_ACK_SLOT;
							end
		// -- Each node that receives the frame, without an error, transmits a 0 and thus overrides the 1 of the transmitter. 
		// If a transmitter detects a recessive level in the ACK slot, it knows that no receiver found a valid frame. 
		// A receiving node may transmit a recessive to indicate that it did not receive a valid frame, 
		// but another node that did receive a valid frame may override this with a dominant.
		// 1 bit
		TX_ACK_SLOT:		begin
                                    TX_STATE 		<= TX_ACK_DELIMITER;
							end
		// 1 bit(1)
		TX_ACK_DELIMITER:	begin
                                    TX_STATE 		<= TX_END_OF_FRAME;
							end
		// 7 bits(1)
		TX_END_OF_FRAME:	begin
                                if ( count == 7'd6 ) begin
                                    count 			<= 7'd0;
                                    TX_STATE 		<= TX_IDLE;
                                end else begin
                                    count 			<= count + 1'b1;
                                end	
							end								
		// </MAC-level>			
																						
		// <LLC-level>
		//		<Identificator>
		// 		C/D 1 bit
		TX_MESSAGE_TYPE:	begin
                                TX_STATE 	  			<= TX_ADDRESS_LOCAL;
                                NEXT_TX_STATE 			<= TX_ADDRESS_LOCAL;	
							end
		// 		Address local 6 bit
		TX_ADDRESS_LOCAL:  	begin
                                if ( count == 7'd5 ) begin
                                    count 				<= 7'd0;							
                                    TX_STATE 			<= TX_ADDRESS_REMOTE;
                                    NEXT_TX_STATE 		<= TX_ADDRESS_REMOTE;	
                                end else begin													
                                    count 				<= count + 1'b1;	
                                end
							end
		// 		Address remote 6 bit				
		TX_ADDRESS_REMOTE:	begin
                                if ( count == 7'd5 ) begin
                                    count 				<= 7'd0;	
                                    TX_STATE 			<= TX_HANDSHAKING_P;
                                    NEXT_TX_STATE 		<= TX_HANDSHAKING_P;	
                                end else begin					
                                    if ( count == 7'd3 ) begin
                                        count 			<= count + 1'b1;
                                        TX_STATE 		<= TX_SRR;
                                        NEXT_TX_STATE 	<= TX_SRR;
                                    end else begin																			
                                        count 			<= count + 1'b1;
                                    end	
                                end
							end
		//		</Identificator>
		// 	<Atribute>		
		// 		DataFrame: pointer, CommandFrame: handshaking 2 bit
		TX_HANDSHAKING_P:   begin
                                if ( count == 7'd1 ) begin
                                    count				<= 7'd0;
                                    TX_STATE 			<= TX_ATRIBUTE_RESERVED;
                                    NEXT_TX_STATE 		<= TX_ATRIBUTE_RESERVED;	
                                end else begin
                                    count 				<= count + 1'b1;
                                end
                            end
		// 		DataFrame: reserved 2'b00, CommandFrame: 2'b10 2 bit
		TX_ATRIBUTE_RESERVED:begin
                                if ( count == 7'd1 ) begin
                                    count				<= 7'd0;
                                    TX_STATE 			<= TX_EXPAND_COUNT;
                                    NEXT_TX_STATE 		<= TX_EXPAND_COUNT;	
                                end else begin
                                    count 				<= count + 1'b1;
                                end										
							end	
		// 		DataFrame: frame count, CommandFrame: expand command field 4 bit		
		TX_EXPAND_COUNT:	begin
                                if ( count == 7'd3 ) begin
                                    count				<= 7'd0;
                                    TX_STATE 			<= TX_CMD_DATA_SIGN;
                                    NEXT_TX_STATE 		<= TX_CMD_DATA_SIGN;	
                                end else begin
                                    count 				<= count + 1'b1;
                                end
							end
		// 		DataFrame: type of data, CommandFrame: type of command 8 bit
		TX_CMD_DATA_SIGN: 	begin
                                if ( count == 7'd7 ) begin
                                    count				<= 7'd0;
                                    TX_STATE 			<= TX_RTR;
                                    NEXT_TX_STATE 		<= TX_RTR;	
                                end else begin
                                    count 				<= count + 1'b1;
                                end										
							end
		// 		DLC 4 bit
		TX_DLC:				begin
                                if ( count == 7'd3 ) begin
                                    count				<= 7'd0;
                                    TX_STATE 			<= TX_DATA;
                                    NEXT_TX_STATE 		<= TX_DATA;	
                                end else begin
                                    count 				<= count + 1'b1;
                                end											
							end
		//			Data 0 or 64 bit
		TX_DATA:			begin
                                if ( count == 7'd63 ) begin
                                    count				<= 7'd0;
                                    TX_STATE 			<= TX_CRC;
                                    NEXT_TX_STATE 		<= TX_CRC;
                                end else begin
                                    count 				<= count + 1'b1;
                                end		
							end
		// </LLC-level>
		endcase		
	
		// <bit stuff check>
		if (    TX_STATE !=	TX_IDLE 	        && 
                TX_STATE != TX_CRC_DELIMITER 	&& 
                TX_STATE !=	TX_ACK_SLOT 		&& 
                TX_STATE !=	TX_ACK_DELIMITER 	&& 
				TX_STATE !=	TX_END_OF_FRAME ) begin
			if ( tx_o == last_bit ) begin	
				bit_pol_count 			<= bit_pol_count + 1'b1;					
					if ( bit_pol_count == 3'd5 ) begin
						if ( tx_o == 1'b0 ) begin
							bit_stuff_bit <= 1'b1;
						end else begin
							bit_stuff_bit <= 1'b0;
						end							
						bit_pol_count 	<= 3'd1;
						TX_STATE 	  	<= TX_BIT_STUFF;
					end				
			end else begin						
				bit_pol_count 	<= 3'd2;								
			end
		end
		// </bit stuff check>
		
		//<arbitrage>
		if ( TX_STATE != TX_IDLE &&
			TX_STATE != TX_ACK_SLOT ) begin
			if ( tx_o != rx_i ) begin
				tx_lost_o_reg 	<= 1'b1;
                //TX_STATE  		<= TX_IDLE;
			end
		end
		//</arbitrage>
		
	end
end

//<acknowledgement>
reg tx_acknowledged_o_reg;
assign tx_acknowledged_o = tx_acknowledged_o_reg;

always @( posedge clk_can_i or posedge rst_i ) begin
	if ( rst_i ) begin
		tx_acknowledged_o_reg <= 1'b0;
	end else begin
		if ( TX_STATE == TX_ACK_SLOT ) begin
			if ( rx_i == 1'b0 ) begin
				tx_acknowledged_o_reg <= 1'b1;
			end
		end
	end
end
//</acknowledgement>

reg [1:0] atribute = 2'b10;
reg rtr = 1'b0;
assign tx_o = TX_STATE == TX_START_OF_FRAME 		? 1'b0 									:												
				( TX_STATE == TX_MESSAGE_TYPE 		? message_type 						:
				( TX_STATE == TX_ADDRESS_LOCAL 		? local_address	[7'd5 - count] :	
				( TX_STATE == TX_ADDRESS_REMOTE 		? remote_address	[7'd5 - count] :
				( TX_STATE == TX_SRR 					? 1'b1 									:
				( TX_STATE == TX_IDE 					? 1'b1 									:
				( TX_STATE == TX_HANDSHAKING_P 		? handshake			[7'd1 - count]	:
				( TX_STATE == TX_ATRIBUTE_RESERVED 	? atribute			[7'd1 - count]	:
				( TX_STATE == TX_EXPAND_COUNT 		? expand_count		[7'd3 - count] :
				( TX_STATE == TX_CMD_DATA_SIGN 		? cmd_data_sign	[7'd7 - count]	:
				( TX_STATE == TX_RTR 					? rtr										:
				( TX_STATE == TX_RESERVED 				? 1'b0									:
				( TX_STATE == TX_DLC 					? dlc					[7'd3 - count]	:
				( TX_STATE == TX_DATA 					? tx_data			[7'd63 - count]:
				( TX_STATE == TX_CRC 					? crc		         [7'd14 - count]:
				( TX_STATE == TX_CRC_DELIMITER 		? 1'b1									:
				( TX_STATE == TX_ACK_SLOT 				? 1'b1									:
				( TX_STATE == TX_ACK_DELIMITER 		? 1'b1									:
				( TX_STATE == TX_END_OF_FRAME 		? 1'b1									:
				( TX_STATE == TX_BIT_STUFF				? bit_stuff_bit						:
				1'b1 )))))))))))))))))));

endmodule