module can_top
(	
	// this is extended CAN format
	// message length 1(SOF)+11(Arb1)+2(SRR,IDE)+11(Arb2)+1(RTR)+1(r1)+1(r0)+4(Control)+64(Data)+15(CRC Field)+1(CRC Delimeter)+2(Ack)+7(EoF)+3(Idle)
	input  rst_i,
	input  clk_i,
	
	input  rx_i,
	output rx_busy,
	
	input  tx_send,
	output tx_o,
	output tx_busy,
	
	input command_or_data,
	
	// - output CAN frame LLC/DLC data
	
	// -- Arbitration field
	//input type, 							// command 0, data 1
	input [5:0] address_sender,		// 
	input [5:0] address_recipient,	// 
	input [1:0] sign, 				   // kvitirovanie
	//input 		type,
	// -- Control
	input [3:0] data_l_i,
	
	// -- Data
	input [63:0] data_b_i,
	
	output [7:0] data_o,
	
	// test
	output test_clk_can,
	output [2:0] test_can_state,
	output [7:0] test_can_tx_state,
	output [7:0] bit_count,
	output [3:0] test_bit_pol_count,
	output reg bit_stuffed,
	output test_last_bit
);
// <test>
//<input>
reg tx_message_type = 1'b0;
//</input>
assign test_clk_can   			= clk_can;
assign test_can_tx_state 		= TX_STATE;
assign test_can_state   	 	= CAN_STATE;
assign bit_count   				= bit_count_reg;
assign test_bit_pol_count 		= bit_pol_count;

assign test_last_bit				= last_bit;
// </test>


wire 			clk_can;

reg [63:0] 	data_to_send;

// constant regs
localparam [5:0] local_address  = 6'b101011;//6'h2A;		
localparam [5:0] remote_address = 6'b010110;

localparam CAN_IDLE = 0;
localparam CAN_RX   = 1;
localparam CAN_TX   = 2;

reg[3:0] CAN_STATE;	
		
always @( posedge clk_i or posedge rst_i ) begin
	if ( rst_i ) begin
		CAN_STATE <= CAN_IDLE;
	end else begin
		case ( CAN_STATE )
		CAN_IDLE:	begin
							CAN_STATE <= CAN_TX;
						end
		CAN_RX:			begin
						end
		CAN_TX:		begin
							
						end
		endcase
	end
end

reg [6:0] count;

//<Bit stuff>
reg [7:0] 	bit_count_reg;					
reg [2:0] 	bit_pol_count;
reg 		 	last_bit;
reg 			bit_stuff_bit; 
//</Bit stuff>

