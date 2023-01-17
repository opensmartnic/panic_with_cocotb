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

@cocotb.test()
async def my_first_test(dut):
    """Try accessing the design."""
    
    clk_co = cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await generate_reset(dut)
    cocotb.start_soon(recv_data(dut))

    axis_master = AxiStreamSource(AxiStreamBus.from_prefix(dut, "s_switch_axis"), dut.clk, dut.rst)
    await ClockCycles(dut.clk, 1)
    await axis_master.send(b'\x40\x00\x01\x00\x04\x00\x00' + b'\x0f' + b'\x00'*56+b'a'*64)  # 表示这个报文将延迟15个周期
    await Timer(30, "ns")
    await axis_master.send(b'\x40\x00\x01\x00\x04\x00\x00' + b'\x0f' + b'\x00'*56+b'b'*64)
    await Timer(30, "ns")
    await axis_master.send(b'\x40\x00\x01\x00\x04\x00\x00' + b'\x0f' + b'\x00'*56+b'c'*64)
    await Timer(30, "ns")
    await axis_master.send(b'\x40\x00\x01\x00\x04\x00\x00' + b'\x0f' + b'\x00'*56+b'd'*64)
    await Timer(30, "ns")
    # for _ in range(10):
    #     to_send = ''.join([random.choice(string.ascii_letters) for _ in range(128)])
    #     to_send = to_send.encode('utf-8')
    #     await axis_master.send(to_send)
    #     await Timer(40, "ns")

    # await clk_co
    await Timer(500, "ns")
    dut._log.info(f'totally recv {frame_recv_counter} frames')
