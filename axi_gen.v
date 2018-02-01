`timescale 1ns/1ps
module axi_gen #(
    parameter integer ADDR_WIDTH     =   32,
    parameter integer DATA_WIDTH     =   64,
    parameter         ADDR_START     =   32'h0,
    parameter         DATA_START     =   64'h00000000_00000000,
    parameter         BURST_TYPE     =   1,   //0 for fix, 1 for INCR, 2 for WRAP
    parameter         BURST_LEN      =   4,
    parameter integer BURST_SIZE     =   8,
    parameter         DATA_STEP      =   64'h4
    ) (
    input                                                       ACLK,
    input                                                       HRESETn,
    output reg  [ADDR_WIDTH-1 : 0]                              AWADDR,
    output      [7:0]                                           AWLEN,
    output      [2:0]                                           AWSIZE,
    output      [1:0]                                           AWBURST,
    output reg                                                  AWVALID,
    input                                                       AWREADY,

    output reg                                                  WLAST,
    output reg [DATA_WIDTH-1 : 0]                               WDATA,
    output reg [(DATA_WIDTH/8)-1:0]                             WSTRB,
    output reg                                                  WVALID,
    input                                                       WREADY,

    input      [1:0]                                            BRESP,
    input                                                       BVALID,
    output reg                                                  BREADY,

    output reg [ADDR_WIDTH-1 : 0]                               ARADDR,
    output     [7:0]                                            ARLEN,
    output     [2:0]                                            ARSIZE,
    output     [1:0]                                            ARBURST,
    output reg                                                  ARVALID,
    input                                                       ARREADY,

    input                                                       RLAST,
    input      [DATA_WIDTH-1 : 0]                               RDATA,
    input      [1:0]                                            RRESP,
    input                                                       RVALID,
    output reg                                                  RREADY
  );

reg read_write_process; //control for write and read transaction
                        // 1 for read, 0 for write

localparam  FIXED    =  2'b00,
            INCR     =  2'b01,
      WRAP     =  2'b10;
localparam ADDR_STEP = (DATA_WIDTH == 32) ? 8'h10: ((DATA_WIDTH == 64) ? 8'h20 : 8'h00);
//-----------------------------------------------------------------------------
// WRITE CHANNEL
//-----------------------------------------------------------------------------
assign AWBURST = (BURST_TYPE == 0) ? FIXED : (
                 (BURST_TYPE == 1) ? INCR : (
                 (BURST_TYPE == 2) ? WRAP : FIXED));

assign AWLEN  =  (BURST_LEN == 1)   ?  4'b0000 :  (
                 (BURST_LEN == 2)   ?  4'b0001 :  (
                 (BURST_LEN == 3)   ?  4'b0010 :  (
                 (BURST_LEN == 4)   ?  4'b0011 :  (
                 (BURST_LEN == 5)   ?  4'b0100 :  (
                 (BURST_LEN == 6)   ?  4'b0101 :  (
                 (BURST_LEN == 7)   ?  4'b0110 :  (
                 (BURST_LEN == 8)   ?  4'b0111 :  (
                 (BURST_LEN == 9)   ?  4'b1000 :  (
                 (BURST_LEN ==10)   ?  4'b1001 :  (
                 (BURST_LEN ==11)   ?  4'b1010 :  (
                 (BURST_LEN ==12)   ?  4'b1011 :  (
                 (BURST_LEN ==13)   ?  4'b1100 :  (
                 (BURST_LEN ==14)   ?  4'b1101 :  (
                 (BURST_LEN ==15)   ?  4'b1110 :  (
                 (BURST_LEN ==16)   ?  4'b1111 :  4'b0000
                 )))))))))))))));

assign AWSIZE  = (BURST_SIZE == 1)   ?  3'b000 : (
                 (BURST_SIZE == 2)   ?  3'b001 : (
                 (BURST_SIZE == 4)   ?  3'b010 : (
                 (BURST_SIZE == 8)   ?  3'b011 : (
                 (BURST_SIZE == 16)  ?  3'b100 : (
                 (BURST_SIZE == 32)  ?  3'b101 : (
                 (BURST_SIZE == 64)  ?  3'b110 : (
                 (BURST_SIZE == 128) ?  3'b111 : 3'b100)))))));

localparam  WR_IDLE      =  3'b000,
            WR_ADDR      =  3'b001,
            WR_DATA      =  3'b010,
            WR_RESP      =  3'b011,
            WR_FINISH    =  3'b100,
            WR_STOP      =  3'b101;

reg [2:0]  wr_state, wr_state_n;
reg [3:0]  wr_cnt;

always @(posedge ACLK or negedge HRESETn) begin
  if(!HRESETn)
    wr_state <= WR_IDLE;
  else
    wr_state <= wr_state_n;
end

always @ (*) begin
  case(wr_state)
    WR_IDLE: begin
      if(~read_write_process)
        wr_state_n = WR_ADDR;
      else
        wr_state_n = WR_IDLE;
    end 

    WR_ADDR: begin
      if(WVALID & WREADY & WLAST)
        wr_state_n = WR_RESP;
      else if(AWVALID & AWREADY)
        wr_state_n = WR_DATA;
      else
        wr_state_n = WR_ADDR;
    end

    WR_DATA: begin
      if(WVALID & WREADY & WLAST)
        wr_state_n = WR_RESP;
      else
        wr_state_n = WR_DATA;
    end
    
    WR_RESP: begin
      if(BVALID & BREADY & (!BRESP[1]))
        wr_state_n = WR_FINISH;
      else
        wr_state_n = WR_RESP;
    end

    WR_FINISH: begin
      wr_state_n = WR_STOP;
    end

    WR_STOP: begin
      if(~read_write_process)
        wr_state_n = WR_ADDR;
      else
        wr_state_n = WR_STOP;
    end

    default: wr_state_n = WR_IDLE;
  endcase
end

always @ (posedge ACLK or negedge HRESETn) begin
  if(!HRESETn) begin
    AWADDR       <=   ADDR_START;
    AWVALID      <=   1'b0;
    WDATA        <=   DATA_START;
    WSTRB        <=   {(DATA_WIDTH/8){1'b0}};
    WVALID       <=   1'b0;
    BREADY       <=   1'b0;
    WLAST        <=   1'b0;
  end
  else begin
    case(wr_state)
      WR_IDLE: begin
        AWADDR       <=   ADDR_START;
        AWVALID      <=   1'b0;
        WDATA        <=   DATA_START;
        WSTRB        <=   {(DATA_WIDTH/8){1'b0}};
        WVALID       <=   1'b0;
        BREADY       <=   1'b0;
        WLAST        <=   1'b0;
      end

      WR_ADDR: begin
        WSTRB        <=  {(DATA_WIDTH/8){1'b1}};
        if(WREADY & WVALID)
          WVALID     <= 1'b0;
        else
          WVALID     <= 1'b1;

        if(WVALID & WREADY)
          WDATA      <= WDATA + DATA_STEP;

        if(WVALID & WREADY & WLAST)
          WLAST      <= 1'b0;
        else if(wr_cnt == AWLEN)
          WLAST      <= 1'b1;
        else
          WLAST      <= 1'b0;

        if(AWREADY & AWVALID)
          AWVALID    <= 1'b0;
        else
          AWVALID    <= 1'b1;
      end

      WR_DATA: begin
        if(WREADY & WVALID)
          WVALID     <= 1'b0;
        else
          WVALID     <= 1'b1;
      
        if(WVALID & WREADY)
          WDATA      <= WDATA + DATA_STEP;
      
        if(WVALID & WREADY & WLAST)
          WLAST      <= 1'b0;
        else if(wr_cnt == AWLEN)
          WLAST      <= 1'b1;
        else
          WLAST      <= 1'b0;
      end

      WR_RESP: begin
        AWVALID      <= 1'b0;
        WVALID       <= 1'b0;
        WLAST        <= 1'b0;
      
        if(BVALID & BREADY)
          BREADY     <= 1'b0;
        else if(BVALID)
          BREADY     <= 1'b1;
            
      end

      WR_FINISH: begin
        AWADDR       <= AWADDR + ADDR_STEP;
        AWVALID      <= 1'b0;
        WVALID       <= 1'b0;
        WLAST        <= 1'b0;
        BREADY       <= 1'b0;
        WSTRB        <= {(DATA_WIDTH/8){1'b0}};
      end

      WR_STOP: begin
        AWVALID      <= 1'b0;
        WVALID       <= 1'b0;
        WLAST        <= 1'b0;
        BREADY       <= 1'b0;
        WSTRB        <= {(DATA_WIDTH/8){1'b0}};
      end

      default: begin
        AWADDR       <=   ADDR_START;
        AWVALID      <=   1'b0;
        WDATA        <=   DATA_START;
        WSTRB        <=   {(DATA_WIDTH/8){1'b0}};
        WVALID       <=   1'b0;
        BREADY       <=   1'b0;
        WLAST        <=   1'b0;      
      end
    endcase
  end
end


always @ (posedge ACLK or negedge HRESETn) begin
  if(!HRESETn)
    wr_cnt <= 4'h0;
  else if((wr_state == WR_DATA) | (wr_state == WR_ADDR)) begin
    if(WVALID & WREADY)
      wr_cnt <= wr_cnt + 1'b1;
  end
  else
    wr_cnt <= 4'h0;
end



//-----------------------------------------------------------------------------
// READ CHANNEL
//-----------------------------------------------------------------------------
assign ARBURST = (BURST_TYPE == 0) ? FIXED : (
                 (BURST_TYPE == 1) ? INCR : (
                 (BURST_TYPE == 2) ? WRAP : FIXED));

assign ARLEN  =  (BURST_LEN == 1)   ?  4'b0000 :  (
                 (BURST_LEN == 2)   ?  4'b0001 :  (
                 (BURST_LEN == 3)   ?  4'b0010 :  (
                 (BURST_LEN == 4)   ?  4'b0011 :  (
                 (BURST_LEN == 5)   ?  4'b0100 :  (
                 (BURST_LEN == 6)   ?  4'b0101 :  (
                 (BURST_LEN == 7)   ?  4'b0110 :  (
                 (BURST_LEN == 8)   ?  4'b0111 :  (
                 (BURST_LEN == 9)   ?  4'b1000 :  (
                 (BURST_LEN ==10)   ?  4'b1001 :  (
                 (BURST_LEN ==11)   ?  4'b1010 :  (
                 (BURST_LEN ==12)   ?  4'b1011 :  (
                 (BURST_LEN ==13)   ?  4'b1100 :  (
                 (BURST_LEN ==14)   ?  4'b1101 :  (
                 (BURST_LEN ==15)   ?  4'b1110 :  (
                 (BURST_LEN ==16)   ?  4'b1111 :  4'b0000
                 )))))))))))))));

assign ARSIZE  = (BURST_SIZE == 1)   ?  3'b000 : (
                 (BURST_SIZE == 2)   ?  3'b001 : (
                 (BURST_SIZE == 4)   ?  3'b010 : (
                 (BURST_SIZE == 8)   ?  3'b011 : (
                 (BURST_SIZE == 16)  ?  3'b100 : (
                 (BURST_SIZE == 32)  ?  3'b101 : (
                 (BURST_SIZE == 64)  ?  3'b110 : (
                 (BURST_SIZE == 128) ?  3'b111 : 3'b100)))))));

localparam   RD_IDLE   = 3'b000,
             RD_ADDR   = 3'b001,
             RD_DATA   = 3'b010,
             RD_FINISH = 3'b011,
             RD_STOP   = 3'b100;

reg [2:0]  rd_state, rd_state_n;

always @(posedge ACLK or negedge HRESETn) begin
  if(!HRESETn)
    rd_state <= RD_IDLE;
  else
    rd_state <= rd_state_n;
end

always @ (*) begin
  case (rd_state)
    RD_IDLE: begin
      if(read_write_process)
        rd_state_n = RD_ADDR;
      else
        rd_state_n = RD_IDLE;
    end

    RD_ADDR: begin
      if(ARVALID & ARREADY)
        rd_state_n = RD_DATA;
      else
        rd_state_n = RD_ADDR;
    end

    RD_DATA: begin
      if(RVALID & RREADY & RLAST)
        rd_state_n = RD_FINISH;
      else
        rd_state_n =RD_DATA;
    end

    RD_FINISH:
      rd_state_n = RD_STOP;

    RD_STOP:begin
      if(read_write_process)
        rd_state_n = RD_ADDR;
      else
        rd_state_n = RD_STOP;
    end

    default: rd_state_n = RD_IDLE;
  endcase
end

always @(posedge ACLK or negedge HRESETn) begin
  if(!HRESETn) begin
    ARADDR   <= ADDR_START;
    ARVALID  <= 1'b0;
    RREADY   <= 1'b0;
  end

  else begin
    case (rd_state)
      RD_IDLE: begin
        ARADDR   <= ADDR_START;
        ARVALID  <= 1'b0;
        RREADY   <= 1'b0;
      end
     
      RD_ADDR: begin
        if(ARREADY & ARVALID)
          ARVALID <= 1'b0;
        else
          ARVALID <= 1'b1;
      end

      RD_DATA: begin
        if(RVALID & RREADY)
          RREADY <= 1'b0;
        else
          RREADY <= 1'b1;
      end

      RD_FINISH: begin
        ARADDR  <= ARADDR + ADDR_STEP;
        ARVALID <= 1'b0;
        RREADY  <= 1'b0;
      end

      RD_STOP: begin
        ARVALID  <= 1'b0;
        RREADY   <= 1'b0;
      end

      default: begin
        ARADDR  <= ADDR_START;
        ARVALID <= 1'b0;
        RREADY  <= 1'b0;
      end
    endcase
  end
end


always @(posedge ACLK or negedge HRESETn) begin
  if(!HRESETn)
    read_write_process <= 1'b0;  //write first
  else begin
    if((BVALID & BREADY) | (RVALID & RREADY & RLAST)) begin
      read_write_process <= ~read_write_process;
    end
  end
end

endmodule
