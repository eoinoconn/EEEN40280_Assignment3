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
			output SS1                  //
			
    );

        // Registers to hold signals from address phase
        reg [1:0] rHADDR;            // only need two bits of address
        reg rWrite, rRead;    // write enable signals
    
        // Internal signals
        reg [7:0]    readData;        // 8-bit data from read multiplexer
        wire [7:0] rx_fifo_out, rx_fifo_in, tx_fifo_out;  // fifo data
        wire rx_fifo_empty, rx_fifo_full, tx_fifo_empty, tx_fifo_full;  // fifo output signals
        wire tx_fifo_wr = rWrite & (rHADDR == 2'h1);  // tx fifo write on write to address 0x4
        wire rx_fifo_rd = rRead & (rHADDR == 2'h0);  // rx fifo read on read to address 0x0
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
    
        // Control register
        reg [3:0] control;    // holds interrupt enable bits
        always @(posedge HCLK)
            if (!HRESETn) control <= 4'b0;
            else if (rWrite && (rHADDR == 2'h3)) control <= HWDATA[3:0];
            
        // Status bits - can read in status register, can cause interrupts if enabled
        wire [3:0] status = {~rx_fifo_empty, rx_fifo_full, tx_fifo_empty, tx_fifo_full};
        
        // Interrupt signal - AND each status bit with enable bit, then OR all the results
        assign uart_IRQ = |(status & control);
            
        // Bus output signals
        always @(rx_fifo_out, tx_fifo_out, status, control, rHADDR)
            case (rHADDR)        // select on word address (stored from address phase)
                2'h0:        readData = rx_fifo_out;    // read from rx fifo - oldest received byte
                2'h1:        readData = tx_fifo_out;    // read of tx register gives oldest byte in queue
                2'h2:        readData = {4'b0, status};    // status register        
                2'h3:        readData = {4'b0, control};    // read back of control register
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
            .rd(txrdy & txgo),        // same signal that loads data register in transmitter
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
            .rd(rx_fifo_rd & ~rx_fifo_empty),
            .wr(rxnew),
            .w_data(rx_fifo_in),
            .empty(rx_fifo_empty),
            .full(rx_fifo_full),
            .r_data(rx_fifo_out)
          );
    
    // ========================= SPI ===================================================
    // Spi module
    rSPI    SPI (
              .clk         (HCLK),
              .rst         (~HRESETn),
              .MISO        (SpiRx),               // serial receive, idles at 1
              .MOSI        (SpiTx),               // serial transmit, idles at 1
              .SCLK        (SpiClk),               // interrupt request
              .SS1         (AccS) 
            );
    


    
endmodule
    