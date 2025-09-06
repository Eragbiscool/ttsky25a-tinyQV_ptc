<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

The peripheral index is the number TinyQV will use to select your peripheral.  You will pick a free
slot when raising the pull request against the main TinyQV repository, and can fill this in then.  You
also need to set this value as the PERIPHERAL_NUM in your test script.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

# PWM/Timer/Counter

Author: Eraz Ahmed

Peripheral index: nn

## What it does

This is an IP to do it all, starting from counting, generating a PWM signal, and measuring the time between two instances. Why is it different? Because you can supply your own clock to do the counting. The design is fully parameterized to make sure we can control most of it until it's hardened. There are multiple type of registers that controls the behavior of this IP. There is also an interrupt behavior implemented in it that can output an interrupt signal as per the registered count being overtaken.

## Register map and Functionality

Document the registers that are used to interact with your peripheral

| Address | Name           | Access | Width | Description                                                            |
|---------|----------------|--------|-------|------------------------------------------------------------------------|
| 0x00    | RPTC_CNTR  | R/W    |  32   | This Register holds the count value that the counter provides to the <br> user |
| 0x04    | RPTC_HRC   | R/W    |  32   | This Register holds the `High Reference Capture Register` that captures <br> counter register data when this externally controlled signal is high <br> and it also holds Reference values for the Counter Register to compare |
| 0x08    | RPTC_LRC   | R/W    |  32   | This Register holds the `Low Reference Capture Register` that captures <br> counter register data when this externally controlled signal is low <br> and it also holds Reference values for the Counter Register to compare |
| 0x0C    | RPTC_CTRL  | R/W    |  9   | This Register holds the control signals to control the functionality <br> of the IP. For example, enabling external clock or capture behavior <br> or both! A better definition of this is discussed next table. |

Control bits in the `RPTC_CTRL` register control the operation of the PTC core.

| Bit     | Access         | Description                                                            |
|---------|----------------|------------------------------------------------------------------------|
| 0       | R/W            | `EN`   <br> This Register bit, When set, RPTC_CNTR can be incremented.   |
| 1       | R/W            | `ECLK` <br> This Register bit, When set, ptc_ecgt signal is used to increment RPTC_CNTR. When cleared, the system <br> clock is used instead. |
| 2       | R/W            | `NEC`  <br> When set, ptc_ecgt increments on negative edge and gates on low period. When cleared, ptc_ecgt <br> increments on the positive edge and gates on high period. This bit affects only on the ‘gating’ <br> function of ptc_ecgt when RPTC_CTRL[ECLK] bit is cleared. |
| 3       | R/W            | `OE`  <br> Inverted value of this bit is reflected on the ptc_oen signal. <br> It is used to enable the PWM output driver and can be collected from `uo_out[6]` or `data_out[1]`.|
| 4       | R/W            | `SINGLE`  <br> When set, RPTC_CNTR is not incremented anymore after it reaches a value equal to the RPTC_LRC value. <br> When cleared, RPTC_CNTR is restarted after it reaches value in the RPTC_LCR register.|
| 5       | R/W            | `INTE`  <br> When set, PTC asserts an interrupt when RPTC_CNTR value is equal to the value of RPTC_LRC or RPTC_HRC. <br> When cleared, interrupts are masked. |
| 6       | R/W            | `INT`  <br> When read, this bit represents a pending interrupt. When it is set, an interrupt is pending. <br> When this bit is written with ‘1’, the interrupt request is cleared.|
| 7       | R/W            | `CNTRRST`  <br> When set, RPTC_CNTR is under reset. When cleared, normal operation of the counter is allowed.|
| 8       | R/W            | `CAPTE`  <br> When set, ptc_capt signal can be used to capture RPTC_CNTR into RPTC_LRC or RPTC_HRC registers. <br> Into which reference/capture register capture occurs depends on edge of the ptc_capt signal. When cleared, <br> capture function is masked.|

### PWM Mode ###
To operate in `PWM mode`, `RPTC_HRC` and `RPTC_LRC` should be set with the value of low and high periods of the PWM output signal. RPTC_HRC is number of clock cycles after reset of the RPTC_CNTR when PWM output should go high. And RPTC_LRC is number of clock cycles after reset of the RPTC_CNTR when PWM output should go low. RPTC_CNTR can be reset with the hardware reset, bit RPTC_CTRL[CNTRRST] or periodically when RPTC_CTRL[SINGLE] bit is cleared. To enable PWM output driver, RPTC_CTRL[OE] should be set. To enable continues operation, RPTC_CTRL[SINGLE] should be cleared and RPTC_CTRL[EN] should be set. If gate function is enabled, PWM periods can be automatically adjusted with the capture input. PWM output signal is controlled with the RPTC_HRC and RPTC_LRC, and these two registers can be set without software control with the ptc_capt signal. 

