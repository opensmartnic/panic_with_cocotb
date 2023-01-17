# test_my_design.py (simple)

import cocotb
from cocotb.triggers import *
import itertools
from cocotb.clock import Clock
import time
# from remote_pdb import RemotePdb; rpdb = RemotePdb("127.0.0.1", 4000)
import traceback
from cocotbext.axi import AxiStreamSource, AxiStreamBus, AxiStreamSink
import random, string

async def generate_reset(dut):
    dut.rst.setimmediatevalue(0)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst.value = 1
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    await ClockCycles(dut.clk, 2)

frame_recv_counter = 0

async def recv_data(dut):
    global frame_recv_counter
    axis_slave = AxiStreamSink(AxiStreamBus.from_prefix(dut, "m_switch_axis"), dut.clk, dut.rst)
    while True:
        data = await axis_slave.recv()
        dut._log.info(f"recv data: {data}")
        frame_recv_counter += 1

frame_send_counter = 0
async def send_data(dut):
    global frame_send_counter
    data_to_send = 0x400004
    prio = 0x02
    while True:
        await RisingEdge(dut.clk)    
        dut.pifo_in_valid.value = 1
        dut.pifo_in_prio.value = prio
        dut.pifo_in_data.value = data_to_send
        dut.pifo_in_drop.value = 1
        dut._log.info(f'send {data_to_send} with prio:{prio}')
        await ReadOnly()
        if dut.pifo_in_ready.value == 1:
            frame_send_counter += 1
            data_to_send += 1
            prio = random.choice(range(0, 255))
        if frame_send_counter > 20:
            break
    await RisingEdge(dut.clk)
    dut.pifo_in_valid.value = 0

@cocotb.test()
async def my_first_test(dut):
    """Try accessing the design."""
    
    clk_co = cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await generate_reset(dut)
    cocotb.start_soon(send_data(dut))
    # dut.pifo_out_ready.value = 1

    await Timer(10000, "ns")
    dut._log.info(f'totally recv {frame_recv_counter} frames')
