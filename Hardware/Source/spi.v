`timescale 1ns / 1ps

module SPI(
    input wire clk,						// main clock, drives all logic
    input wire rst,						// asynchronous reset
    input wire [7:0] txdin,				// 8-bit data to be transmitted
    input wire txgo,					// indicates new data to send, ignored if not ready
    output reg MOSI,					// data out (idle at logic 1, high)
    output wire SCLK,					// SPI clock
    output wire txrdy,						// transmitter ready for new data
    input MISO,							// data in (idle at logic 1, high)
    output reg [7:0] rxdout				// 8-bit received data
 );
    
    ////////////////////////////////////////////////////////
    // SCLK counter
    ////////////////////////////////////////////////////////
    reg [7:0] count;
    wire [7:0] next_count = count - 8'd1;
    
    always @(posedge clk)
        if (rst)
            count <= 8'd0;
        else if (txgo)
            count <= 8'd134;
        else if (count != 8'd0)
            count <= next_count;


    assign SCLK = (count[3]);
    
	
    ////////////////////////////////////////////////////////
    // input data capture
    ////////////////////////////////////////////////////////
    reg [7:0] datareg;
    
    always @(posedge clk)
        if (rst)
            datareg <= 8'b0;
        else if (txgo & txrdy)
            datareg <= txdin;
          

    ////////////////////////////////////////////////////////
    // MOSI control
    ////////////////////////////////////////////////////////
    reg [3:0] bitcount;
    wire [3:0] bitcount_decrement = bitcount - 4'b1;
    assign txrdy = (bitcount == 4'b0);
    
    
    always @(posedge clk)
        if (rst)
            bitcount <= 4'b0;
        else if (txgo & txrdy)
            bitcount <= 4'd8;
        else if (count[3:0] == 4'd8)
            bitcount <= bitcount_decrement;
    
    always @(bitcount, datareg)
        case(bitcount)		
            4'd8:        MOSI = datareg[7];    
            4'd7:        MOSI = datareg[6];
            4'd6:        MOSI = datareg[5];
            4'd5:        MOSI = datareg[4];
            4'd4:        MOSI = datareg[3];
            4'd3:        MOSI = datareg[2];
            4'd2:        MOSI = datareg[1];
            4'd1:        MOSI = datareg[0];    
            4'd0:        MOSI = 1'b0;            
            default:     MOSI = 1'b0;
         endcase

    ////////////////////////////////////////////////////////
    // MIS0 control
    ////////////////////////////////////////////////////////
    always @ (posedge clk)
        if (rst) 
            rxdout <= 8'b0;                // reset to zero
        else if(count[3:0] == 4'd8)                                   // on sampling pulse 
            rxdout <= {rxdout[6:0], MISO};     // shift right...
        
    
   endmodule
   