The `address` pin also controls the polarity of the `output PWM signal` where polarity `high` means the default of the PWM signal is `high` and vice versa.

### Timer/Counter Mode ###
To operate in timer/counter mode, only `RPTC_LRC` or even neither of `capture/reference` registers is required. In this mode `system clock` or `external clock` reference increments `RPTC_CNTR` register. When `RPTC_CNTR` equals to the `RPTC_LRC`, `RPTC_CNTR` can be `reset` if this is selected with the `RPTC_CTRL[SINGLE]`. Usually `interrupts` are enabled in `timer/counter` mode. This is done with the `RPTC_CTRL[INTE]`.

### Gate Feature ###

If `system clock` is used to increment `RPTC_CNTR`, `ui_in[0](external clock)` input signal can be used to gate the `system clock` and not increment the `RPTC_CNTR` register. Which level of the `ui_in[0](external clock)` has gating capability depends on value of the `RPTC_CTRL[NEC]`.

### Interrupt Feature ###

Whenever `RPTC_CNTR` equals to the value of the `RPTC_HRC` or `RPTC_LRC`, an interrupt request can be asserted. This depends if `RPTC_CTRL[INTE]` bit is `set`.

### Capture Feature ###

Input signal `ui_in[1]` can be used to capture value of the current `RPTC_CNTR` into `RPTC_HRC` or `RPTC_LRC` registers. Into which reference/capture register value is captured, depends on edge of the `ui_in[1]` signal. On positive edge value is captured into `RPTC_HRC register` and on negative edge value is captured into `RPTC_LRC` register. In order to enable capture feature, `RPTC_CTRL[CAPTE]` must be set.


## How to test

To test this, the IP is relatively simple and easily understood through the following waveform. Noteworthy here is that once the signal is registered by `data_write_n` being anything other than `2'b11`, the expected output can be started to be observed `1` clock cycle after the `data_write_n` goes to `2'b11` again. So to schedule any read, we will have to ensure that we took enough time after write to see the effect in the registered.

Now, in tinyQV, we have a serial interface which takes a long time to settle down in parallel ports of the IP(`at least 25 cycles`). To deal with this, we will have to consider the headroom taken by each of the changes of the signals to ensure proper counting and timing behavior.

In the test directory of this repo, counting with external clock has been tested for the hardened (`post gds`) design using cocotb. But I have seperately verified all the behaviors for the `RTL` using SystemVerilog in here[1]. Please refer to it for getting more confidence on the design.

The waveforms should look something like this:

![Behavior](40_wavedrom_PTC.svg)
**Note: There is these other pins that is not mentioned here. The pins are `ui_in` `uo_out` and `user_interrupt` which are described in `Pin list` Section**

## Pin list

The pin name and their behavior is as follows:
| Pin Name     | Width         | Type           | Description                                                            |
|--------------|---------------|----------------|------------------------------------------------------------------------|
| `clk`          | 1             | Input          | This is the system clock                                               |
| `rst_n`        | 1             | Input          | This is the system reset and it's active low                           |
| `address`      | 6             | Input          | This is the address pins to access specific register                    |
| `data_in`      | 32            | Input          | This is the input data pins to write to the register selected by address|
| `data_write_n` | 2             | Input          | This is the `write_enable` pins of the IP. For `2'b11 = no write`, `2'b00 = 8-bits(byte)`, `2'b01 = 16-bits(half word)`, `2'b10 = 32-bits(word)` |
| `data_read_n`  | 2             | Input          | This is the `read_enable` pins of the IP. For `2'b11 = no write`, `2'b00 = 8-bits(byte)`, `2'b01 = 16-bits(half word)`, `2'b10 = 32-bits(word)`  |
| `data_out`     | 32            | Output         | This is the data_output pins that behaves according to `data_read_n` and outputs values from the registers  |
| `data_ready`   | 1             | Output         | This is the output pin that validates the `data_out` signal. For a valid `data_out`, `data_ready` needs to be high |
| `ui_in`        | 8             | Input          | This is the pin where `ui_in[0]` and `ui_in[1]` are used for `external clock` insertion and `capture clock/pulse` respectively and other pins are not used and kept low |
| `uo_out`       | 8             | Output         | This is the pin where `ui_in[7]` and `ui_in[6]` are used for `pwm_out` and `oen_out` respectively, where `pwm_out` is the output pwm signal and `oen_out` is the `enable` signal for pwm_driver |

## Noteworthy ##

This design is not a noble one, and is collected from the PTC IP designed in OpenCores for wishbone. The author here has tried to make it work for the tinyQV interface with some custom changes(introducing polarity for pwm_output and some more). Anyone who wants to go through with the real wishbone version can go through with this[2]

## Reference ##

**[1] https://www.edaplayground.com/x/na9r**
**[2] https://github.com/freecores/ptc/tree/master**
