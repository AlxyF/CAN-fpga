module PMRAMIF
#(
    parameter DATA_WIDTH        = 32,
    parameter ADDR_WIDTH        = 20,
    parameter CLK_FREQUENCY     = 200_000_000,
    parameter OP_CYCLE_NS       = 35
)(
    input                          clk,
    input                          rst,

    input       [DATA_WIDTH-1 : 0] data_wr,
    input       [ADDR_WIDTH-1 : 0] addr_wr,
    input                          wr_en,
    output reg                     wr_done,
    output reg                     wr_busy,

    output reg  [DATA_WIDTH-1 : 0] data_rd,
    input       [ADDR_WIDTH-1 : 0] addr_rd,
    input                          rd_en,
    output reg                     rd_done,
    output reg                     rd_busy,
     
     
    inout       [DATA_WIDTH-1 : 0] mram_data,
    output reg  [ADDR_WIDTH-1 : 0] mram_addr,
    output reg                     mram_ng,
    output reg                     mram_nw,
    output reg                     mram_nce
);

function integer clog2;
input integer value;
    begin
        value = value-1;
        for ( clog2 = 0; value > 0; clog2 = clog2+1 ) begin
            value = value >> 1;
        end
    end
endfunction




localparam CLK_PERIOD_NS         = 1_000_000_000 / CLK_FREQUENCY;
localparam OP_CLK_CYCLES         = (OP_CYCLE_NS + CLK_PERIOD_NS - 1) / CLK_PERIOD_NS;
localparam OP_COUNTER_WIDTH      = clog2(OP_CLK_CYCLES + 1);




wire op_done;
wire begin_op;




reg [DATA_WIDTH-1 : 0]       data_wr_reg;
reg [ADDR_WIDTH-1 : 0]       addr_wr_reg;
reg [ADDR_WIDTH-1 : 0]       addr_rd_reg;

reg [OP_COUNTER_WIDTH-1 : 0] op_counter    = 0;
reg                          op_counter_en = 1'b0;




assign mram_data = mram_nw ? { DATA_WIDTH {1'bz} } : data_wr_reg;

assign op_done   = (op_counter == OP_CLK_CYCLES);
assign begin_op  = (op_counter == 0);




    always @( posedge clk ) begin
        if ( op_counter_en ) begin
            if ( op_counter < OP_CLK_CYCLES ) begin
                op_counter <= op_counter + 1'b1;
            end else begin
                op_counter <= 0;
            end
        end else begin
            op_counter <= 0;
        end
    end

    always @( posedge clk ) begin
        case (STATE)
         IDLE :         begin
                            mram_nce      <= 1'b1;
                            mram_nw       <= 1'b1;
                            mram_ng       <= 1'b1;
                        end
        
        MRAM_WRITE :    begin
                            if ( begin_op ) begin
                                mram_addr <= addr_wr_reg;

                                mram_nce  <= 1'b0;
                                mram_ng   <= 1'b1;
                                mram_nw   <= 1'b0;                    
                            end else begin
                                if ( op_done ) begin
                                    mram_ng <= 1'b1;
                                    mram_nw <= 1'b1;
                                end
                            end
                        end

        MRAM_READ :     begin
                            if ( begin_op ) begin
                                mram_addr <= addr_rd_reg;

                                mram_nce  <= 1'b0;
                                mram_ng   <= 1'b0;
                                mram_nw   <= 1'b1;                    
                            end else begin
                                if ( op_done ) begin
                                    mram_nce  <= 1'b1;
                                    mram_ng   <= 1'b1;
                                end
                            end
                        end
        default:        begin
                            mram_nce <= 1'b1;
                            mram_nw <= 1'b1;
                            mram_ng <= 1'b1;
                        end
        endcase
    end






    localparam IDLE = 0;
    localparam MRAM_WRITE = 1;
    localparam MRAM_READ  = 2;

    reg [1:0] STATE;

    always @( posedge clk ) begin
        if ( rst ) begin
            STATE <= IDLE;
        end else begin
            case (STATE)
                IDLE :          begin
                                    if ( wr_en ) begin
                                        data_wr_reg   <= data_wr;
                                        addr_wr_reg   <= addr_wr;                                    
                                        wr_busy       <= 1'b1;

                                        op_counter_en <= 1'b1;
                                        STATE         <= MRAM_WRITE;                                    
                                    end else begin
                                        if ( rd_en ) begin              
                                            addr_rd_reg   <= addr_rd;                                        
                                            rd_busy       <= 1'b1;

                                            op_counter_en <= 1'b1;
                                            STATE         <= MRAM_READ;                                                                                
                                        end else begin
                                            wr_done       <= 1'b0;
                                            rd_done       <= 1'b0;
                                            op_counter_en <= 1'b0;
                                            wr_busy       <= 1'b0;
                                            rd_busy       <= 1'b0;
                                            data_wr_reg   <= 0;
                                            addr_wr_reg    <= 0;
                                            addr_rd_reg   <= 0;
                                        end
                                    end
                                end

                MRAM_WRITE:     begin
                                    if ( op_done ) begin                                    
                                        wr_done       <= 1'b1;
                                        wr_busy       <= 1'b0;

                                        op_counter_en <= 1'b0;
                                        if ( rd_en ) begin
                                            addr_rd_reg   <= addr_rd;                                        
                                            rd_busy       <= 1'b1;

                                            op_counter_en <= 1'b1;
                                            STATE         <= MRAM_READ;
                                        end else begin
                                            STATE <= IDLE;
                                        end
                                    end
                                    rd_done <= 1'b0;
                                end

                MRAM_READ:      begin
                                    if ( op_done ) begin
                                        rd_done       <= 1'b1;
                                        rd_busy       <= 1'b0;
                                        data_rd       <= mram_data;
                                        
                                        op_counter_en <= 1'b0;
                                        if ( wr_en ) begin
                                            data_wr_reg   <= data_wr;
                                            addr_wr_reg   <= addr_wr;                                        
                                            wr_busy       <= 1'b1;

                                            op_counter_en <= 1'b1;
                                            STATE         <= MRAM_WRITE;
                                        end else begin
                                            STATE <= IDLE;
                                        end
                                    end
                                    wr_done <= 1'b0;
                                end
                default:        begin                                
                                    STATE <= IDLE;
                                end
            endcase
        end
    end




endmodule

