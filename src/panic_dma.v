
`timescale 1ns / 1ps
`include "panic_define.v"
/*
 * PANIC to DMA interface
 */
module panic_dma #
(
    // Width of AXI data bus in bits
    parameter AXI_DATA_WIDTH = 512,
    // Width of AXI address bus in bits
    parameter AXI_ADDR_WIDTH = 16,
    // Width of AXI wstrb (width of data bus in words)
    parameter AXI_STRB_WIDTH = (AXI_DATA_WIDTH/8),
    // Width of AXI ID signal
    parameter AXI_ID_WIDTH = 8,
    // Width of AXI stream interfaces in bits
    parameter AXIS_DATA_WIDTH = AXI_DATA_WIDTH,
    // Use AXI stream tkeep signal
    parameter AXIS_KEEP_ENABLE = (AXIS_DATA_WIDTH>8),
    // AXI stream tkeep signal width (words per cycle)
    parameter AXIS_KEEP_WIDTH = (AXIS_DATA_WIDTH/8),
    // Use AXI stream tlast signal
    parameter AXIS_LAST_ENABLE = 1,
    // Propagate AXI stream tid signal
    parameter AXIS_ID_ENABLE = 0,
    // AXI stream tid signal width
    parameter AXIS_ID_WIDTH = 8,
    // Propagate AXI stream tdest signal
    parameter AXIS_DEST_ENABLE = 0,
    // AXI stream tdest signal width
    parameter AXIS_DEST_WIDTH = 8,
    // Propagate AXI stream tuser signal
    parameter AXIS_USER_ENABLE = 0,
    // AXI stream tuser signal width
    parameter AXIS_USER_WIDTH = 1,
    // Width of length field
    parameter LEN_WIDTH = 16,
    // Width of tag field
    parameter TAG_WIDTH = 8,

    // crossbar data width, current 512, but need refine
    parameter SWITCH_DATA_WIDTH = 512,
    parameter SWITCH_KEEP_WIDTH = (SWITCH_DATA_WIDTH/8),
    // crossbar address width, if 5 is 32*32 crossbar
    parameter SWITCH_DEST_WIDTH = 3,
    // crossbar vcs number
    parameter SWITCH_USER_ENABLE = 1,  

    parameter SWITCH_USER_WIDTH = 1 ,
    parameter CELL_ID_WIDTH = 16,
    parameter TEST_MODE = 0


)
(
    input  wire                       clk,
    input  wire                       rst,

    /*
    * Send data output to the dma
    */
    output  wire [AXIS_DATA_WIDTH-1:0]          m_rx_axis_tdata,
    output  wire [AXIS_KEEP_WIDTH-1:0]          m_rx_axis_tkeep,
    output  wire                                m_rx_axis_tvalid,
    input   wire                                m_rx_axis_tready,
    output  wire                                m_rx_axis_tlast,
    output  wire                                m_rx_axis_tuser,

    /*
    * Crossbar interface input
    */
    input  wire [SWITCH_DATA_WIDTH-1:0]     s_switch_axis_tdata,
    input  wire [SWITCH_KEEP_WIDTH-1:0]     s_switch_axis_tkeep,
    input  wire                             s_switch_axis_tvalid,
    output reg                              s_switch_axis_tready,
    input  wire                             s_switch_axis_tlast,
    input  wire [SWITCH_DEST_WIDTH-1:0]     s_switch_axis_tdest,
    input  wire [SWITCH_USER_WIDTH-1:0]     s_switch_axis_tuser,


    /*
    * Crossbar interface output
    */
    output  reg [SWITCH_DATA_WIDTH-1:0]      m_switch_axis_tdata,
    output  reg [SWITCH_KEEP_WIDTH-1:0]      m_switch_axis_tkeep,
    output  reg                              m_switch_axis_tvalid,
    input   wire                             m_switch_axis_tready,
    output  reg                              m_switch_axis_tlast,
    output  reg [SWITCH_DEST_WIDTH-1:0]      m_switch_axis_tdest,
    output  reg [SWITCH_USER_WIDTH-1:0]      m_switch_axis_tuser,

    /* Memory Allocator Interface*/
    output  reg                             free_mem_req,
    input   wire                            free_mem_ready,
    output  reg [LEN_WIDTH - 1 : 0]         free_mem_size,
    output  reg                             free_bank_id,
    output  reg [CELL_ID_WIDTH - 1 : 0]     free_cell_id,

    input   wire [`PANIC_DESC_TS_SIZE-1:0]  timestamp

);
reg [AXIS_DATA_WIDTH-1:0]           s_receive_data_fifo_tdata;
reg [AXIS_KEEP_WIDTH-1:0]           s_receive_data_fifo_tkeep;
reg                                 s_receive_data_fifo_tvalid;
wire                                s_receive_data_fifo_tready;
reg                                 s_receive_data_fifo_tlast;

// wire [AXIS_DATA_WIDTH-1:0]           m_receive_data_fifo_tdata;
// wire [AXIS_KEEP_WIDTH-1:0]           m_receive_data_fifo_tkeep;
// wire                                 m_receive_data_fifo_tvalid;
// wire                                 m_receive_data_fifo_tready;
// wire                                 m_receive_data_fifo_tlast;
// reg                                  m_receive_data_fifo_tready_reg;

reg  if_packet_header_reg;
reg  [4:0] flow_class, flow_class_reg = 0;


always @(*) begin
    flow_class = flow_class_reg;

    if(s_switch_axis_tvalid && s_switch_axis_tready && if_packet_header_reg) begin
        flow_class = s_switch_axis_tdata[`PANIC_DESC_FLOW_OF +: `PANIC_DESC_FLOW_SIZE];  // assign flow number to it
    end
end



always @(posedge clk) begin
    if(rst) begin
        if_packet_header_reg <= 1;
        flow_class_reg <= 0;
    end
    else begin
        flow_class_reg <= flow_class;
        if(s_switch_axis_tvalid && s_switch_axis_tready && s_switch_axis_tlast) begin
            if_packet_header_reg <= 1;
            // $display("------------Receive packet from flow %d", flow_class);
        end
        else if(s_switch_axis_tvalid && s_switch_axis_tready && if_packet_header_reg) begin
            if_packet_header_reg <= 0;
            // $display("%d -- flow %d" ,timestamp - s_switch_axis_tdata[`PANIC_DESC_TS_OF +: `PANIC_DESC_TS_SIZE], flow_class);
        end
    end
end



always @* begin
    s_receive_data_fifo_tdata = 0;
    s_receive_data_fifo_tkeep = 0;
    s_receive_data_fifo_tvalid = 0;
    s_switch_axis_tready = s_receive_data_fifo_tready;
    s_receive_data_fifo_tlast = 0;

    m_switch_axis_tdata = 0;
    m_switch_axis_tkeep = 0;
    m_switch_axis_tvalid = 0;
    m_switch_axis_tlast = 0;
    m_switch_axis_tdest = 0;
    m_switch_axis_tuser = 0;

    free_mem_req = 0;
    free_cell_id = 0;
    free_mem_size = 0;

    if(if_packet_header_reg && s_switch_axis_tvalid && s_switch_axis_tready) begin  // input packet header
        // free mem request
        if(s_switch_axis_tuser != 1) begin
            free_mem_req = 1;
            free_cell_id = s_switch_axis_tdata[`PANIC_DESC_CELL_ID_OF   +: `PANIC_DESC_CELL_ID_SIZE];
            free_mem_size = s_switch_axis_tdata[`PANIC_DESC_LEN_OF   +: `PANIC_DESC_LEN_SIZE];
            free_bank_id = s_switch_axis_tdata[`PANIC_DESC_PORT_OF];
        end
    end
    else if(!if_packet_header_reg && s_switch_axis_tvalid && s_switch_axis_tready) begin
        // if(s_switch_axis_tuser == 1) begin // packets are from bypass path, then send to dma engine
        if(1) begin
            s_receive_data_fifo_tdata = s_switch_axis_tdata;
            s_receive_data_fifo_tkeep = s_switch_axis_tkeep;
            s_receive_data_fifo_tvalid = s_switch_axis_tvalid;
            s_switch_axis_tready = s_receive_data_fifo_tready;
            s_receive_data_fifo_tlast = s_switch_axis_tlast;
        end
    end
end

axis_fifo #(
    .DEPTH(26 * AXIS_KEEP_WIDTH),
    .DATA_WIDTH(AXIS_DATA_WIDTH),
    .KEEP_ENABLE(1),
    .KEEP_WIDTH(AXIS_KEEP_WIDTH),
    .LAST_ENABLE(AXIS_LAST_ENABLE),
    .USER_ENABLE(0),
    // .USER_WIDTH(AXIS_USER_WIDTH),
    .ID_ENABLE(0),
    .DEST_ENABLE(0),
    .FRAME_FIFO(0)
)
receive_data_fifo (
    .clk(clk),
    .rst(rst),

    // AXI input
    .s_axis_tdata(s_receive_data_fifo_tdata),
    .s_axis_tkeep(s_receive_data_fifo_tkeep),
    .s_axis_tvalid(s_receive_data_fifo_tvalid),
    .s_axis_tready(s_receive_data_fifo_tready),
    .s_axis_tlast(s_receive_data_fifo_tlast),

    // AXI output
    .m_axis_tdata(m_rx_axis_tdata),
    .m_axis_tkeep(m_rx_axis_tkeep),
    .m_axis_tvalid(m_rx_axis_tvalid),
    .m_axis_tready(m_rx_axis_tready),
    .m_axis_tlast(m_rx_axis_tlast)
);



