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
from udp_ep import UDPFrame

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
    axis_slave = AxiStreamSink(AxiStreamBus.from_prefix(dut, "panic_rx_axis"), dut.clk, dut.rst)
    while True:
        data = await axis_slave.recv()
        dut._log.info(f"recv data: {data}")
        frame_recv_counter += 1

@cocotb.test()
async def my_first_test(dut):
    """Try accessing the design."""
    
    clk_co = cocotb.start_soon(Clock(dut.clk, 4, units="ns").start())
    await generate_reset(dut)
    cocotb.start_soon(recv_data(dut))

    axis_master = AxiStreamSource(AxiStreamBus.from_prefix(dut, "rx_axis"), dut.clk, dut.rst)
    await ClockCycles(dut.clk, 1)
    # udpframe = UDPFrame(payload=b'a'*22, eth_type=0x0800, udp_source_port=2)
    for _ in range(10000):
        udpframe = UDPFrame(payload=b'a'*150, eth_type=0x0800, udp_source_port=random.choice(range(3)))
        await axis_master.send(udpframe.build_axis().data) 
        # await ClockCycles(dut.clk, 6)

    await Timer(1000, "us")
    dut._log.info(f'totally recv {frame_recv_counter} frames')
