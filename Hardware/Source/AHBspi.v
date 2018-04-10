module AHBspi(
			// Bus signals
			input wire HCLK,				// bus clock
			input wire HRESETn,			// bus reset, active low
			input wire HSEL,				// selects this slave
			input wire HREADY,			// indicates previous transaction completing
			input wire [31:0] HADDR,	// address
			input wire [1:0] HTRANS,	// transaction type (only bit 1 used)
			input wire HWRITE,			// write transaction
//			input wire [2:0] HSIZE,		// transaction width ignored
			input wire [31:0] HWDATA,	// write data
			output wire [31:0] HRDATA,	// read data from slave
			output wire HREADYOUT,		// ready output from slave
			// SPI signals
			input MISO,				    //  
			output MOSI,				// 
			output SCLK,				// 
			output SSn                  //
			
    );

        // Registers to hold signals from address phase
        reg [1:0] rHADDR;            // only need two bits of address
        reg rWrite, rRead;    // write enable signals
    
        // Internal signals
        reg [7:0]    readData;        // 8-bit data from read multiplexer
        wire [7:0] rx_fifo_out, rx_fifo_in, tx_fifo_out;  // fifo data
        wire rx_fifo_empty, rx_fifo_full, tx_fifo_empty, tx_fifo_full;  // fifo output signals
        wire tx_fifo_wr = rWrite & (rHADDR == 2'h2);  // tx fifo write on write to address 0x4
        wire rx_fifo_rd = (rRead & (rHADDR == 2'h1) & ~rx_fifo_empty);  // rx fifo read on read to address 0x0
        wire txrdy;        // transmitter status signal
        wire txgo = ~tx_fifo_empty;    // transmitter control signal
        wire rxnew;        // receiver strobe output
    
         // Capture bus signals in address phase
        always @(posedge HCLK)
            if(!HRESETn)
                begin
                    rHADDR <= 2'b0;
                    rWrite <= 1'b0;
                    rRead  <= 1'b0;
                end
            else if(HREADY)
             begin
                rHADDR <= HADDR[3:2];         // capture address bits for for use in data phase
                rWrite <= HSEL & HWRITE & HTRANS[1];    // slave selected for write transfer       
                rRead <= HSEL & ~HWRITE & HTRANS[1];    // slave selected for read transfer 
             end
    
            
        // Status bits - can read in status register, can cause interrupts if enabled
        wire status = {~tx_ready & txgo};
        
            
        // Bus output signals
        always @(rx_fifo_out, tx_fifo_out, status, rHADDR)
            case (rHADDR)        // select on word address (stored from address phase)
                2'h0:        readData = {7'b0, status};    // status register    
                2'h1:        readData = rx_fifo_out;    // read from rx fifo - oldest received byte
                2'h2:        readData = tx_fifo_out;    // read of tx register gives oldest byte in queue    
                default:     readData = {8'b0};
            endcase
            
        assign HRDATA = {24'b0, readData};    // extend with 0 bits for bus read
    
    // Options on ready signal - can wait on write when full, or read when empty 
        assign HREADYOUT = 1'b1;    // always ready - transaction never delayed
    //    assign HREADYOUT = ~((tx_fifo_wr & tx_fifo_full) | (rx_fifo_rd & rx_fifo_empty));
        
    // ========================= FIFOs ===================================================
          //Transmitter FIFO
          FIFO  #(.DWIDTH(8), .AWIDTH(4))
            uFIFO_TX (
            .clk(HCLK),
            .resetn(HRESETn),
            .rd(tx_ready & txgo),        // same signal that loads data register in transmitter
            .wr(tx_fifo_wr),
            .w_data(HWDATA[7:0]),
            .empty(tx_fifo_empty),
            .full(tx_fifo_full),
            .r_data(tx_fifo_out)
          );
          
          //Receiver FIFO
          FIFO  #(.DWIDTH(8), .AWIDTH(4))
            uFIFO_RX (
            .clk(HCLK),
            .resetn(HRESETn),
            .rd(rx_fifo_rd),
            .wr(rx_new),
            .w_data(rx_fifo_in),
            .empty(rx_fifo_empty),
            .full(rx_fifo_full),
            .r_data(rx_fifo_out)
          );
    
    // ========================= SPI ===================================================
    // Spi module
    SPI    rSPI (
              .clk         (HCLK),
              .rst         (~HRESETn),
              .txdin       (tx_fifo_out),
              .txgo        (~tx_fifo_empty),
              .txrdy       (tx_ready),
              .rxdout      (rx_fifo_in),
              .rxnew       (rx_new),
              .MISO        (MISO),               // serial receive, idles at 1
              .MOSI        (MOSI),               // serial transmit, idles at 1
              .SCLK        (SCLK),               // interrupt request
              .SSn         (SSn) 
            );
    


    
endmodule
    