# PANIC

update：

A small amount of code has been changed here to make it run in modelsim. Code of cocotb has been added. The original tb file written by verilog has been rewritten with cocotb.



## Introduction

This is the FPGA prototype for PANIC. PANIC is a new programmable 100G NIC that provides cross-tenant performance isolation and low-latency load-balancing across parallel offload engines. Our FPGA prototype is implemented in pure Verilog. 

PANIC has unique architectural features, including a hybrid push/pull packet scheduler, a high-performance switching interconnect, and self-contained compute units. In this repo, you can find the Verilog implementation of the above components. Besides, this repo also includes the packet buffer manager, the single-stage RMT pipeline (packet parser), the packet generator, and the packet capture agent.

For more details about PANIC architecture, please check our paper. 

* [PANIC: Your Programmable NIC Should be a Programmable Switch](http://wisr.cs.wisc.edu/papers/panic.hotnets18.pdf)
* PANIC: A High-Performance Programmable NIC for Multi-tenant Networks

![arch design](/doc/arch_design.png)

## Documentations
PANIC source code and testbench are located in *./src*. PANIC uses [Corundum's](https://github.com/ucsdsysnet/corundum) AXIS and AXI library, which is located in *./lib*. Also, PANIC uses [Open Source NoC router RTL](https://github.com/anan-cn/Open-Source-Network-on-Chip-Router-RTL) to build up the crossbar, which is located in *./src/Open-Source-Network-on-Chip-Router-RTL*.

This repo does not include the implementation of the NIC driver, DMA Engine, Ethernet MAC, and physical layer (PHY). However, PANIC can be easily connected with the 100G [Corundum NIC](https://github.com/ucsdsysnet/corundum) using AXI Stream interface, which has implemented the above components.

### Source Files
    panic.v                  : PANIC top module
    panic_parser.v           : PANIC single stage RMT
    panic_scheduler.v        : PANIC central scheduler
    panic_memory_alloc.v     : PANIC memory manager
    panic_define.v           : Definition of PANIC descriptor
    pifo.sv                  : PIFO
    pifo_warp.sv             : PIFO warpper
    panic_noc_warp.v         : NoC warpper
    SHA_engine.v             : SHA engine
    AES engine.v             : AES engine
    compute_engine.v         : Delay engine
    per_counter.v            : Throughput metircs
    perf_lat.v               : Latency metrics


### Testbench
    packet_gen_parallel.v    : Packet generator for replaying Fig.8(c)
    packet_gen_shaaes.v      : Packet generator for replaying Fig.11(a)

## Testing

In the repo, we provide two testbenches to replay the experiments in Vivado HDL simulator. 

* In **packet_gen_parallel.v**, we measure PANIC's throughput using different packet sizes and 40% service time variance (see Fig.1 below). In this testbench we expect to see that PANIC can achieve 100G throughput even if the offload engines have variable performance. For the expected output and analysis please reference Fig.8(c) in PANIC paper.

* In **packet_gen_shaaes.v**, we implement two FPGA-based offload engines in PANIC: an SHA-3-512 engine, and an AES-256 engine (see Fig.2 below). We use four traffic patterns to test PANIC performance. For the expected output and analysis please reference Fig.11(a) in PANIC paper.
  

![chaining model](/doc/chaining_model.png)

Running this repo requires Vivado. (Vivado 2019.x and 2020.1 Webpack is verified). We strongly recommend you to use the [AWS FPGA Developer AMI](https://aws.amazon.com/marketplace/pp/B06VVYBLZZ), which has pre-installed the Vivado toolchain.

**0. Instance [FPGA Developer AMI](https://aws.amazon.com/marketplace/pp/B06VVYBLZZ) in AWS (If Vivado 2019 Webpack is already installed, ignore this step)**
```
// User guide of Amazon Machine Images (AMI): https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html
// We recommand to instance a EC2 with more than 4GB memory and 2 virtual cores, which can impove the simulation speed.
```


**1. Check Vivado is installed correctly, Vivado 2019.x and 2020.1 is verified**

```
$ vivado -mode tcl 
  // Enter the Vivado TCl Command Palette
  Vivado% version
  Vivado% quit
```
**2. Clone the PANIC repo and make run**

```
$ git clone https://bitbucket.org/uw-madison-networking-research/panic_osdi20_artifact.git
$ cd panic_osdi20_artifact
$ make test_parallel  \\ replay Figure 8(c) in PANIC paper
$ make test_shaaes    \\ replay Figure 11(a) in PANIC paper
```
The result will be printed in the console. The output will also be logged in *./build/export_sim/xsim/simulate.log*

