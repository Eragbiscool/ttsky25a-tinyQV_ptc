

import cocotb
from cocotb.triggers import RisingEdge, Timer, ClockCycles
from cocotb.clock import Clock

from tqv_reg import spi_write_cpha0, spi_read_cpha0

from tqv import TinyQV

# ----------------------------------------------------------------------
# Macro definitions (replace these with your actual values if different)
# ----------------------------------------------------------------------

PTC_RPTC_CNTR      = 0
PTC_RPTC_HRC       = 1
PTC_RPTC_LRC       = 2
PTC_RPTC_CTRL      = 3


PTC_RPTC_CTRL_EN      = 0
PTC_RPTC_CTRL_ECLK    = 1
PTC_RPTC_CTRL_CNTRRST = 7
# ----------------------------------------------------------------------
# Task translations
# ----------------------------------------------------------------------
PERIPHERAL_NUM = 0
# async def generate_clock(dut,pin, period_ns=8):
#     cocotb.start_soon(Clock(dut.pin, period_ns, units="ns").start())

async def wr(dut,adr, dat,tqv):
    await tqv.write_word_reg(adr, dat)
    
 


async def rd(dut,adr,tqv):
    result = await tqv.read_word_reg(adr)
    return result


async def setctrl(dut,val,tqv):
    await wr(dut,(PTC_RPTC_CTRL << 2), val,tqv)


async def sethrc(dut,val,tqv):
    await wr(dut,(PTC_RPTC_HRC << 2), val,tqv)


async def setlrc(dut,val,tqv):
    await wr(dut,(PTC_RPTC_LRC << 2), val,tqv)


async def getcntr(dut,tqv):
    tmp = await rd(dut,(PTC_RPTC_CNTR << 2),tqv)
    return tmp

async def ext_clock(dut,cyc):
    for _ in range(cyc):
        dut.ui_in[0].value = 1
        await Timer(3, units="ns")   # low for 1 ns
        dut.ui_in[0].value = 0
        await Timer(4, units="ns")


# ----------------------------------------------------------------------
# Test converted from SV "test_eclk" task
# ----------------------------------------------------------------------

async def test_eclk(dut,tqv):

    cocotb.log.info("Testing control bit RPTC_CTRL[ECLK] ...")

    # Reset counter
    await setctrl(dut,(1 << PTC_RPTC_CTRL_CNTRRST),tqv)

    cocotb.log.info("Control Reset")
    

    # Set HRC and LRC to max
    await sethrc(dut,(0xFFFFFFFF),tqv)
    cocotb.log.info("High HRC Set")
    await setlrc(dut,(0xFFFFFFFF),tqv)
    cocotb.log.info("High LRC Set")
    # Enable PTC
    await setctrl(dut,(1 << PTC_RPTC_CTRL_EN),tqv)
    cocotb.log.info("Control Set")
    # Wait for time to advance

    await Timer(50, units='ns')
    cocotb.log.info("Wait Done")

    l1 = await getcntr(dut,tqv)
    cocotb.log.info("L1 collected")
    # Phase 2
    await setctrl(dut,(1 << PTC_RPTC_CTRL_CNTRRST),tqv)
    cocotb.log.info("Control Reset")
    await setctrl(dut,(1 << PTC_RPTC_CTRL_EN) | (1 << PTC_RPTC_CTRL_ECLK),tqv)
    cocotb.log.info("Control Set")

   
    await ext_clock(dut,1489)

    cocotb.log.info("Wait Done")

    l2 = await getcntr(dut,tqv)
    cocotb.log.info("L2 collected")

    
    cocotb.log.info(f"l1 = {l1} and l2= {l2}")

    # Compare
    assert l2 - l1 == 49



#
# Top-level cocotb test converted from SV "initial begin" block
#

@cocotb.test()
async def ptc_verification(dut):

    # Equivalent of SV variable initializations
    tqv = TinyQV(dut, PERIPHERAL_NUM)
    

    clock = Clock(dut.clk, 8, units="ns")
    cocotb.start_soon(clock.start())
    await tqv.reset()

    # Display banners
    cocotb.log.info("")
    cocotb.log.info("###")
    cocotb.log.info("### PTC IP Core Verification ###")
    cocotb.log.info("###")
    cocotb.log.info("I. Testing correct operation of RPTC_CTRL control bits")
    cocotb.log.info("")

    await test_eclk(dut,tqv)

    cocotb.log.info("###")
    cocotb.log.info("")

