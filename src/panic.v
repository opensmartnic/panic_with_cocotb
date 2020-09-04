`timescale 1ns / 1ps
`include "panic_define.v"

module panic #
(
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
    input  wire                       clk,
    input  wire                       rst,
    /*
    * Send data output to the wire
    */
    output wire [AXIS_DATA_WIDTH-1:0]           m_tx_axis_tdata,
    output wire [AXIS_KEEP_WIDTH-1:0]           m_tx_axis_tkeep,
    output wire                                 m_tx_axis_tvalid,
    input  wire                                 m_tx_axis_tready,
    output wire                                 m_tx_axis_tlast,
    output wire                                 m_tx_axis_tuser,

    /*
    * Receive data from the wire
    */
    input  wire [AXIS_DATA_WIDTH-1:0]           s_rx_axis_tdata,
    input  wire [AXIS_KEEP_WIDTH-1:0]           s_rx_axis_tkeep,
    input  wire                                 s_rx_axis_tvalid,
    output wire                                 s_rx_axis_tready,
    input  wire                                 s_rx_axis_tlast,
    input  wire                                 s_rx_axis_tuser,

    /*
    * Receive data input from the dma
    */
    input  wire [AXIS_DATA_WIDTH-1:0]           s_tx_axis_tdata,
    input  wire [AXIS_KEEP_WIDTH-1:0]           s_tx_axis_tkeep,
    input  wire                                 s_tx_axis_tvalid,
    output wire                                 s_tx_axis_tready,
    input  wire                                 s_tx_axis_tlast,
    input  wire                                 s_tx_axis_tuser,

    /*
    * Send data output to the dma
    */
    output  wire [AXIS_DATA_WIDTH-1:0]          m_rx_axis_tdata,
    output  wire [AXIS_KEEP_WIDTH-1:0]          m_rx_axis_tkeep,
    output  wire                                m_rx_axis_tvalid,
    input   wire                                m_rx_axis_tready,
    output  wire                                m_rx_axis_tlast,
    output  wire                                m_rx_axis_tuser

);
localparam FREE_PORT_NUM = 2;
localparam CELL_NUM = 2**(AXI_ADDR_WIDTH+1)/`PANIC_CELL_SIZE;
localparam CELL_ID_WIDTH = $clog2(CELL_NUM);
localparam NUMPIFO = 256;

wire [ENGINE_NUM*2 -1 :0] credit_control;


reg [`PANIC_DESC_TS_SIZE-1:0] timestamp;
always @(posedge clk) begin
    if(rst) begin
        timestamp <= 0;
    end
    else begin
        timestamp <= timestamp +1;
    end
end

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



/*
PANIC MEMORY ALLOCATOR MODULE
Function: allocate memory address for each packet, can reuse memory address when the packet exits panic.
*/

// wire for allocate memory  
wire                             alloc_mem_req;
wire [LEN_WIDTH - 1 : 0]         alloc_mem_size;
wire [CELL_ID_WIDTH -1 : 0]      alloc_cell_id;
wire                             alloc_port_id;
wire                             alloc_mem_success;
wire                             alloc_mem_intense;

// wire for free memory 
wire [FREE_PORT_NUM -1 : 0]                      free_mem_ready;
wire [FREE_PORT_NUM -1 : 0]                      free_mem_req;
wire [FREE_PORT_NUM * LEN_WIDTH - 1 : 0]         free_mem_size;
wire [FREE_PORT_NUM -1 : 0]                      free_bank_id;      
wire [FREE_PORT_NUM * CELL_ID_WIDTH - 1 : 0]     free_cell_id;

panic_memory_alloc #(
    // .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .CELL_NUM(CELL_NUM),
    .CELL_ID_WIDTH(CELL_ID_WIDTH),
    .LEN_WIDTH(LEN_WIDTH),
    // .CELL_SIZE(512 * 3 * 8),
    .FREE_PORT_NUM(FREE_PORT_NUM)
)
panic_memory_alloc_inst (
    .clk(clk),
    .rst(rst),

    .alloc_mem_req(alloc_mem_req),
    .alloc_mem_size(alloc_mem_size),
    // .alloc_mem_addr(alloc_mem_addr),
    .alloc_cell_id(alloc_cell_id),
    .alloc_port_id(alloc_port_id),
    .alloc_mem_success(alloc_mem_success),
    .alloc_mem_intense(alloc_mem_intense),

    .free_mem_req(free_mem_req),
    .free_mem_ready(free_mem_ready),
    .free_mem_size(free_mem_size),
    .free_bank_id(free_bank_id),
    // .free_mem_addr(free_mem_addr)
    .free_cell_id(free_cell_id)
);

/*
PANIC PACKET PARSER MODULE
Function: need to parse packet to generate packet descriptor, and do simple packet processing
*/

// wire for parser output - packet data
wire [AXIS_DATA_WIDTH-1:0]    panic_parser_axis_tdata;
wire [AXIS_KEEP_WIDTH-1:0]    panic_parser_axis_tkeep;
wire                          panic_parser_axis_tvalid;
wire                          panic_parser_axis_tready;
wire                          panic_parser_axis_tlast;
wire                          panic_parser_axis_tuser;

