`timescale 1ns / 1ps

module SPI(
    input wire clk,						// main clock, drives all logic
    input wire rst,						// asynchronous reset
    input wire [7:0] txdin,			// 8-bit data to be transmitted
    input wire txgo,					// indicates new data to send, ignored if not ready
    output reg MOSI,				// serial data out (idle at logic 1, high)
    output wire SSn,
    output wire SCLK,
    output txrdy,					// transmitter ready for new data
    input MISO,						// serial data in (idle at logic 1, high)
    output reg [7:0] rxdout	// 8-bit received data
    //output wire rxnew					// indicates new data available, asserted for 1 clock
 );
    
    ////////////////////////////////////////////////////////
    // SCLK counter
    ////////////////////////////////////////////////////////
    reg [3:0] count;
    wire [3:0] next_count = count + 4'b1;
    
    always @(posedge clk or posedge rst)
        if (rst)
            count <= 4'b0;
        else if (bitcount == 4'b0)
            count <= 4'b0;
        else
            count <= next_count;
            
    assign SCLK = (count[3]);
    
//    always @(posedge clk or posedge rst)
//        if (rst)
//            SCLK <= 1'b0;
//        else if (txrdy)
//            SCLK <= 1'b0;
//        else if (flip_SCLK)
//            SCLK <= ~SCLK;
    
    ////////////////////////////////////////////////////////
    // SSn controller
    ////////////////////////////////////////////////////////

    assign SSn = (bitcount == 4'b0);
    
    ////////////////////////////////////////////////////////
    // input data capture
    ////////////////////////////////////////////////////////
    reg [7:0] datareg;
    
    always @(posedge clk or posedge rst)
        if (rst)
            datareg <= 8'b0;
        else if (txgo & txrdy)
            datareg <= txdin;
          

    ////////////////////////////////////////////////////////
    // MOSI control
    ////////////////////////////////////////////////////////
    reg [3:0] bitcount;
    reg [3:0] bitcount_decrement;
    assign txrdy = (bitcount == 4'b0);
    
    always@(posedge SCLK)
        bitcount_decrement = bitcount - 4'b1; 
    
    always @(posedge clk or posedge rst)
        if (rst)
            bitcount <= 4'b0;
        else if (txgo & txrdy)
            bitcount <= 4'd9;
        else if (count == 4'd8)
            bitcount <= bitcount_decrement;
    
    always @(bitcount, datareg)
        case(bitcount)		
            4'd8:        MOSI = datareg[0];    
            4'd7:        MOSI = datareg[1];
            4'd6:        MOSI = datareg[2];
            4'd5:        MOSI = datareg[3];
            4'd4:        MOSI = datareg[4];
            4'd3:        MOSI = datareg[5];
            4'd2:        MOSI = datareg[6];
            4'd1:        MOSI = datareg[7];    
            4'd0:        MOSI = 1'b0;            
            default:     MOSI = 1'b0;
         endcase

    ////////////////////////////////////////////////////////
    // MIS0 control
    //////////////////////////////////////////////////////// 
    
    always @ (posedge SCLK or posedge rst)
        if (rst) rxdout <= 8'b0;                // reset to zero
        else                                      // on sampling pulse 
            rxdout <= {MISO, rxdout[7:1]};     // shift right...
        
//    wire non_zero = ~(rxdout == 8'b0);
//    reg [3:0] rx_bit_count;
//    wire [3:0] next_rx_bit_count = rx_bit_count + 4'b1;
    
//    always @ (posedge SCLK or posedge rst)
//        if (rst) rx_bit_count <= 4'b0;            // reset to zero
//        else                                      // on sampling pulse 
//            rx_bit_count <= next_rx_bit_count;     // shift right...
    
//    assign rxnew = (non_zero & (rx_bit_count == 4'd8));
    
   endmodule
   