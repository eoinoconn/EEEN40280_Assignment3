`timescale 1ns / 1ps

module spi(
    input clk,						// main clock, drives all logic
    input rst,						// asynchronous reset
    input [7:0] txdin,			// 8-bit data to be transmitted
    input txgo,					// indicates new data to send, ignored if not ready
    output reg txd,				// serial data out (idle at logic 1, high)
    output txrdy,					// transmitter ready for new data
    input rxd,						// serial data in (idle at logic 1, high)
    output reg [7:0] rxdout,	// 8-bit received data
    output rxnew					// indicates new data available, asserted for 1 clock
    );
    
   