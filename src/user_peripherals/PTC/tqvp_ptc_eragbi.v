/*
 * Copyright (c) 2025 Eraz
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none


//`include "user_peripherals/ptc_defines.v"

module tqvp_ptc_eragbi (
    input         clk,          // Clock - the TinyQV project clock is normally set to 64MHz.
    input         rst_n,        // Reset_n - low to reset.

    input  [7:0]  ui_in,        // The input PMOD, always available.  Note that ui_in[7] is normally used for UART RX.
                                // The inputs are synchronized to the clock; note this will introduce 2 cycles of delay on the inputs.

    output [7:0]  uo_out,       // The output PMOD.  Each wire is only connected if this peripheral is selected.
                                // Note that uo_out[0] is normally used for UART TX.

    input [5:0]   address,      // Address within this peripheral's address space
    input [31:0]  data_in,      // Data in to the peripheral, bottom 8, 16, or all 32 bits are valid on write.

    // Data read and write requests from the TinyQV core.
    input [1:0]   data_write_n, // 11 = no write, 00 = 8-bits, 01 = 16-bits, 10 = 32-bits
    input [1:0]   data_read_n,  // 11 = no read,  00 = 8-bits, 01 = 16-bits, 10 = 32-bits
    
    output [31:0] data_out,     // Data out from the peripheral, bottom 8, 16, or all 32 bits are valid on read when data_ready is high.
    output        data_ready,

    output        user_interrupt  // Dedicated interrupt request for this peripheral
);



parameter dw = 32;                     //Data Width
parameter aw = `PTC_ADDRHH+1;          //Address Width  
parameter cw = `PTC_CW;                //counter width


`ifdef PTC_IMPLEMENTED

//
// PTC Main Counter Register (or no register)
//
`ifdef PTC_RPTC_CNTR
reg	[cw-1:0]	rptc_cntr;	// RPTC_CNTR register
`else
wire	[cw-1:0]	rptc_cntr;	// No RPTC_CNTR register
`endif

//
// PTC HI Reference/Capture Register (or no register)
//
`ifdef PTC_RPTC_HRC
reg	[cw-1:0]	rptc_hrc;	// RPTC_HRC register
`else
wire	[cw-1:0]	rptc_hrc;	// No RPTC_HRC register
`endif

//
// PTC LO Reference/Capture Register (or no register)
//
`ifdef PTC_RPTC_LRC
reg	[cw-1:0]	rptc_lrc;	// RPTC_LRC register
`else
wire	[cw-1:0]	rptc_lrc;	// No RPTC_LRC register
`endif

//
// PTC Control Register (or no register)
//
`ifdef PTC_RPTC_CTRL
reg	[8:0]		rptc_ctrl;	// RPTC_CTRL register
`else
wire	[8:0]		rptc_ctrl;	// No RPTC_CTRL register
`endif

//
// Internal wires & regs
//
    wire			rptc_cntr_sel;	// Counter Register(RPTC_CNTR) select
    wire			rptc_hrc_sel;	// High Reference/Capture Register(RPTC_HRC) select
    wire			rptc_lrc_sel;	// Low Reference/Capture Register(RPTC_HRC) select
    wire			rptc_ctrl_sel;	// Control register(RPTC_CTRL) select
    wire			hrc_match;	    // RPTC_HRC matches RPTC_CNTR
    wire			lrc_match;	    // RPTC_LRC matches RPTC_CNTR
    wire			restart;	    // Restart counter when asserted
    wire			stop;		    // Stop counter when asserted
    wire			cntr_clk;	    // Counter clock
    wire			cntr_rst;	    // Counter reset
    wire			hrc_clk;	    // RPTC_HRC clock
    wire			lrc_clk;	    // RPTC_LRC clock
    wire			eclk_gate;	    // ptc_ecgt xored by RPTC_CTRL[NEC]
    wire			gate;		    // Gate function of ptc_ecgt
    wire			pwm_rst;	    // Reset of a PWM output
    reg			    pwm_o;	        // PWM output
    reg			    intr;		    // Interrupt reg
    wire			intr_match;	    // Interrupt match
    reg   [dw-1:0]  data_out_reg;   // Data_out register
    wire            polarity;       // Polarity wire
    reg           trigger;        // Trigger register for PWM output wire default value set
  	wire 			oen_o;


    //
    // Counter clock is selected by RPTC_CTRL[ECLK]. When it is set,
    // external clock is used.
    //
      assign cntr_clk = rptc_ctrl[`PTC_RPTC_CTRL_ECLK] ? eclk_gate : clk;

    //
    // Counter reset
    //
      assign cntr_rst = rst_n;

    //
    // HRC clock is selected by RPTC_CTRL[CAPTE]. When it is set,
    // ptc_capt(In the testbench) is used as a clock.
    //
      assign hrc_clk = rptc_ctrl[`PTC_RPTC_CTRL_CAPTE] ? ui_in[1] : clk;

    //
    // LRC clock is selected by RPTC_CTRL[CAPTE]. When it is set,
    // inverted ptc_capt is used as a clock.
    //
      assign lrc_clk = rptc_ctrl[`PTC_RPTC_CTRL_CAPTE] ? ~ui_in[1] : clk;

    //
    // PWM output driver enable is inverted RPTC_CTRL[OE]
    //
    assign oen_o = ~rptc_ctrl[`PTC_RPTC_CTRL_OE];

    //
    // Use RPTC_CTRL[NEC]
    //
    assign eclk_gate = ui_in[0] ^ rptc_ctrl[`PTC_RPTC_CTRL_NEC];

    //
    // Gate function is active when RPTC_CTRL[ECLK] is cleared
    //
    assign gate = eclk_gate & ~rptc_ctrl[`PTC_RPTC_CTRL_ECLK];


    //
    // PTC registers address decoder
    //
      assign rptc_cntr_sel = (~&data_write_n) & ((address[4:2] == `PTC_RPTC_CNTR) 		 | (ui_in[5:3] == `PTC_RPTC_CNTR))			;
      assign rptc_hrc_sel  = (~&data_write_n) & ((address[4:2] == `PTC_RPTC_HRC)  		 | (ui_in[5:3] == `PTC_RPTC_HRC))			;
      assign rptc_lrc_sel  = (~&data_write_n) & ((address[4:2] == `PTC_RPTC_LRC)  		 | (ui_in[5:3] == `PTC_RPTC_LRC))			;
      assign rptc_ctrl_sel = (~&data_write_n) & ((address[4:2] == `PTC_RPTC_CTRL) 		 | (ui_in[5:3] == `PTC_RPTC_CTRL))			;
      assign polarity	   = ~rst_n ? 1'b0 : (address[5] == 1'b1 | ui_in[6] == 1'b1)	;


    //
    // Write to RPTC_CTRL or update of RPTC_CTRL[INT] bit
    //
    `ifdef PTC_RPTC_CTRL
      always @(posedge clk or negedge rst_n)
        if (~rst_n)
    		rptc_ctrl <= 9'b0;
      else if (rptc_ctrl_sel && ~&data_write_n)
    		rptc_ctrl <= data_in[8:0];
    	else if (rptc_ctrl[`PTC_RPTC_CTRL_INTE])
          rptc_ctrl[`PTC_RPTC_CTRL_INT] <= rptc_ctrl[`PTC_RPTC_CTRL_INT] | intr;
    `else
    assign rptc_ctrl = `PTC_DEF_RPTC_CTRL;
    `endif

    //
    // Write to RPTC_HRC
    //
    `ifdef PTC_RPTC_HRC
    always @(posedge hrc_clk or negedge rst_n)
    	if (~rst_n)
    		rptc_hrc <= {cw{1'b0}};
    	else if (rptc_hrc_sel && ~&data_write_n)
    		rptc_hrc <= data_in[cw-1:0];
    	else if (rptc_ctrl[`PTC_RPTC_CTRL_CAPTE])
    		rptc_hrc <= rptc_cntr;
    `else
    assign rptc_hrc = `DEF_RPTC_HRC;
    `endif

    //
    // Write to RPTC_LRC
    //
    `ifdef PTC_RPTC_LRC
    always @(posedge lrc_clk or negedge rst_n)
    	if (~rst_n)
    		rptc_lrc <= {cw{1'b0}};
    	else if (rptc_lrc_sel && ~&data_write_n)
    		rptc_lrc <= data_in[cw-1:0];
    	else if (rptc_ctrl[`PTC_RPTC_CTRL_CAPTE])
    		rptc_lrc <= rptc_cntr;
    `else
    assign rptc_lrc = `DEF_RPTC_LRC;
    `endif

    //
    // Write to or increment of RPTC_CNTR
    //
    `ifdef PTC_RPTC_CNTR
      always @(posedge cntr_clk or negedge cntr_rst)
        if (~cntr_rst)
    		rptc_cntr <= {cw{1'b0}};
      else if (rptc_cntr_sel && ~&data_write_n) 
        rptc_cntr <= data_in[cw-1:0];
      else if (restart) begin 
    		rptc_cntr <= {cw{1'b0}};
      end
      else if (!stop && rptc_ctrl[`PTC_RPTC_CTRL_EN] && !gate)
    		rptc_cntr <= rptc_cntr + 1;
    `else
    assign rptc_cntr = `DEF_RPTC_CNTR;
    `endif
  
 
    //
    // Read PTC registers
      
      always @(*) begin
    	case (address[`PTC_OFS_BITS])
            `ifdef PTC_READREGS
                    `PTC_RPTC_HRC : data_out_reg[dw-1:0] = {{dw-cw{1'b0}}, rptc_hrc};
                    `PTC_RPTC_LRC : data_out_reg[dw-1:0] = {{dw-cw{1'b0}}, rptc_lrc};
                    `PTC_RPTC_CTRL: data_out_reg[dw-1:0] = {{dw-9{1'b0}}, rptc_ctrl};
          			`PTC_RPTC_CNTR : data_out_reg[dw-1:0] = {{dw-cw{1'b0}}, rptc_cntr};
            `endif
          default: 		data_out_reg[dw-1:0] = {rptc_cntr[dw-3:0],oen_o,pwm_o};
    	endcase
      end

    //
    // A match when RPTC_HRC is equal to RPTC_CNTR
    //
    assign hrc_match = rptc_ctrl[`PTC_RPTC_CTRL_EN] & (rptc_cntr == rptc_hrc);
    
    //
    // A match when RPTC_LRC is equal to RPTC_CNTR
    //
    assign lrc_match = rptc_ctrl[`PTC_RPTC_CTRL_EN] & (rptc_cntr == rptc_lrc);
    
    //
    // Restart counter when lrc_match asserted and RPTC_CTRL[SINGLE] cleared
    // or when RPTC_CTRL[CNTRRST] is set
    //
      
      assign restart = lrc_match & ~rptc_ctrl[`PTC_RPTC_CTRL_SINGLE]
    	| rptc_ctrl[`PTC_RPTC_CTRL_CNTRRST];
    
    //
    // Stop counter when lrc_match and RPTC_CTRL[SINGLE] both asserted
    //
    assign stop = lrc_match & rptc_ctrl[`PTC_RPTC_CTRL_SINGLE];
    
    //
    // PWM reset when lrc_match or system reset
    //
      assign pwm_rst = lrc_match | ~rst_n;

    //
    // PWM output
    //
      always @(posedge clk) begin	// posedge pwm_rst or posedge hrc_match !!! Damjan
          if(polarity) begin
            if (pwm_rst) begin
                pwm_o <= 1'b1;
            	trigger	  <= 1'b0;
            end
            else if (hrc_match) begin
                pwm_o <= 1'b0;
                trigger   <= 1'b1;
            end
            else if (!trigger) begin
              	pwm_o <= 1'b1;
            end
          end
          else begin
            if (pwm_rst) begin
                pwm_o <= 1'b0;
              	trigger	  <= 1'b0;
            end
            else if (hrc_match)
                pwm_o <= 1'b1; 
          end
      end

  
      assign uo_out[7] 	 = pwm_o;
      assign uo_out[6]	 = oen_o;
    //
    // Interrupt Request Generation
    //
    assign intr_match = (lrc_match | hrc_match) & rptc_ctrl[`PTC_RPTC_CTRL_INTE];

    // Register interrupt request
      always @(posedge clk or negedge rst_n)
        if (~rst_n)
    		intr <= 1'b0;
      else if (intr_match)
    		intr <= 1'b1;
    	else
    		intr <= 1'b0;
  
      assign user_interrupt = rptc_ctrl[`PTC_RPTC_CTRL_INT];
      
      assign data_out     = (data_read_n == 2'b11)? 32'h00000000 : data_out_reg;
      assign data_ready   = (data_read_n == 2'b11) ? 1'b0 : 1'b1;
      assign uo_out[5:0]  = 6'b0;
`else

    //
    // When PTC is not implemented, drive all outputs as would when RPTC_CTRL
    // is cleared
     assign user_interrupt 	= 1'b0;
     assign data_ready 		= (data_read_n == 2'b11) ? 1'b0 : 1'b1;
     assign uo_out[7:0]     = 8'b0;
    //
    // Read PTC registers
    //
    `ifdef PTC_READREGS
    assign data_out = {dw{1'b0}};
    `endif
    
    `endif

endmodule