perf_counter #(
    .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),
    .AXIS_KEEP_WIDTH(AXIS_KEEP_WIDTH),
    .TEST_MODE(TEST_MODE)
)
perf_counter_inst_2(

    .clk(clk),
    .rst(rst),

    /*
    * Receive data from the wire
    */
    .s_rx_axis_tdata(s_switch_axis_tdata),
    .s_rx_axis_tkeep(s_switch_axis_tkeep),
    .s_rx_axis_tvalid(s_switch_axis_tvalid && !if_packet_header_reg),
    .s_rx_axis_tready(s_switch_axis_tready),
    .s_rx_axis_tlast(s_switch_axis_tlast),

    /*
    * Send packet data to the packet scheduler
    */
    .m_rx_axis_tvalid(0),
    .m_rx_axis_tready(0),

    .s_flow_class(flow_class)

);

perf_laten #(
    .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),
    .AXIS_KEEP_WIDTH(AXIS_KEEP_WIDTH)
)
perf_laten_inst_2(

    .clk(clk),
    .rst(rst),

    .s_rx_axis_tvalid(s_switch_axis_tvalid && s_switch_axis_tready && if_packet_header_reg),
    .s_rx_axis_ts(s_switch_axis_tdata[`PANIC_DESC_TS_OF +: `PANIC_DESC_TS_SIZE]),

    .timestamp(timestamp),
    .s_flow_class(0)

);



endmodule