// wire for parser output - packet descriptor
wire [`PANIC_DESC_WIDTH-1:0]         panic_parser_packet_desc;
wire                                 panic_parser_packet_desc_valid;
wire                                 panic_parser_packet_desc_ready;


panic_parser #(
    .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),
    .AXIS_KEEP_WIDTH(AXIS_KEEP_WIDTH),
    .AXIS_LAST_ENABLE(AXIS_LAST_ENABLE),
    .AXIS_ID_ENABLE(AXIS_ID_ENABLE),
    .AXIS_DEST_ENABLE(AXIS_DEST_ENABLE),
    .AXIS_USER_ENABLE(AXIS_USER_ENABLE),
    //.AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .LEN_WIDTH(LEN_WIDTH),
    .CELL_ID_WIDTH(CELL_ID_WIDTH),

    .SWITCH_DATA_WIDTH(SWITCH_DATA_WIDTH),
    .SWITCH_KEEP_WIDTH(SWITCH_KEEP_WIDTH),
    .SWITCH_DEST_WIDTH(SWITCH_DEST_WIDTH),
    .SWITCH_USER_ENABLE(SWITCH_USER_ENABLE),  
    .SWITCH_USER_WIDTH(SWITCH_USER_WIDTH)
)
panic_parser_inst(

    .clk(clk),
    .rst(rst),

    /*
    * Receive data from the wire
    */
    .s_rx_axis_tdata(s_rx_axis_tdata),
    .s_rx_axis_tkeep(s_rx_axis_tkeep),
    .s_rx_axis_tvalid(s_rx_axis_tvalid),
    .s_rx_axis_tready(s_rx_axis_tready),
    .s_rx_axis_tlast(s_rx_axis_tlast),
    .s_rx_axis_tuser(s_rx_axis_tuser),


    /*
    * Send packet data to the packet scheduler
    */
    .m_rx_axis_tdata(panic_parser_axis_tdata),
    .m_rx_axis_tkeep(panic_parser_axis_tkeep),
    .m_rx_axis_tvalid(panic_parser_axis_tvalid),
    .m_rx_axis_tready(panic_parser_axis_tready),
    .m_rx_axis_tlast(panic_parser_axis_tlast),
    .m_rx_axis_tuser(),

    /*
    * Send packet descriptor to the packet scheduler
    */
    .m_packet_desc(panic_parser_packet_desc),
    .m_packet_desc_valid(panic_parser_packet_desc_valid),
    .m_packet_desc_ready(panic_parser_packet_desc_ready),

    /*
    * Memory allocator assign memory address for each packet
    * The memory address is contained in the packet descriptor
    */
    .alloc_mem_req(alloc_mem_req),
    .alloc_mem_size(alloc_mem_size),
    // .alloc_mem_addr(alloc_mem_addr),
    .alloc_port_id(alloc_port_id),
    .alloc_cell_id(alloc_cell_id),
    .alloc_mem_success(alloc_mem_success),
    .alloc_mem_intense(alloc_mem_intense),

    .s_switch_axis_tdata(m_switch_axis_tdata[2*SWITCH_DATA_WIDTH +: SWITCH_DATA_WIDTH]),
    .s_switch_axis_tkeep(m_switch_axis_tkeep[2*SWITCH_KEEP_WIDTH +: SWITCH_KEEP_WIDTH]),
    .s_switch_axis_tvalid(m_switch_axis_tvalid[2]),
    .s_switch_axis_tready(m_switch_axis_tready[2]),
    .s_switch_axis_tlast(m_switch_axis_tlast[2]),
    .s_switch_axis_tdest(m_switch_axis_tdest[2*SWITCH_DEST_WIDTH +: SWITCH_DEST_WIDTH]),
    .s_switch_axis_tuser(m_switch_axis_tuser[2*SWITCH_USER_WIDTH +: SWITCH_USER_WIDTH]),

    .m_switch_axis_tdata(s_switch_axis_tdata[2*SWITCH_DATA_WIDTH +: SWITCH_DATA_WIDTH]),
    .m_switch_axis_tkeep(s_switch_axis_tkeep[2*SWITCH_KEEP_WIDTH +: SWITCH_KEEP_WIDTH]),
    .m_switch_axis_tvalid(s_switch_axis_tvalid[2]),
    .m_switch_axis_tready(s_switch_axis_tready[2]),
    .m_switch_axis_tlast(s_switch_axis_tlast[2]),
    .m_switch_axis_tdest(s_switch_axis_tdest[2*SWITCH_DEST_WIDTH +: SWITCH_DEST_WIDTH]),
    .m_switch_axis_tuser(s_switch_axis_tuser[2*SWITCH_USER_WIDTH +: SWITCH_USER_WIDTH]),

    .timestamp(timestamp)
);


panic_dma #(
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_STRB_WIDTH(AXI_STRB_WIDTH),
    .AXI_ID_WIDTH(AXI_ID_WIDTH),
    .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),
    .AXIS_KEEP_ENABLE(AXIS_KEEP_ENABLE),
    .AXIS_KEEP_WIDTH(AXIS_KEEP_WIDTH),
    .AXIS_LAST_ENABLE(AXIS_LAST_ENABLE),
    .AXIS_ID_ENABLE(AXIS_ID_ENABLE),
    .AXIS_ID_WIDTH(AXIS_ID_WIDTH),
    .AXIS_DEST_ENABLE(AXIS_DEST_ENABLE),
    .AXIS_DEST_WIDTH(AXIS_DEST_WIDTH),
    .AXIS_USER_ENABLE(AXIS_USER_ENABLE),
    .AXIS_USER_WIDTH(AXIS_USER_WIDTH),
    .LEN_WIDTH(LEN_WIDTH),
    .TAG_WIDTH(TAG_WIDTH),

    .SWITCH_DATA_WIDTH(SWITCH_DATA_WIDTH),
    .SWITCH_KEEP_WIDTH(SWITCH_KEEP_WIDTH),
    .SWITCH_DEST_WIDTH(SWITCH_DEST_WIDTH),
    .SWITCH_USER_ENABLE(SWITCH_USER_ENABLE),  
    .SWITCH_USER_WIDTH(SWITCH_USER_WIDTH),
    .CELL_ID_WIDTH(CELL_ID_WIDTH),
    .TEST_MODE(TEST_MODE)

)
panic_dma_inst(

    .clk(clk),
    .rst(rst),

    .m_rx_axis_tdata(m_rx_axis_tdata),
    .m_rx_axis_tkeep(m_rx_axis_tkeep),
    .m_rx_axis_tvalid(m_rx_axis_tvalid),
    .m_rx_axis_tready(m_rx_axis_tready),
    .m_rx_axis_tlast(m_rx_axis_tlast),
    .m_rx_axis_tuser(m_rx_axis_tuser),

    /* 
    * Crossbar port1 interface
    */
    .s_switch_axis_tdata(m_switch_axis_tdata[1*SWITCH_DATA_WIDTH +: SWITCH_DATA_WIDTH]),
    .s_switch_axis_tkeep(m_switch_axis_tkeep[1*SWITCH_KEEP_WIDTH +: SWITCH_KEEP_WIDTH]),
    .s_switch_axis_tvalid(m_switch_axis_tvalid[1]),
    .s_switch_axis_tready(m_switch_axis_tready[1]),
    .s_switch_axis_tlast(m_switch_axis_tlast[1]),
    .s_switch_axis_tdest(m_switch_axis_tdest[1*SWITCH_DEST_WIDTH +: SWITCH_DEST_WIDTH]),
    .s_switch_axis_tuser(m_switch_axis_tuser[1*SWITCH_USER_WIDTH +: SWITCH_USER_WIDTH]),

    .m_switch_axis_tdata(s_switch_axis_tdata[1*SWITCH_DATA_WIDTH +: SWITCH_DATA_WIDTH]),
    .m_switch_axis_tkeep(s_switch_axis_tkeep[1*SWITCH_KEEP_WIDTH +: SWITCH_KEEP_WIDTH]),
    .m_switch_axis_tvalid(s_switch_axis_tvalid[1]),
    .m_switch_axis_tready(s_switch_axis_tready[1]),
    .m_switch_axis_tlast(s_switch_axis_tlast[1]),
    .m_switch_axis_tdest(s_switch_axis_tdest[1*SWITCH_DEST_WIDTH +: SWITCH_DEST_WIDTH]),
    .m_switch_axis_tuser(s_switch_axis_tuser[1*SWITCH_USER_WIDTH +: SWITCH_USER_WIDTH]),


    .free_mem_req(free_mem_req[0]),
    .free_mem_ready(free_mem_ready[0]),
    .free_mem_size(free_mem_size[ 0 * LEN_WIDTH +: LEN_WIDTH ]),
    .free_bank_id(free_bank_id[0]),
    // .free_port_id(free_port_id),
    // .free_mem_addr(free_mem_addr)
    .free_cell_id(free_cell_id[ 0 * CELL_ID_WIDTH +: CELL_ID_WIDTH ]),

    .timestamp(timestamp)

);

/*
PANIC CENTRAL SCHEDULER MODULE
Function: Schedule packets to different engines, manage buffer read and buffer write operation
*/

// write descriptor to the buffer controller module
wire [AXI_ADDR_WIDTH-1:0]  buffer_dma_axis_write_desc_addr  [PORT_NUM-1:0];
wire [LEN_WIDTH-1:0]       buffer_dma_axis_write_desc_len   [PORT_NUM-1:0];
wire [TAG_WIDTH-1:0]       buffer_dma_axis_write_desc_tag   [PORT_NUM-1:0];
wire                       buffer_dma_axis_write_desc_valid [PORT_NUM-1:0];
wire                       buffer_dma_axis_write_desc_ready [PORT_NUM-1:0];

// write descriptor state from the buffer controller module
wire [LEN_WIDTH-1:0]       buffer_dma_axis_write_desc_status_len   [PORT_NUM-1:0];
wire [TAG_WIDTH-1:0]       buffer_dma_axis_write_desc_status_tag   [PORT_NUM-1:0];
wire                       buffer_dma_axis_write_desc_status_valid [PORT_NUM-1:0];

// write data to the buffer controller module
wire [AXIS_DATA_WIDTH-1:0] buffer_dma_axis_write_data_tdata   [PORT_NUM-1:0];
wire [AXIS_KEEP_WIDTH-1:0] buffer_dma_axis_write_data_tkeep   [PORT_NUM-1:0];
wire                       buffer_dma_axis_write_data_tvalid  [PORT_NUM-1:0];
wire                       buffer_dma_axis_write_data_tready  [PORT_NUM-1:0];
wire                       buffer_dma_axis_write_data_tlast   [PORT_NUM-1:0];


// read descriptor to the buffer controller module
wire [AXI_ADDR_WIDTH-1:0]  buffer_dma_axis_read_desc_addr  [PORT_NUM-1:0];
wire [LEN_WIDTH-1:0]       buffer_dma_axis_read_desc_len   [PORT_NUM-1:0];
wire [TAG_WIDTH-1:0]       buffer_dma_axis_read_desc_tag   [PORT_NUM-1:0];
wire                       buffer_dma_axis_read_desc_valid [PORT_NUM-1:0];
wire                       buffer_dma_axis_read_desc_ready [PORT_NUM-1:0];

// read descriptor state from the buffer controller module
wire [TAG_WIDTH-1:0]       buffer_dma_axis_read_desc_status_tag   [PORT_NUM-1:0];
wire                       buffer_dma_axis_read_desc_status_valid [PORT_NUM-1:0];

// read data from the buffer controller module
wire [AXIS_DATA_WIDTH-1:0] buffer_dma_axis_read_data_tdata  [PORT_NUM-1:0];
wire [AXIS_KEEP_WIDTH-1:0] buffer_dma_axis_read_data_tkeep  [PORT_NUM-1:0];
wire                       buffer_dma_axis_read_data_tvalid [PORT_NUM-1:0];
wire                       buffer_dma_axis_read_data_tready [PORT_NUM-1:0];
wire                       buffer_dma_axis_read_data_tlast  [PORT_NUM-1:0];


panic_scheduler #(
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_STRB_WIDTH(AXI_STRB_WIDTH),
    .AXI_ID_WIDTH(AXI_ID_WIDTH),
    .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),
    .AXIS_KEEP_ENABLE(AXIS_KEEP_ENABLE),
    .AXIS_KEEP_WIDTH(AXIS_KEEP_WIDTH),
    .AXIS_LAST_ENABLE(AXIS_LAST_ENABLE),
    .AXIS_ID_ENABLE(AXIS_ID_ENABLE),
    .AXIS_ID_WIDTH(AXIS_ID_WIDTH),
    .AXIS_DEST_ENABLE(AXIS_DEST_ENABLE),
    .AXIS_DEST_WIDTH(AXIS_DEST_WIDTH),
    .AXIS_USER_ENABLE(AXIS_USER_ENABLE),
    .AXIS_USER_WIDTH(AXIS_USER_WIDTH),
    .LEN_WIDTH(LEN_WIDTH),
    .TAG_WIDTH(TAG_WIDTH),

    .SWITCH_DATA_WIDTH(SWITCH_DATA_WIDTH),
    .SWITCH_KEEP_WIDTH(SWITCH_KEEP_WIDTH),
    .SWITCH_DEST_WIDTH(SWITCH_DEST_WIDTH),
    .SWITCH_USER_ENABLE(SWITCH_USER_ENABLE),  
    .SWITCH_USER_WIDTH(SWITCH_USER_WIDTH),

    .ENGINE_NUM(ENGINE_NUM),
    .ENGINE_OFFSET(ENGINE_OFFSET),
    .NODE_NUM(NODE_NUM),

    .FREE_PORT_NUM(FREE_PORT_NUM),

    .CELL_ID_WIDTH(CELL_ID_WIDTH),

    .NUMPIFO(NUMPIFO),
    .INIT_CREDIT_NUM(INIT_CREDIT_NUM),
    .TEST_MODE(TEST_MODE)
)
panic_scheduler_inst(

    .clk(clk),
    .rst(rst),

    /* 
    * Memory Write desc to the mem controller
    */
    .m_mem_p_axis_write_desc_addr({buffer_dma_axis_write_desc_addr[1],buffer_dma_axis_write_desc_addr[0]}),
    .m_mem_p_axis_write_desc_len({buffer_dma_axis_write_desc_len[1],buffer_dma_axis_write_desc_len[0]}),
    .m_mem_p_axis_write_desc_tag({buffer_dma_axis_write_desc_tag[1],buffer_dma_axis_write_desc_tag[0]}),
    .m_mem_p_axis_write_desc_valid({buffer_dma_axis_write_desc_valid[1],buffer_dma_axis_write_desc_valid[0]}),
    .m_mem_p_axis_write_desc_ready({buffer_dma_axis_write_desc_ready[1],buffer_dma_axis_write_desc_ready[0]}),

    /* 
    * Memory Write desc status from the mem controller
    */
    .s_mem_p_axis_write_desc_status_len({buffer_dma_axis_write_desc_status_len[1],buffer_dma_axis_write_desc_status_len[0]}),
    .s_mem_p_axis_write_desc_status_tag({buffer_dma_axis_write_desc_status_tag[1],buffer_dma_axis_write_desc_status_tag[0]}),
    .s_mem_p_axis_write_desc_status_valid({buffer_dma_axis_write_desc_status_valid[1],buffer_dma_axis_write_desc_status_valid[0]}),

    /* 
    * Memory Write data to the mem controller
    */
    .m_mem_p_axis_write_data_tdata({buffer_dma_axis_write_data_tdata[1],buffer_dma_axis_write_data_tdata[0]}),
    .m_mem_p_axis_write_data_tkeep({buffer_dma_axis_write_data_tkeep[1],buffer_dma_axis_write_data_tkeep[0]}),
    .m_mem_p_axis_write_data_tvalid({buffer_dma_axis_write_data_tvalid[1],buffer_dma_axis_write_data_tvalid[0]}),
    .m_mem_p_axis_write_data_tready({buffer_dma_axis_write_data_tready[1],buffer_dma_axis_write_data_tready[0]}),
    .m_mem_p_axis_write_data_tlast({buffer_dma_axis_write_data_tlast[1],buffer_dma_axis_write_data_tlast[0]}),

    /* 
    * Memory Read desc to the mem controller
    */
    .m_mem_p_axis_read_desc_addr({buffer_dma_axis_read_desc_addr[1],buffer_dma_axis_read_desc_addr[0]}),
    .m_mem_p_axis_read_desc_len({buffer_dma_axis_read_desc_len[1],buffer_dma_axis_read_desc_len[0]}),
    .m_mem_p_axis_read_desc_tag({buffer_dma_axis_read_desc_tag[1],buffer_dma_axis_read_desc_tag[0]}),
    .m_mem_p_axis_read_desc_valid({buffer_dma_axis_read_desc_valid[1],buffer_dma_axis_read_desc_valid[0]}),
    .m_mem_p_axis_read_desc_ready({buffer_dma_axis_read_desc_ready[1],buffer_dma_axis_read_desc_ready[0]}),

    /* 
    * Memory Read desc status from the mem controller
    */
    .s_mem_p_axis_read_desc_status_tag({buffer_dma_axis_read_desc_status_tag[1],buffer_dma_axis_read_desc_status_tag[0]}),
    .s_mem_p_axis_read_desc_status_valid({buffer_dma_axis_read_desc_status_valid[1],buffer_dma_axis_read_desc_status_valid[0]}),


    /* 
    * Memory Read data from the mem controller
    */
    .s_mem_p_axis_read_data_tdata({buffer_dma_axis_read_data_tdata[1],buffer_dma_axis_read_data_tdata[0]}),
    .s_mem_p_axis_read_data_tkeep({buffer_dma_axis_read_data_tkeep[1],buffer_dma_axis_read_data_tkeep[0]}),
    .s_mem_p_axis_read_data_tvalid({buffer_dma_axis_read_data_tvalid[1],buffer_dma_axis_read_data_tvalid[0]}),
    .s_mem_p_axis_read_data_tready({buffer_dma_axis_read_data_tready[1],buffer_dma_axis_read_data_tready[0]}),
    .s_mem_p_axis_read_data_tlast({buffer_dma_axis_read_data_tlast[1],buffer_dma_axis_read_data_tlast[0]}),


    /* 
    * Crossbar port 0 and port 3 interface
    */
    .s_switch_p_axis_tdata({m_switch_axis_tdata[3*SWITCH_DATA_WIDTH +: SWITCH_DATA_WIDTH] ,m_switch_axis_tdata[0 +: SWITCH_DATA_WIDTH]}),
    .s_switch_p_axis_tkeep({m_switch_axis_tkeep[3*SWITCH_KEEP_WIDTH +: SWITCH_KEEP_WIDTH] ,m_switch_axis_tkeep[0 +: SWITCH_KEEP_WIDTH]}),
    .s_switch_p_axis_tvalid({m_switch_axis_tvalid[3], m_switch_axis_tvalid[0]}),
    .s_switch_p_axis_tready({m_switch_axis_tready[3], m_switch_axis_tready[0]}),
    .s_switch_p_axis_tlast({m_switch_axis_tlast[3], m_switch_axis_tlast[0]}),
    .s_switch_p_axis_tdest({m_switch_axis_tdest[3*SWITCH_DEST_WIDTH +: SWITCH_DEST_WIDTH] ,m_switch_axis_tdest[0 +: SWITCH_DEST_WIDTH]}),
    .s_switch_p_axis_tuser({m_switch_axis_tuser[3*SWITCH_USER_WIDTH +: SWITCH_USER_WIDTH] ,m_switch_axis_tuser[0 +: SWITCH_USER_WIDTH]}),

    .m_switch_p_axis_tdata({s_switch_axis_tdata[3*SWITCH_DATA_WIDTH +: SWITCH_DATA_WIDTH], s_switch_axis_tdata[0 +: SWITCH_DATA_WIDTH]}),
    .m_switch_p_axis_tkeep({s_switch_axis_tkeep[3*SWITCH_KEEP_WIDTH +: SWITCH_KEEP_WIDTH], s_switch_axis_tkeep[0 +: SWITCH_KEEP_WIDTH]}),
    .m_switch_p_axis_tvalid({s_switch_axis_tvalid[3], s_switch_axis_tvalid[0]}),
    .m_switch_p_axis_tready({s_switch_axis_tready[3], s_switch_axis_tready[0]}),
    .m_switch_p_axis_tlast({s_switch_axis_tlast[3], s_switch_axis_tlast[0]}),
    .m_switch_p_axis_tdest({s_switch_axis_tdest[3*SWITCH_DEST_WIDTH +: SWITCH_DEST_WIDTH], s_switch_axis_tdest[0 +: SWITCH_DEST_WIDTH]}),
    .m_switch_p_axis_tuser({s_switch_axis_tuser[3*SWITCH_USER_WIDTH +: SWITCH_USER_WIDTH], s_switch_axis_tuser[0 +: SWITCH_USER_WIDTH]}),

    .alloc_mem_intense(alloc_mem_intense),

    .free_mem_req(free_mem_req[1]),
    .free_mem_ready(free_mem_ready[1]),
    .free_mem_size(free_mem_size[ 1 * LEN_WIDTH +: LEN_WIDTH ]),
    .free_bank_id(free_bank_id[1]),
    // .free_mem_addr(free_mem_addr)
    .free_cell_id(free_cell_id[ 1 * CELL_ID_WIDTH +: CELL_ID_WIDTH ]),

    .credit_control(credit_control)

);


/*
PANIC MEMORY CONTROLLER (DMA) MODULE
Function: Manage read write operation of the ram
*/

generate
    genvar mn;
    // wire of axi interfacec for ram read write
    for(mn = 0; mn < PORT_NUM; mn = mn +1) begin

        wire [AXI_ID_WIDTH-1:0]    axi_awid;
        wire [AXI_ADDR_WIDTH-1:0]  axi_awaddr;
        wire [7:0]                 axi_awlen;
        wire [2:0]                 axi_awsize;
        wire [1:0]                 axi_awburst;
        wire                       axi_awlock;
        wire [3:0]                 axi_awcache;
        wire [2:0]                 axi_awprot;
        wire                       axi_awvalid;
        wire                       axi_awready;
        wire [AXI_DATA_WIDTH-1:0]  axi_wdata;
        wire [AXI_STRB_WIDTH-1:0]  axi_wstrb;
        wire                       axi_wlast;
        wire                       axi_wvalid;
        wire                       axi_wready;
        wire [AXI_ID_WIDTH-1:0]    axi_bid;
        wire [1:0]                 axi_bresp;
        wire                       axi_bvalid;
        wire                       axi_bready;
        wire [AXI_ID_WIDTH-1:0]    axi_arid;
        wire [AXI_ADDR_WIDTH-1:0]  axi_araddr;
        wire [7:0]                 axi_arlen;
        wire [2:0]                 axi_arsize;
        wire [1:0]                 axi_arburst;
        wire                       axi_arlock;
        wire [3:0]                 axi_arcache;
        wire [2:0]                 axi_arprot;
        wire                       axi_arvalid;
        wire                       axi_arready;
        wire [AXI_ID_WIDTH-1:0]    axi_rid;
        wire [AXI_DATA_WIDTH-1:0]  axi_rdata;
        wire [1:0]                 axi_rresp;
        wire                       axi_rlast;
        wire                       axi_rvalid;
        wire                       axi_rready;


        axi_dma #(
            .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
            .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
            .AXI_STRB_WIDTH(AXI_STRB_WIDTH),
            .AXI_ID_WIDTH(AXI_ID_WIDTH),
            .AXI_MAX_BURST_LEN(AXI_MAX_BURST_LEN),
            .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),
            .AXIS_KEEP_ENABLE(AXIS_KEEP_ENABLE),
            .AXIS_KEEP_WIDTH(AXIS_KEEP_WIDTH),
            .AXIS_LAST_ENABLE(AXIS_LAST_ENABLE),
            .AXIS_ID_ENABLE(0),
            // .AXIS_ID_WIDTH(AXIS_ID_WIDTH),
            .AXIS_DEST_ENABLE(0),
            // .AXIS_DEST_WIDTH(AXIS_DEST_WIDTH),
            .AXIS_USER_ENABLE(0),
            // .AXIS_USER_WIDTH(AXIS_USER_WIDTH),
            .LEN_WIDTH(LEN_WIDTH),
            .TAG_WIDTH(TAG_WIDTH),
            .ENABLE_SG(ENABLE_SG),
            .ENABLE_UNALIGNED(ENABLE_UNALIGNED)
        )
        axi_dma_inst (
            .clk(clk),
            .rst(rst),
            .s_axis_read_desc_addr(buffer_dma_axis_read_desc_addr[mn]),
            .s_axis_read_desc_len(buffer_dma_axis_read_desc_len[mn]),
            .s_axis_read_desc_tag(buffer_dma_axis_read_desc_tag[mn]),
            .s_axis_read_desc_valid(buffer_dma_axis_read_desc_valid[mn]),
            .s_axis_read_desc_ready(buffer_dma_axis_read_desc_ready[mn]),

            .m_axis_read_desc_status_tag(buffer_dma_axis_read_desc_status_tag[mn]),
            .m_axis_read_desc_status_valid(buffer_dma_axis_read_desc_status_valid[mn]),
            .m_axis_read_data_tdata(buffer_dma_axis_read_data_tdata[mn]),
            .m_axis_read_data_tkeep(buffer_dma_axis_read_data_tkeep[mn]),
            .m_axis_read_data_tvalid(buffer_dma_axis_read_data_tvalid[mn]),
            .m_axis_read_data_tready(buffer_dma_axis_read_data_tready[mn]),
            .m_axis_read_data_tlast(buffer_dma_axis_read_data_tlast[mn]),
            // .m_axis_read_data_tid(),
            // .m_axis_read_data_tdest(),
            // .m_axis_read_data_tuser(),

            .s_axis_write_desc_addr(buffer_dma_axis_write_desc_addr[mn]),
            .s_axis_write_desc_len(buffer_dma_axis_write_desc_len[mn]),
            .s_axis_write_desc_tag(buffer_dma_axis_write_desc_tag[mn]),
            .s_axis_write_desc_valid(buffer_dma_axis_write_desc_valid[mn]),
            .s_axis_write_desc_ready(buffer_dma_axis_write_desc_ready[mn]),

            .m_axis_write_desc_status_len(buffer_dma_axis_write_desc_status_len[mn]),
            .m_axis_write_desc_status_tag(buffer_dma_axis_write_desc_status_tag[mn]),
            .m_axis_write_desc_status_valid(buffer_dma_axis_write_desc_status_valid[mn]),

            .s_axis_write_data_tdata(buffer_dma_axis_write_data_tdata[mn]),
            .s_axis_write_data_tkeep(buffer_dma_axis_write_data_tkeep[mn]),
            .s_axis_write_data_tvalid(buffer_dma_axis_write_data_tvalid[mn]),
            .s_axis_write_data_tready(buffer_dma_axis_write_data_tready[mn]),
            .s_axis_write_data_tlast(buffer_dma_axis_write_data_tlast[mn]),

            // aw write address
            .m_axi_awid(axi_awid),
            .m_axi_awaddr(axi_awaddr),
            .m_axi_awlen(axi_awlen),    // cycle_num -1
            .m_axi_awsize(axi_awsize),  // data width with coded
            .m_axi_awburst(axi_awburst),
            .m_axi_awlock(axi_awlock),
            .m_axi_awcache(axi_awcache),
            .m_axi_awprot(axi_awprot),
            .m_axi_awvalid(axi_awvalid),
            .m_axi_awready(axi_awready),
            // w write data
            .m_axi_wdata(axi_wdata),
            .m_axi_wstrb(axi_wstrb),    // ignore
            .m_axi_wlast(axi_wlast),
            .m_axi_wvalid(axi_wvalid),
            .m_axi_wready(axi_wready),
            // ar read address
            .m_axi_bid(axi_bid),
            .m_axi_bresp(axi_bresp),
            .m_axi_bvalid(axi_bvalid),
            .m_axi_bready(axi_bready),
            .m_axi_arid(axi_arid),
            .m_axi_araddr(axi_araddr),
            .m_axi_arlen(axi_arlen),
            .m_axi_arsize(axi_arsize),
            .m_axi_arburst(axi_arburst),
            .m_axi_arlock(axi_arlock),
            .m_axi_arcache(axi_arcache),
            .m_axi_arprot(axi_arprot),
            .m_axi_arvalid(axi_arvalid),
            .m_axi_arready(axi_arready),
            //r read data back
            .m_axi_rid(axi_rid),
            .m_axi_rdata(axi_rdata),
            .m_axi_rresp(axi_rresp),    //invalid/valid, 0 is ok
            .m_axi_rlast(axi_rlast),
            .m_axi_rvalid(axi_rvalid),
            .m_axi_rready(axi_rready),
            //b write response  -- valid or invalid wirte response

            .read_enable(1),
            .write_enable(1),
            .write_abort(0)
        );

        /*
        PANIC MEMORY MODULE
        Function: RAM (central buffer)
        */
        axi_ram #(
            .DATA_WIDTH(AXI_DATA_WIDTH),
            .ADDR_WIDTH(AXI_ADDR_WIDTH),
            .STRB_WIDTH(AXI_STRB_WIDTH),
            .PIPELINE_OUTPUT(0)
        )
        axi_ram_inst (
            .clk(clk),
            .rst(rst),
            .s_axi_awid(axi_awid),
            .s_axi_awaddr(axi_awaddr),
            .s_axi_awlen(axi_awlen),
            .s_axi_awsize(axi_awsize),
            .s_axi_awburst(axi_awburst),
            .s_axi_awlock(axi_awlock),
            .s_axi_awcache(axi_awcache),
            .s_axi_awprot(axi_awprot),
            .s_axi_awvalid(axi_awvalid),
            .s_axi_awready(axi_awready),
            .s_axi_wdata(axi_wdata),
            .s_axi_wstrb(axi_wstrb),
            .s_axi_wlast(axi_wlast),
            .s_axi_wvalid(axi_wvalid),
            .s_axi_wready(axi_wready),
            .s_axi_bid(axi_bid),
            .s_axi_bresp(axi_bresp),
            .s_axi_bvalid(axi_bvalid),
            .s_axi_bready(axi_bready),
            .s_axi_arid(axi_arid),
            .s_axi_araddr(axi_araddr),
            .s_axi_arlen(axi_arlen),
            .s_axi_arsize(axi_arsize),
            .s_axi_arburst(axi_arburst),
            .s_axi_arlock(axi_arlock),
            .s_axi_arcache(axi_arcache),
            .s_axi_arprot(axi_arprot),
            .s_axi_arvalid(axi_arvalid),
            .s_axi_arready(axi_arready),
            .s_axi_rid(axi_rid),
            .s_axi_rdata(axi_rdata),
            .s_axi_rresp(axi_rresp),
            .s_axi_rlast(axi_rlast),
            .s_axi_rvalid(axi_rvalid),
            .s_axi_rready(axi_rready)
        );

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
/*
PANIC COMPUTE ENGINE MODULE
Function: compute engine module
*/
generate
    genvar n;

    if(TEST_MODE == 1)begin // parallel test
        for (n = ENGINE_OFFSET; n < ENGINE_NUM + ENGINE_OFFSET; n = n + 1) begin : engine
            compute_engine #(
                .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
                .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
                .AXI_STRB_WIDTH(AXI_STRB_WIDTH),
                .AXI_ID_WIDTH(AXI_ID_WIDTH),
                .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),
                .AXIS_KEEP_ENABLE(AXIS_KEEP_ENABLE),
                .AXIS_KEEP_WIDTH(AXIS_KEEP_WIDTH),
                .AXIS_LAST_ENABLE(AXIS_LAST_ENABLE),
                .AXIS_ID_ENABLE(AXIS_ID_ENABLE),
                .AXIS_ID_WIDTH(AXIS_ID_WIDTH),
                .AXIS_DEST_ENABLE(AXIS_DEST_ENABLE),
                .AXIS_DEST_WIDTH(AXIS_DEST_WIDTH),
                .AXIS_USER_ENABLE(AXIS_USER_ENABLE),
                .AXIS_USER_WIDTH(AXIS_USER_WIDTH),
                .LEN_WIDTH(LEN_WIDTH),
                .TAG_WIDTH(TAG_WIDTH),

                .SWITCH_DATA_WIDTH(SWITCH_DATA_WIDTH),
                .SWITCH_KEEP_WIDTH(SWITCH_KEEP_WIDTH),
                .SWITCH_DEST_WIDTH(SWITCH_DEST_WIDTH),
                .SWITCH_USER_ENABLE(SWITCH_USER_ENABLE),   
                .SWITCH_USER_WIDTH(SWITCH_USER_WIDTH),

                .NODE_ID(n),
                .INIT_CREDIT_NUM(INIT_CREDIT_NUM)
            )
            compute_engine_inst(

                .clk(clk),
                .rst(rst),
                
                .m_credit_control(credit_control[(n - ENGINE_OFFSET)*2 +: 2]),
                /* 
                * Crossbar port4-7 interface
                */
                .s_switch_axis_tdata(m_switch_axis_tdata[n*SWITCH_DATA_WIDTH +: SWITCH_DATA_WIDTH]),
                .s_switch_axis_tkeep(m_switch_axis_tkeep[n*SWITCH_KEEP_WIDTH +: SWITCH_KEEP_WIDTH]),
                .s_switch_axis_tvalid(m_switch_axis_tvalid[n +: 1]),
                .s_switch_axis_tready(m_switch_axis_tready[n +: 1]),
                .s_switch_axis_tlast(m_switch_axis_tlast[n +: 1]),
                .s_switch_axis_tdest(m_switch_axis_tdest[n*SWITCH_DEST_WIDTH +: SWITCH_DEST_WIDTH]),
                .s_switch_axis_tuser(m_switch_axis_tuser[n*SWITCH_USER_WIDTH +: SWITCH_USER_WIDTH]),

                .m_switch_axis_tdata(s_switch_axis_tdata[n*SWITCH_DATA_WIDTH +: SWITCH_DATA_WIDTH]),
                .m_switch_axis_tkeep(s_switch_axis_tkeep[n*SWITCH_KEEP_WIDTH +: SWITCH_KEEP_WIDTH]),
                .m_switch_axis_tvalid(s_switch_axis_tvalid[n +: 1]),
                .m_switch_axis_tready(s_switch_axis_tready[n +: 1]),
                .m_switch_axis_tlast(s_switch_axis_tlast[n +: 1]),
                .m_switch_axis_tdest(s_switch_axis_tdest[n*SWITCH_DEST_WIDTH +: SWITCH_DEST_WIDTH]),
                .m_switch_axis_tuser(s_switch_axis_tuser[n*SWITCH_USER_WIDTH +: SWITCH_USER_WIDTH])

            );
        end
    end
    else begin     // SHA_AES_TEST
        // [SHA TAG] --
        for (n = ENGINE_OFFSET; n < ENGINE_NUM + ENGINE_OFFSET; n = n + 1) begin : engine
            if(n == 4 || n == 5) begin
                    SHA_engine #(
                    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
                    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
                    .AXI_STRB_WIDTH(AXI_STRB_WIDTH),
                    .AXI_ID_WIDTH(AXI_ID_WIDTH),
                    .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),
                    .AXIS_KEEP_ENABLE(AXIS_KEEP_ENABLE),
                    .AXIS_KEEP_WIDTH(AXIS_KEEP_WIDTH),
                    .AXIS_LAST_ENABLE(AXIS_LAST_ENABLE),
                    .AXIS_ID_ENABLE(AXIS_ID_ENABLE),
                    .AXIS_ID_WIDTH(AXIS_ID_WIDTH),
                    .AXIS_DEST_ENABLE(AXIS_DEST_ENABLE),
                    .AXIS_DEST_WIDTH(AXIS_DEST_WIDTH),
                    .AXIS_USER_ENABLE(AXIS_USER_ENABLE),
                    .AXIS_USER_WIDTH(AXIS_USER_WIDTH),
                    .LEN_WIDTH(LEN_WIDTH),
                    .TAG_WIDTH(TAG_WIDTH),

                    .SWITCH_DATA_WIDTH(SWITCH_DATA_WIDTH),
                    .SWITCH_KEEP_WIDTH(SWITCH_KEEP_WIDTH),
                    .SWITCH_DEST_WIDTH(SWITCH_DEST_WIDTH),
                    .SWITCH_USER_ENABLE(SWITCH_USER_ENABLE),  
                    .SWITCH_USER_WIDTH(SWITCH_USER_WIDTH),

                    .NODE_ID(n),
                    .INIT_CREDIT_NUM(4)
                )
                compute_engine_inst(

                    .clk(clk),
                    .rst(rst),

                    .m_credit_control(credit_control[(n - ENGINE_OFFSET)*2 +: 2]),

                    /* 
                    * Crossbar port4-5 interface
                    */
                    .s_switch_axis_tdata(m_switch_axis_tdata[n*SWITCH_DATA_WIDTH +: SWITCH_DATA_WIDTH]),
                    .s_switch_axis_tkeep(m_switch_axis_tkeep[n*SWITCH_KEEP_WIDTH +: SWITCH_KEEP_WIDTH]),
                    .s_switch_axis_tvalid(m_switch_axis_tvalid[n +: 1]),
                    .s_switch_axis_tready(m_switch_axis_tready[n +: 1]),
                    .s_switch_axis_tlast(m_switch_axis_tlast[n +: 1]),
                    .s_switch_axis_tdest(m_switch_axis_tdest[n*SWITCH_DEST_WIDTH +: SWITCH_DEST_WIDTH]),
                    .s_switch_axis_tuser(m_switch_axis_tuser[n*SWITCH_USER_WIDTH +: SWITCH_USER_WIDTH]),

                    .m_switch_axis_tdata(s_switch_axis_tdata[n*SWITCH_DATA_WIDTH +: SWITCH_DATA_WIDTH]),
                    .m_switch_axis_tkeep(s_switch_axis_tkeep[n*SWITCH_KEEP_WIDTH +: SWITCH_KEEP_WIDTH]),
                    .m_switch_axis_tvalid(s_switch_axis_tvalid[n +: 1]),
                    .m_switch_axis_tready(s_switch_axis_tready[n +: 1]),
                    .m_switch_axis_tlast(s_switch_axis_tlast[n +: 1]),
                    .m_switch_axis_tdest(s_switch_axis_tdest[n*SWITCH_DEST_WIDTH +: SWITCH_DEST_WIDTH]),
                    .m_switch_axis_tuser(s_switch_axis_tuser[n*SWITCH_USER_WIDTH +: SWITCH_USER_WIDTH])

                );
            end
            else begin
                    AES_engine #(
                    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
                    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
                    .AXI_STRB_WIDTH(AXI_STRB_WIDTH),
                    .AXI_ID_WIDTH(AXI_ID_WIDTH),
                    .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),
                    .AXIS_KEEP_ENABLE(AXIS_KEEP_ENABLE),
                    .AXIS_KEEP_WIDTH(AXIS_KEEP_WIDTH),
                    .AXIS_LAST_ENABLE(AXIS_LAST_ENABLE),
                    .AXIS_ID_ENABLE(AXIS_ID_ENABLE),
                    .AXIS_ID_WIDTH(AXIS_ID_WIDTH),
                    .AXIS_DEST_ENABLE(AXIS_DEST_ENABLE),
                    .AXIS_DEST_WIDTH(AXIS_DEST_WIDTH),
                    .AXIS_USER_ENABLE(AXIS_USER_ENABLE),
                    .AXIS_USER_WIDTH(AXIS_USER_WIDTH),
                    .LEN_WIDTH(LEN_WIDTH),
                    .TAG_WIDTH(TAG_WIDTH),

                    .SWITCH_DATA_WIDTH(SWITCH_DATA_WIDTH),
                    .SWITCH_KEEP_WIDTH(SWITCH_KEEP_WIDTH),
                    .SWITCH_DEST_WIDTH(SWITCH_DEST_WIDTH),
                    .SWITCH_USER_ENABLE(SWITCH_USER_ENABLE),    
                    .SWITCH_USER_WIDTH(SWITCH_USER_WIDTH),

                    .NODE_ID(n),
                    .INIT_CREDIT_NUM(2)
                )
                compute_engine_inst(

                    .clk(clk),
                    .rst(rst),

                    .m_credit_control(credit_control[(n - ENGINE_OFFSET)*2 +: 2]),

                    /* 
                    * Crossbar port6-7 interface
                    */
                    .s_switch_axis_tdata(m_switch_axis_tdata[n*SWITCH_DATA_WIDTH +: SWITCH_DATA_WIDTH]),
                    .s_switch_axis_tkeep(m_switch_axis_tkeep[n*SWITCH_KEEP_WIDTH +: SWITCH_KEEP_WIDTH]),
                    .s_switch_axis_tvalid(m_switch_axis_tvalid[n +: 1]),
                    .s_switch_axis_tready(m_switch_axis_tready[n +: 1]),
                    .s_switch_axis_tlast(m_switch_axis_tlast[n +: 1]),
                    .s_switch_axis_tdest(m_switch_axis_tdest[n*SWITCH_DEST_WIDTH +: SWITCH_DEST_WIDTH]),
                    .s_switch_axis_tuser(m_switch_axis_tuser[n*SWITCH_USER_WIDTH +: SWITCH_USER_WIDTH]),

                    .m_switch_axis_tdata(s_switch_axis_tdata[n*SWITCH_DATA_WIDTH +: SWITCH_DATA_WIDTH]),
                    .m_switch_axis_tkeep(s_switch_axis_tkeep[n*SWITCH_KEEP_WIDTH +: SWITCH_KEEP_WIDTH]),
                    .m_switch_axis_tvalid(s_switch_axis_tvalid[n +: 1]),
                    .m_switch_axis_tready(s_switch_axis_tready[n +: 1]),
                    .m_switch_axis_tlast(s_switch_axis_tlast[n +: 1]),
                    .m_switch_axis_tdest(s_switch_axis_tdest[n*SWITCH_DEST_WIDTH +: SWITCH_DEST_WIDTH]),
                    .m_switch_axis_tuser(s_switch_axis_tuser[n*SWITCH_USER_WIDTH +: SWITCH_USER_WIDTH])

                );
            end
        end
        // [SHA TAG] --
    end
    

endgenerate


endmodule