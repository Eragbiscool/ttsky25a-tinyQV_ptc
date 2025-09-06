`ifndef ptc_defines_file
`define ptc_defines_file

`define PTC_CW	32

//
// Undefine this one if you don't want to remove the PTC block from your design
// but you also don't need it. When it is undefined, all PTC ports are still
// remain valid, and the core can be synthesized; however, internally, there is
// no PTC functionality.
//
// Defined by default (duhh !).
//
`define PTC_IMPLEMENTED

//
// Undefine if you don't need to read PTC registers.
// When it is undefined, all reads of PTC registers return zero. This
// is usually useful if you want really small area (for example, when
// implemented in FPGA).
//
// To follow the PTC IP core specification document, this one must be defined.
// Also, to successfully run the test bench, it must be defined. By default
// it is defined.
//
`define PTC_READREGS

//
// Full WISHBONE address decoding
//
// It is undefined; partial WISHBONE address decoding is performed.
// Undefine it if you need to save some area.
//
// By default, it is defined.
//
`define PTC_FULL_DECODE

//
// Strict 32-bit WISHBONE access
//
// If this one is defined, all WISHBONE accesses must be 32-bit. If it is
// not defined, err_o is asserted whenever 8- or 16-bit access is made.
// Undefine it if you need to save some area.
//
// By default, it is defined.
//
`define PTC_STRICT_32BIT_ACCESS

//
// WISHBONE address bits used for full decoding of PTC registers.
//
`define PTC_ADDRHH 15
`define PTC_ADDRHL 5
`define PTC_ADDRLH 1
`define PTC_ADDRLL 0

//
// Bits of WISHBONE address used for partial decoding of PTC registers.
//
// Default 4:2.
//
`define PTC_OFS_BITS	`PTC_ADDRHL-1:`PTC_ADDRLH+1

//
// Addresses of PTC registers
//
// To comply with the PTC IP core specification document, they must go from
// address 0 to address 0xC in the following order: RPTC_CNTR, RPTC_HRC,
// RPTC_LRC and RPTC_CTRL
//
//If a  particular alarm/ctrl register is not needed, its address definition
// can be omitted, and the register will not be implemented. Instead a fixed
// default value will
// be used.
//
`define PTC_RPTC_CNTR		 3'b000	// Address 0x0
`define PTC_RPTC_HRC		 3'b001	// Address 0x4
`define PTC_RPTC_LRC		 3'b010	// Address 0x8
`define PTC_RPTC_CTRL		 3'b011	// Address 0xc
`define PTC_POLARITY     1'b1   // Polarity of PWM signal is set when we get 4 in the address pin or ui_in[6:1] 

//
// Default values for unimplemented PTC registers
//
`define PTC_DEF_RPTC_CNT	`PTC_CW'b0
`define PTC_DEF_RPTC_HRC	`PTC_CW'b0
`define PTC_DEF_RPTC_LRC	`PTC_CW'b0
`define PTC_DEF_RPTC_CTRL	9'h01		// RPTC_CTRL[EN] = 1

//
// RPTC_CTRL bits
//
// To comply with the PTC IP core specification document, they must go from
// bit 0 to bit 8 in the following order: EN, ECLK, NEC, OE, SINGLE, INTE,
// INT, CNTRRST, CAPTE
//
`define PTC_RPTC_CTRL_EN		  0
`define PTC_RPTC_CTRL_ECLK		1
`define PTC_RPTC_CTRL_NEC		  2
`define PTC_RPTC_CTRL_OE		  3
`define PTC_RPTC_CTRL_SINGLE	4
`define PTC_RPTC_CTRL_INTE		5
`define PTC_RPTC_CTRL_INT		  6
`define PTC_RPTC_CTRL_CNTRRST	7
`define PTC_RPTC_CTRL_CAPTE		8

`endif