//<CRC>
reg [14:0] 	crc_reg;
wire 			crc_next;
wire [14:0] crc_tmp;
assign crc_next = tx_o ^ crc_reg[14];
assign crc_tmp  = {crc_reg[13:0], 1'b0};
//</CRC>

// 0xAx - MAC-lvl, 0xB-x - LLC-lvl
localparam TX_IDLE          		= 8'h00;
localparam TX_BIT_STUFF    		= 8'h0B;
 
localparam TX_START_OF_FRAME  	= 8'hA1;
localparam TX_MESSAGE_TYPE  		= 8'hB1;
localparam TX_ADDRESS_LOCAL     	= 8'hB2;
localparam TX_ADDRESS_REMOTE     = 8'hB3;
localparam TX_SRR    		 		= 8'hA2;
localparam TX_IDE  		    		= 8'hA3;
localparam TX_HANDSHAKING_P 		= 8'hB4;
localparam TX_ATRIBUTE_RESERVED	= 8'hB5;
localparam TX_EXPAND_COUNT  		= 8'hB6;
localparam TX_CMD_DATA_SIGN 		= 8'hB7;
localparam TX_RTR						= 8'hA4;
localparam TX_RESERVED				= 8'hA5;
localparam TX_DLC				 		= 8'hB8;
localparam TX_DATA			 		= 8'hB9;
localparam TX_CRC 					= 8'hA6;
localparam TX_CRC_DELIMITER		= 8'hA7;
localparam TX_ACK_SLOT				= 8'hA8;
localparam TX_ACK_DELIMITER		= 8'hA9;
localparam TX_END_OF_FRAME			= 8'hAA;

reg[7:0] TX_STATE;
reg[7:0] NEXT_TX_STATE;
						
always @( posedge clk_can or posedge rst_i ) begin
	if ( rst_i ) begin
		TX_STATE             <= TX_IDLE;
		NEXT_TX_STATE 			<= TX_IDLE;
		crc_reg					<= 15'd0;
		bit_count_reg 			<= 8'd0;		
		count 					<= 7'd0;	
	   bit_pol_count 			<= 3'd1;
		bit_stuff_bit			<= 1'b0;
		last_bit					<= 1'b0;
	end else begin
		if ( CAN_STATE == CAN_TX ) begin
			if ( TX_STATE != TX_IDLE  ) begin
				last_bit 		<= tx_o;
				bit_count_reg  <= bit_count_reg + 1'b1;		
			end
			case ( TX_STATE )
			TX_IDLE: 			begin	
										count 			<= 3'd0;
										bit_count_reg 	<= 8'd0;
										crc_reg			<= 15'd0;
										if ( )
										TX_STATE			<= TX_START_OF_FRAME;								
									end																		
			// <MAC-level>
			
			// every 5 consequent same polarity bit add one reversed(not for CRC delimiter, ACK field and EOF)
			// 1 bit
			TX_BIT_STUFF: 		begin		
										TX_STATE 		<= NEXT_TX_STATE;	
									end				
			// 1 bit 
			TX_START_OF_FRAME:begin											
										TX_STATE 	  	<= TX_MESSAGE_TYPE;
										NEXT_TX_STATE 	<= TX_MESSAGE_TYPE;								
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
										end else begin
											count 			<= count + 1'b1;
										end		
									end
			// -- must be 1
			// 1 bit
			TX_CRC_DELIMITER:		begin
											TX_STATE 		<= TX_ACK_SLOT;
										end
			// -- Each node that receives the frame, without an error, transmits a 0 and thus overrides the 1 of the transmitter. 
			// If a transmitter detects a recessive level in the ACK slot, it knows that no receiver found a valid frame. 
			// A receiving node may transmit a recessive to indicate that it did not receive a valid frame, 
			// but another node that did receive a valid frame may override this with a dominant.
			// 1 bit
			TX_ACK_SLOT:			begin
											TX_STATE 		<= TX_ACK_DELIMITER;
										end
			// must be 1
			// 1 bit
			TX_ACK_DELIMITER:		begin
											TX_STATE 		<= TX_END_OF_FRAME;
										end
			// must bt all 1
			// 7 bits
			TX_END_OF_FRAME:		begin
											if ( count == 7'd6 ) begin
												count 			<= 7'd0;
												TX_STATE 		<= TX_IDLE;
											end else begin
												count 			<= count + 1'b1;
											end	
										end
										
			// </MAC-level>			
																							
			// <LLC-level>
			
			// -- Identificator
			
			// --- C/D
			// 1 bit
			TX_MESSAGE_TYPE:		begin
											TX_STATE 	  			<= TX_ADDRESS_LOCAL;
											NEXT_TX_STATE 			<= TX_ADDRESS_LOCAL;	
										end
			// --- Address local
			// 6 bit
			TX_ADDRESS_LOCAL:  	begin
											if ( count == 7'd5 ) begin
												count 				<= 7'd0;							
												TX_STATE 			<= TX_ADDRESS_REMOTE;
												NEXT_TX_STATE 		<= TX_ADDRESS_REMOTE;	
											end else begin													
												count 				<= count + 1'b1;	
											end
										end
			// --- Address remote
			// 6 bit						
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
			// --- Atribute
			
			// DataFrame: pointer?, CommandFrame: handshaking
			// 2 bit
			TX_HANDSHAKING_P:		begin
											if ( count == 7'd1 ) begin
												count					<= 7'd0;
												TX_STATE 			<= TX_RESERVED;
												NEXT_TX_STATE 		<= TX_RESERVED;	
											end else begin
												count 				<= count + 1'b1;
											end
										end
			// DataFrame: reserved 2'b00, CommandFrame: 2'b10
			// 2 bit
			TX_ATRIBUTE_RESERVED:begin
											if ( count == 7'd1 ) begin
												count					<= 7'd0;
												TX_STATE 			<= TX_EXPAND_COUNT;
												NEXT_TX_STATE 		<= TX_EXPAND_COUNT;	
											end else begin
												count 				<= count + 1'b1;
											end										
										end
			// DataFrame: frame count, CommandFrame: expand command field
			// 4 bit		
			TX_EXPAND_COUNT:		begin
											if ( count == 7'd3 ) begin
												count					<= 7'd0;
												TX_STATE 			<= TX_RTR;
												NEXT_TX_STATE 		<= TX_RTR;	
											end else begin
												count 				<= count + 1'b1;
											end
										end
			// --- Data/Command sign
			// DataFrame: type of data, CommandFrame: type of command
			// 8 bit
			TX_CMD_DATA_SIGN: 	begin
											if ( count == 7'd7 ) begin
												count					<= 7'd0;
												TX_STATE 			<= TX_RTR;
												NEXT_TX_STATE 		<= TX_RTR;	
											end else begin
												count 				<= count + 1'b1;
											end										
										end
			// -- DLC
			// 4 bit
			TX_DLC:					begin
											if ( count == 7'd3 ) begin
												count					<= 7'd0;
												TX_STATE 			<= TX_DATA;
												NEXT_TX_STATE 		<= TX_DATA;	
											end else begin
												count 				<= count + 1'b1;
											end											
										end
			
			// -- Data
			// 0 or 64 bit
			TX_DATA:					begin
											if ( count == 7'd63 ) begin
												count					<= 7'd0;
												TX_STATE 			<= TX_CRC;
												NEXT_TX_STATE 		<= TX_CRC;	
											end else begin
												count 				<= count + 1'b1;
											end		
										end
			// </LLC-level>
			endcase		
			// <CRC>
			if ( 	TX_STATE != TX_IDLE 				&&
					TX_STATE !=	TX_START_OF_FRAME &&
					TX_STATE != TX_BIT_STUFF 		&&
					TX_STATE !=	TX_CRC 				&&
					TX_STATE !=	TX_CRC_DELIMITER  &&
					TX_STATE !=	TX_ACK_SLOT 		&& 
					TX_STATE !=	TX_ACK_DELIMITER 	&& 
					TX_STATE !=	TX_END_OF_FRAME ) begin	
				if ( crc_next ) begin 
					crc_reg <= crc_tmp ^ 15'h4599;
				end else begin
					crc_reg <= crc_tmp;
				end				
			end
			// </CRC>		
			// <bit stuff check>
			if (  TX_STATE !=	TX_IDLE 				&& 
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
		end
	end
end

assign tx_o = TX_STATE == TX_START_OF_FRAME 		? 1'b0 									:												
				( TX_STATE == TX_MESSAGE_TYPE 		? tx_message_type 					:
				( TX_STATE == TX_ADDRESS_LOCAL 		? local_address[3'd5 - count] 	:	
				( TX_STATE == TX_ADDRESS_REMOTE 		? remote_address[3'd5 - count] 	:
				( TX_STATE == TX_SRR 					? 1'b1 									:
				( TX_STATE == TX_IDE 					? 1'b1 									:
				( TX_STATE == TX_HANDSHAKING_P 		?											:
				( TX_STATE == TX_ATRIBUTE_RESERVED 	?											:
				( TX_STATE == TX_EXPAND_COUNT 		?											:
				( TX_STATE == TX_CMD_DATA_SIGN 		?											:
				( TX_STATE == TX_RTR 					?											:
				( TX_STATE == TX_RESERVED 				?											:
				( TX_STATE == TX_DLC 					?											:
				( TX_STATE == TX_DATA 					?											:
				( TX_STATE == TX_CRC 					? crc_reg[7'd14 - count] : 1'b0  :
				( TX_STATE == TX_CRC_DELIMITER 		?											:
				( TX_STATE == TX_ACK_SLOT 				?											:
				( TX_STATE == TX_ACK_DELIMITER 		?											:
				( TX_STATE == TX_END_OF_FRAME 		?											:
				( TX_STATE == BIT_STUFF					?											:
				))))));
							
TX_STATE == TX_BIT_STUFF ? bit_stuff_bit

baud_rate baud_rate_gen
(
	.rst_i 		(rst_i),
	.clk_i 		(clk_i),
	.baud_clk_o (clk_can)
);
	

endmodule
