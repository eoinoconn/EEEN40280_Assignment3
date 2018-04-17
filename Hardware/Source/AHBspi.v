`timescale 1ns / 1ps
module AHBspi(
			// Bus signals
			input wire HCLK,			// bus clock
			input wire HRESETn,			// bus reset, active low
			input wire HSEL,			// selects this slave
			input wire HREADY,			// indicates previous transaction completing
			input wire [31:0] HADDR,	// address
			input wire [1:0] HTRANS,	// transaction type (only bit 1 used)
			input wire HWRITE,			// write transaction
//			input wire [2:0] HSIZE,		// transaction width ignored
			input wire [31:0] HWDATA,	// write data
			output wire [31:0] HRDATA,	// read data from slave
			output wire HREADYOUT,		// ready output from slave
			// SPI signals
			input MISO,				    // Data input from slave  
			output MOSI,				// Data output from this block
			output SCLK,				// SPI CLK from this module
			output SSn                  // Accelerometer slave select
			
    );

        // Registers to hold signals from address phase
        reg [1:0] rHADDR;     // only need two bits of address
        reg rWrite, rRead;    // write enable signals
        reg [7:0] control;
    
    
    
        // Internal signals
        reg [7:0]    readData;        				// 8-bit data from read multiplexer
        wire tx_wr = rWrite & (rHADDR == 2'h2);  	// Idicates new transmit message has been received
        wire txrdy;        							// transmitter status signal
		wire [7:0] rxdout;							// Receveid message signal
    
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
                rHADDR <= HADDR[3:2];         			// capture address bits for for use in data phase
                rWrite <= HSEL & HWRITE & HTRANS[1];    // slave selected for write transfer       
                rRead <= HSEL & ~HWRITE & HTRANS[1];    // slave selected for read transfer 
             end
    
        always @(posedge HCLK)
            if (!HRESETn) control = 8'b0;
            else if (rWrite & (rHADDR == 2'b11))
                control = HWDATA[7:0];
        
        assign SSn = ~control[0];
        
        // Status bit - indicates the master is ready for another transmit message
        wire status = ~tx_ready;
        
            
        // Bus output signals
        always @(rxdout, status, rHADDR)
            case (rHADDR)        							// select on word address (stored from address phase)
                2'h0:        readData = {7'b0, status};    	// status register    
                2'h1:        readData = rxdout;    			// read from rx fifo - oldest received byte
                2'b11:       readData = control;
                default:     readData = {8'b0};
            endcase
            
        assign HRDATA = {24'b0, readData};    				// extend with 0 bits for bus read
     
        assign HREADYOUT = 1'b1;    // always ready - transaction never delayed
        

    // ========================= SPI ===================================================
    
    // Spi module
    SPI    rSPI (
              .clk         (HCLK),					// clk
              .rst         (~HRESETn),				// reset
              .txdin       (HWDATA[7:0]),			// transmit byte
              .txgo        (tx_wr),					// new message to trasnmit
              .txrdy       (tx_ready),				// ready for next transmission
              .rxdout      (rxdout),				// Received message buffer
              .MISO        (MISO),              	// serial receive, idles at 1
              .MOSI        (MOSI),               	// serial transmit, idles at 1
              .SCLK        (SCLK)               	// interrupt request
            );
    
endmodule