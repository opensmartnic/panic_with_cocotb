# test_my_design.py (simple)

import cocotb
from cocotb.triggers import *
import itertools
from cocotb.clock import Clock
import time
# from remote_pdb import RemotePdb; rpdb = RemotePdb("127.0.0.1", 4000)
import traceback
from cocotbext.axi import AxiStreamSource, AxiStreamBus, AxiStreamSink, AxiStreamFrame
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

async def recv_data(dut, port_num):
    global frame_recv_counter
    axis_slave = AxiStreamSink(AxiStreamBus.from_prefix(dut.port_signals[port_num], "p_m_switch_axis"), dut.clk, dut.rst)
    while True:
        data = await axis_slave.recv()
        dut._log.info(f"recv data: {data}")
        frame_recv_counter += 1
        

@cocotb.test()
async def my_first_test(dut):
    """Try accessing the design."""
    
    clk_co = cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await generate_reset(dut)
    for i in range(8):
        cocotb.start_soon(recv_data(dut, i))

    axis_masters = []
    for i in range(8):
        axis_master = AxiStreamSource(AxiStreamBus.from_prefix(dut.port_signals[i], "p_s_switch_axis"), dut.clk, dut.rst)
        axis_masters.append(axis_master)

    for i in range(100):
        to_send = ''.join([random.choice(string.ascii_letters) for _ in range(128)])
        to_send = to_send.encode('utf-8')
        src_port = random.choice(range(8))
        dst_port = random.choice(range(8))
        while dst_port == src_port:
            dst_port = random.choice(range(8))
        frame = AxiStreamFrame(b'\x80\x00\x00\x00\x04' + b'\x00' * 59 + to_send, tdest=dst_port)
        await axis_masters[src_port].send(frame)
        await Timer(10, "ns")

    # await clk_co
    await Timer(100, "us")
    dut._log.info(f'totally recv {frame_recv_counter} frames')
