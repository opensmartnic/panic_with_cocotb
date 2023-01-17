`include "../../src/panic_define.v"
module panic_noc_warp_wrap #(
        // Width of AXI data bus in bits
    parameter AXI_DATA_WIDTH = 512,
    // Width of AXI address bus in bits
    parameter AXI_ADDR_WIDTH = 16,
    // Width of AXI wstrb (width of data bus in words)
    parameter AXI_STRB_WIDTH = (AXI_DATA_WIDTH/8),
    // Width of AXI ID signal
    parameter AXI_ID_WIDTH = 8,
    // Maximum AXI burst length to generate
    parameter AXI_MAX_BURST_LEN = 16,
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
    // Enable support for scatter/gather DMA
    // (multiple descriptors per AXI stream frame)
    parameter ENABLE_SG = 0,
    // Enable support for unaligned transfers
    parameter ENABLE_UNALIGNED = 0,

    // crossbar data width
    parameter SWITCH_DATA_WIDTH = 512,
    parameter SWITCH_KEEP_WIDTH = (SWITCH_DATA_WIDTH/8),
    // crossbar dest width, if it is 3, then we have 2^3 ports for the corssbar
    parameter SWITCH_DEST_WIDTH = 3,
    parameter SWITCH_USER_ENABLE = 1,  
    parameter SWITCH_USER_WIDTH = 1,

    parameter ENGINE_NUM = 4,
    parameter ENGINE_OFFSET = 4,
    parameter NODE_NUM = ENGINE_NUM + ENGINE_OFFSET,
    parameter INIT_CREDIT_NUM = 2,
    parameter PORT_NUM = 2,

    parameter TEST_MODE = 0
)
(
    input wire clk, 
    input wire rst
);


wire [NODE_NUM*SWITCH_DATA_WIDTH-1:0]     s_switch_axis_tdata;
wire [NODE_NUM*SWITCH_KEEP_WIDTH-1:0]     s_switch_axis_tkeep;
wire [NODE_NUM-1:0]                       s_switch_axis_tvalid;
wire [NODE_NUM-1:0]                       s_switch_axis_tready;
wire [NODE_NUM-1:0]                       s_switch_axis_tlast;
wire [NODE_NUM*SWITCH_DEST_WIDTH-1:0]     s_switch_axis_tdest;
wire [NODE_NUM*SWITCH_USER_WIDTH-1:0]     s_switch_axis_tuser;

wire [NODE_NUM*SWITCH_DATA_WIDTH-1:0]      m_switch_axis_tdata;
wire [NODE_NUM*SWITCH_KEEP_WIDTH-1:0]      m_switch_axis_tkeep;
wire [NODE_NUM-1:0]                        m_switch_axis_tvalid;
wire [NODE_NUM-1:0]                        m_switch_axis_tready;
wire [NODE_NUM-1:0]                        m_switch_axis_tlast;
wire [NODE_NUM*SWITCH_DEST_WIDTH-1:0]      m_switch_axis_tdest;
wire [NODE_NUM*SWITCH_USER_WIDTH-1:0]      m_switch_axis_tuser;


generate
    genvar n;
    for(n = 0; n < NODE_NUM; n = n +1) begin: port_signals
        wire [SWITCH_DATA_WIDTH-1:0]    p_s_switch_axis_tdata;
        wire [SWITCH_KEEP_WIDTH-1:0]    p_s_switch_axis_tkeep;
        wire                            p_s_switch_axis_tvalid;
        wire                            p_s_switch_axis_tready;
        wire                            p_s_switch_axis_tlast;
        wire [SWITCH_DEST_WIDTH-1:0]    p_s_switch_axis_tdest;
        wire [SWITCH_USER_WIDTH-1:0]    p_s_switch_axis_tuser;

        wire [SWITCH_DATA_WIDTH-1:0]    p_m_switch_axis_tdata;
        wire [SWITCH_KEEP_WIDTH-1:0]    p_m_switch_axis_tkeep;
        wire                            p_m_switch_axis_tvalid;
        wire                            p_m_switch_axis_tready;
        wire                            p_m_switch_axis_tlast;
        wire [SWITCH_DEST_WIDTH-1:0]    p_m_switch_axis_tdest;
        wire [SWITCH_USER_WIDTH-1:0]    p_m_switch_axis_tuser;

        assign s_switch_axis_tdata[n*SWITCH_DATA_WIDTH +: SWITCH_DATA_WIDTH] = p_s_switch_axis_tdata;
        assign s_switch_axis_tkeep[n*SWITCH_KEEP_WIDTH +: SWITCH_KEEP_WIDTH] = p_s_switch_axis_tkeep;
        assign s_switch_axis_tvalid[n] = p_s_switch_axis_tvalid;
        assign p_s_switch_axis_tready =  s_switch_axis_tready[n];
        assign s_switch_axis_tlast[n] = p_s_switch_axis_tlast;
        assign s_switch_axis_tdest[n*SWITCH_DEST_WIDTH +: SWITCH_DEST_WIDTH] = p_s_switch_axis_tdest;
        assign s_switch_axis_tuser[n*SWITCH_USER_WIDTH +: SWITCH_USER_WIDTH] = p_s_switch_axis_tuser;

        assign p_m_switch_axis_tdata =  m_switch_axis_tdata[n*SWITCH_DATA_WIDTH +: SWITCH_DATA_WIDTH];
        assign p_m_switch_axis_tkeep =  m_switch_axis_tkeep[n*SWITCH_KEEP_WIDTH +: SWITCH_KEEP_WIDTH];
        assign p_m_switch_axis_tvalid =  m_switch_axis_tvalid[n];
        assign m_switch_axis_tready[n] = p_m_switch_axis_tready;
        assign p_m_switch_axis_tlast =  m_switch_axis_tlast[n];
        assign p_m_switch_axis_tdest =  m_switch_axis_tdest[n*SWITCH_DEST_WIDTH +: SWITCH_DEST_WIDTH];
        assign p_m_switch_axis_tuser =  m_switch_axis_tuser[n*SWITCH_USER_WIDTH +: SWITCH_USER_WIDTH];
    end
endgenerate


panic_noc_warp #(
    .S_COUNT(NODE_NUM),
    .M_COUNT(NODE_NUM),
    .DATA_WIDTH(SWITCH_DATA_WIDTH),
    .KEEP_ENABLE(1),
    .ID_ENABLE(0),
    // .ID_WIDTH(),
    .DEST_WIDTH(SWITCH_DEST_WIDTH),
    .USER_ENABLE(SWITCH_USER_ENABLE),
    .USER_WIDTH(SWITCH_USER_WIDTH)
)
panic_noc_warp(
    .clk(clk),
    .rst(rst),

    .s_axis_tdata(s_switch_axis_tdata),
    .s_axis_tkeep(s_switch_axis_tkeep),
    .s_axis_tvalid(s_switch_axis_tvalid),
    .s_axis_tready(s_switch_axis_tready),
    .s_axis_tlast(s_switch_axis_tlast),
    .s_axis_tdest(s_switch_axis_tdest),
    .s_axis_tuser(s_switch_axis_tuser),

    .m_axis_tdata(m_switch_axis_tdata),
    .m_axis_tkeep(m_switch_axis_tkeep),
    .m_axis_tvalid(m_switch_axis_tvalid),
    .m_axis_tready(m_switch_axis_tready),
    .m_axis_tlast(m_switch_axis_tlast),
    .m_axis_tdest(m_switch_axis_tdest),
    .m_axis_tuser(m_switch_axis_tuser)
);

endmodule