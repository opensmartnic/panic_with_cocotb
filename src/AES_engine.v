
`timescale 1ns / 1ps
`include "panic_define.v"

module AES_engine #
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

    parameter NODE_ID = 1,

    parameter INIT_CREDIT_NUM = 2
)
(
    input  wire                       clk,
    input  wire                       rst,

    /*
    * Credit interface output
    */
    output  wire [1:0]      m_credit_control,  // 0: no change; 01: add 1; 10: sub 1

    /*
    * Crossbar interface input
    */
    input  wire [SWITCH_DATA_WIDTH-1:0]     s_switch_axis_tdata,
    input  wire [SWITCH_KEEP_WIDTH-1:0]     s_switch_axis_tkeep,
    input  wire                             s_switch_axis_tvalid,
    output wire                             s_switch_axis_tready,
    input  wire                             s_switch_axis_tlast,
    input  wire [SWITCH_DEST_WIDTH-1:0]     s_switch_axis_tdest,
    input  wire [SWITCH_USER_WIDTH-1:0]     s_switch_axis_tuser,


    /*
    * Crossbar interface output
    */
    output  wire [SWITCH_DATA_WIDTH-1:0]      m_switch_axis_tdata,
    output  wire [SWITCH_KEEP_WIDTH-1:0]      m_switch_axis_tkeep,
    output  wire                              m_switch_axis_tvalid,
    input   wire                              m_switch_axis_tready,
    output  wire                              m_switch_axis_tlast,
    output  wire [SWITCH_DEST_WIDTH-1:0]      m_switch_axis_tdest,
    output  wire [SWITCH_USER_WIDTH-1:0]      m_switch_axis_tuser
    
);

reg add_credit;
reg sub_credit;

assign m_credit_control = {sub_credit , add_credit};

wire [SWITCH_DATA_WIDTH-1:0]      m_input_fifo_tdata;
wire [SWITCH_KEEP_WIDTH-1:0]      m_input_fifo_tkeep;
wire                              m_input_fifo_tvalid;
wire                              m_input_fifo_tready;
reg                               m_input_fifo_tready_reg;
wire                              m_input_fifo_tlast;
wire [SWITCH_DEST_WIDTH-1:0]      m_input_fifo_tdest;
wire [SWITCH_USER_WIDTH-1:0]      m_input_fifo_tuser;

assign m_input_fifo_tready = m_input_fifo_tready_reg;
axis_fifo #(
    .DEPTH(4 * SWITCH_KEEP_WIDTH),
    .DATA_WIDTH(SWITCH_DATA_WIDTH),
    .KEEP_ENABLE(1),
    .KEEP_WIDTH(SWITCH_KEEP_WIDTH),
    .LAST_ENABLE(1),
    .ID_ENABLE(0),
    .DEST_ENABLE(1),
    .DEST_WIDTH(SWITCH_DEST_WIDTH),
    .USER_ENABLE(SWITCH_USER_ENABLE),
    .USER_WIDTH(SWITCH_USER_WIDTH),
    .FRAME_FIFO(0)
)
input_fifo (
    .clk(clk),
    .rst(rst),

    // AXI input
    .s_axis_tdata(s_switch_axis_tdata),
    .s_axis_tkeep(s_switch_axis_tkeep),
    .s_axis_tvalid(s_switch_axis_tvalid),
    .s_axis_tready(s_switch_axis_tready),
    .s_axis_tlast(s_switch_axis_tlast),
    .s_axis_tdest(s_switch_axis_tdest),
    .s_axis_tuser(s_switch_axis_tuser),
    
    // AXI output
    .m_axis_tdata(m_input_fifo_tdata),
    .m_axis_tkeep(m_input_fifo_tkeep),
    .m_axis_tvalid(m_input_fifo_tvalid),
    .m_axis_tready(m_input_fifo_tready),
    .m_axis_tlast(m_input_fifo_tlast),
    .m_axis_tdest(m_input_fifo_tdest),
    .m_axis_tuser(m_input_fifo_tuser)
);

// detour engine //
reg [SWITCH_DATA_WIDTH-1:0]      m_switch_o1_axis_tdata;
reg [SWITCH_KEEP_WIDTH-1:0]      m_switch_o1_axis_tkeep;
reg                              m_switch_o1_axis_tvalid;
wire                             m_switch_o1_axis_tready;
reg                              m_switch_o1_axis_tlast;
reg [SWITCH_DEST_WIDTH-1:0]      m_switch_o1_axis_tdest;
reg [SWITCH_USER_WIDTH-1:0]      m_switch_o1_axis_tuser;

reg [SWITCH_DATA_WIDTH-1:0]      m_switch_o2_axis_tdata;
reg [SWITCH_KEEP_WIDTH-1:0]      m_switch_o2_axis_tkeep;
reg                              m_switch_o2_axis_tvalid;
wire                             m_switch_o2_axis_tready;
reg                              m_switch_o2_axis_tlast;
reg [SWITCH_DEST_WIDTH-1:0]      m_switch_o2_axis_tdest;
reg [SWITCH_USER_WIDTH-1:0]      m_switch_o2_axis_tuser;

reg [SWITCH_DATA_WIDTH-1:0]      m_switch_o3_axis_tdata;
reg [SWITCH_KEEP_WIDTH-1:0]      m_switch_o3_axis_tkeep;
reg                              m_switch_o3_axis_tvalid;
wire                             m_switch_o3_axis_tready;
reg                              m_switch_o3_axis_tlast;
reg [SWITCH_DEST_WIDTH-1:0]      m_switch_o3_axis_tdest;
reg [SWITCH_USER_WIDTH-1:0]      m_switch_o3_axis_tuser;

wire [SWITCH_DATA_WIDTH-1:0]     m_switch_o4_axis_tdata;
wire [SWITCH_KEEP_WIDTH-1:0]     m_switch_o4_axis_tkeep;
wire                             m_switch_o4_axis_tvalid;
wire                             m_switch_o4_axis_tready;
wire                             m_switch_o4_axis_tlast;
wire [SWITCH_DEST_WIDTH-1:0]     m_switch_o4_axis_tdest;
wire [SWITCH_USER_WIDTH-1:0]     m_switch_o4_axis_tuser;

reg [2:0]  packet_counter, packet_counter_reg;

reg [2:0] detour_state;
localparam INPUT_IDLE_STATE = 0;
localparam DETOUR_STATE = 1;
localparam INSERT_STATE = 2;

reg [SWITCH_DATA_WIDTH-1:0]           s_data_buffer_fifo_tdata;
reg [SWITCH_KEEP_WIDTH-1:0]           s_data_buffer_fifo_tkeep;
reg                                   s_data_buffer_fifo_tvalid;
wire                                  s_data_buffer_fifo_tready;
reg                                   s_data_buffer_fifo_tlast;

wire [SWITCH_DATA_WIDTH-1:0]           m_data_buffer_fifo_tdata;
wire [SWITCH_KEEP_WIDTH-1:0]           m_data_buffer_fifo_tkeep;
wire                                   m_data_buffer_fifo_tvalid;
wire                                   m_data_buffer_fifo_tready;
wire                                   m_data_buffer_fifo_tlast;

reg [AXIS_DATA_WIDTH-1:0]            s_cancle_credit_fifo_tdata;
reg                                  s_cancle_credit_fifo_tvalid;
wire                                 s_cancle_credit_fifo_tready;

always @ (posedge clk) begin
    if(rst) begin
        detour_state <= INPUT_IDLE_STATE;
    end
    else begin
        if(detour_state == INPUT_IDLE_STATE) begin
            if(m_input_fifo_tvalid && packet_counter < INIT_CREDIT_NUM) begin
                detour_state <= INSERT_STATE;
            end
            else if(m_input_fifo_tvalid && packet_counter >= INIT_CREDIT_NUM)begin
                detour_state <= DETOUR_STATE;
            end
        end
        else if (detour_state == INSERT_STATE) begin
            if (m_input_fifo_tready_reg && m_input_fifo_tvalid && m_input_fifo_tlast) begin
                detour_state <= INPUT_IDLE_STATE;
            end
        end
        else if (detour_state == DETOUR_STATE) begin
            if(m_input_fifo_tready_reg && m_input_fifo_tvalid && m_input_fifo_tlast ) begin
                detour_state <= INPUT_IDLE_STATE;
            end
        end
    end
end
always @* begin
    s_data_buffer_fifo_tvalid = 0;
    s_data_buffer_fifo_tdata   = 0;
    s_data_buffer_fifo_tkeep   = 0;
    s_data_buffer_fifo_tlast   = 0; 

    m_input_fifo_tready_reg = 0;

    m_switch_o1_axis_tvalid = 0;
    m_switch_o1_axis_tdata = 0;
    m_switch_o1_axis_tkeep = 0;
    m_switch_o1_axis_tlast = 0;
    m_switch_o1_axis_tdest = 0;
    m_switch_o1_axis_tuser = 0;

    s_cancle_credit_fifo_tvalid = 0;
    s_cancle_credit_fifo_tdata = 0;

    sub_credit = 0;
    if(detour_state == INSERT_STATE) begin
        m_input_fifo_tready_reg    =  s_data_buffer_fifo_tready;
        if(m_input_fifo_tready_reg && m_input_fifo_tvalid && m_input_fifo_tlast && m_input_fifo_tuser == 0) begin
            sub_credit = 1;
        end

        s_data_buffer_fifo_tdata   =  m_input_fifo_tdata;
        s_data_buffer_fifo_tkeep   =  m_input_fifo_tkeep;
        s_data_buffer_fifo_tvalid  =  m_input_fifo_tvalid;
        s_data_buffer_fifo_tlast   =  m_input_fifo_tlast;
    end
    else if(detour_state == DETOUR_STATE) begin
        m_switch_o1_axis_tdata  =  m_input_fifo_tdata;
        m_switch_o1_axis_tkeep  =  m_input_fifo_tkeep;
        m_switch_o1_axis_tvalid =  m_input_fifo_tvalid;
        m_input_fifo_tready_reg =  m_switch_o1_axis_tready;
        m_switch_o1_axis_tlast  =  m_input_fifo_tlast;
        m_switch_o1_axis_tdest  =  0;
        m_switch_o1_axis_tuser  =  0;
    end
end


// max two packet
axis_fifo #(
    .DEPTH(64 * SWITCH_KEEP_WIDTH),
    .DATA_WIDTH(SWITCH_DATA_WIDTH),
    .KEEP_ENABLE(1),
    .KEEP_WIDTH(SWITCH_KEEP_WIDTH),
    .LAST_ENABLE(1),
    .USER_ENABLE(0),
    .ID_ENABLE(0),
    .DEST_ENABLE(0),
    .FRAME_FIFO(0)
)
data_buffer_fifo (
    .clk(clk),
    .rst(rst),

    // AXI input
    .s_axis_tdata(s_data_buffer_fifo_tdata),
    .s_axis_tkeep(s_data_buffer_fifo_tkeep),
    .s_axis_tvalid(s_data_buffer_fifo_tvalid),
    .s_axis_tready(s_data_buffer_fifo_tready),
    .s_axis_tlast(s_data_buffer_fifo_tlast),

    // AXI output
    .m_axis_tdata(m_data_buffer_fifo_tdata),
    .m_axis_tkeep(m_data_buffer_fifo_tkeep),
    .m_axis_tvalid(m_data_buffer_fifo_tvalid),
    .m_axis_tready(m_data_buffer_fifo_tready),
    .m_axis_tlast(m_data_buffer_fifo_tlast)
    // .m_axis_tuser(rx_parser_data_fifo_tuser)
);

axis_fifo #(
    .DEPTH(4),
    .DATA_WIDTH(SWITCH_DATA_WIDTH),
    .KEEP_ENABLE(0),
    .LAST_ENABLE(0),
    .ID_ENABLE(0),
    .DEST_ENABLE(0),
    .USER_ENABLE(0),
    .FRAME_FIFO(0)
)
cancle_credit_fifo (
    .clk(clk),
    .rst(rst),

    // AXI input
    .s_axis_tdata(s_cancle_credit_fifo_tdata),
    .s_axis_tvalid(s_cancle_credit_fifo_tvalid),
    .s_axis_tready(s_cancle_credit_fifo_tready),

    // AXI output
    .m_axis_tdata(m_switch_o4_axis_tdata),
    .m_axis_tvalid(m_switch_o4_axis_tvalid),
    .m_axis_tready(m_switch_o4_axis_tready)
);
assign m_switch_o4_axis_tlast = 1;
assign m_switch_o4_axis_tdest = 0;
assign m_switch_o4_axis_tuser = 1; 
assign m_switch_o4_axis_tkeep = {{(SWITCH_DATA_WIDTH - `PANIC_CREDIT_WIDTH)/8{1'd0}},{256/8{1'd1}}};

reg signed [6:0] R;

// compute engine
reg [2:0] compute_state;
localparam STATE_IDLE   = 0;
localparam STATE_BUSY   = 1;
localparam STATE_EGRESS_HEAD = 2;
localparam STATE_EGRESS_DATA = 3;
localparam STATE_EGRESS_CREDIT = 4;
reg [15:0] delay_counter;
reg [SWITCH_DEST_WIDTH-1:0] switch_dest_reg;
reg [`PANIC_CREDIT_WIDTH-1:0] out_credit_reg;

reg  [3:0] f_512_to_128; // 0: no data 1: frist data
reg  [3:0] f_128_to_512;
reg [127:0] aes_in_data;
reg  [28:0] aes_state; // 29 cycle delay
wire [255:0] aes_key;
wire [127:0] aes_out;

assign aes_key = 256'h2b7e151628aed2a6abf7158809cf4f3c_762e7160f38b4da56a784d9045190cfe;

//////////////////aes descriptor////////////////////////

reg [`PANIC_DESC_WIDTH-1:0]          s_aes_desc_fifo_tdata;
reg                                  s_aes_desc_fifo_tvalid;
wire                                 s_aes_desc_fifo_tready;

wire [`PANIC_DESC_WIDTH-1:0]          m_aes_desc_fifo_tdata;
wire                                 m_aes_desc_fifo_tvalid;
wire                                 m_aes_desc_fifo_tready;
reg                                  m_aes_desc_fifo_tready_reg;

assign m_aes_desc_fifo_tready = m_aes_desc_fifo_tready_reg;

reg  if_aes_desc = 0;

always @(posedge clk) begin
    if(rst) begin
        if_aes_desc <= 1;
    end
    else begin
        if(if_aes_desc == 1) begin
            if(m_data_buffer_fifo_tready && m_data_buffer_fifo_tvalid) begin
                if_aes_desc <= 0;
            end
        end

        if(m_data_buffer_fifo_tlast && m_data_buffer_fifo_tready && m_data_buffer_fifo_tvalid) begin
            if_aes_desc <= 1;
        end
    end
end

axis_fifo #(
    .DEPTH(64),
    .DATA_WIDTH(`PANIC_DESC_WIDTH),
    .KEEP_ENABLE(0),
    .LAST_ENABLE(0),
    .ID_ENABLE(0),
    .DEST_ENABLE(0),
    .USER_ENABLE(0),
    .FRAME_FIFO(0)
)
aes_desc_fifo (
    .clk(clk),
    .rst(rst),

    // AXI input
    .s_axis_tdata(m_data_buffer_fifo_tdata),
    .s_axis_tvalid(m_data_buffer_fifo_tready && m_data_buffer_fifo_tvalid && if_aes_desc),
    .s_axis_tready(s_aes_desc_fifo_tready),

    // AXI output
    .m_axis_tdata(m_aes_desc_fifo_tdata),
    .m_axis_tvalid(m_aes_desc_fifo_tvalid),
    .m_axis_tready(m_aes_desc_fifo_tready)
);

reg [SWITCH_KEEP_WIDTH-1+1:0]        s_tkeep_tlast_fifo_tdata;
reg                                  s_tkeep_tlast_fifo_tvalid;
wire                                 s_tkeep_tlast_fifo_tready;

wire                                 m_tkeep_tlast_fifo_tvalid;
wire                                 m_tkeep_tlast_fifo_tready;
wire [SWITCH_KEEP_WIDTH-1:0]         m_tkeep_tlast_fifo_tdata_tkeep;
wire                                 m_tkeep_tlast_fifo_tdata_tlast;
reg                                  m_tkeep_tlast_fifo_tready_reg;

assign m_tkeep_tlast_fifo_tready = m_tkeep_tlast_fifo_tready_reg;

wire [128-1:0]                        m_aes_data_in_fifo_tdata;
wire [16-1:0]                         m_aes_data_in_fifo_tkeep;
wire                                  m_aes_data_in_fifo_tvalid;
wire                                  m_aes_data_in_fifo_tvalid_tmp;
wire                                  m_aes_data_in_fifo_tready;
wire                                  m_aes_data_in_fifo_tlast;

wire [128-1:0]                        s_aes_data_out_fifo_tdata;
wire                                  s_aes_data_out_fifo_tvalid;
wire                                  s_aes_data_out_fifo_tready;
wire [16-1:0]                         s_aes_data_out_fifo_tkeep;
wire                                  s_aes_data_out_fifo_tlast;

wire [SWITCH_DATA_WIDTH-1:0]         m_aes_data_out_fifo_tdata;
wire                                 m_aes_data_out_fifo_tvalid;
wire                                 m_aes_data_out_fifo_tready;
wire [SWITCH_KEEP_WIDTH-1:0]         m_aes_data_out_fifo_tkeep;
wire                                 m_aes_data_out_fifo_tlast;

axis_fifo #(
    .DEPTH(128),
    .DATA_WIDTH(SWITCH_KEEP_WIDTH+1),
    .KEEP_ENABLE(0),
    .LAST_ENABLE(0),
    .ID_ENABLE(0),
    .DEST_ENABLE(0),
    .USER_ENABLE(0),
    .FRAME_FIFO(0)
)
tkeep_tlast_fifo (
    .clk(clk),
    .rst(rst),

    // AXI input
    .s_axis_tdata({m_aes_data_in_fifo_tkeep,m_aes_data_in_fifo_tlast}),
    .s_axis_tvalid(m_aes_data_in_fifo_tready && m_aes_data_in_fifo_tvalid),
    .s_axis_tready(m_aes_data_in_fifo_tready),

    // AXI output
    .m_axis_tdata({m_tkeep_tlast_fifo_tdata_tkeep,m_tkeep_tlast_fifo_tdata_tlast}),
    .m_axis_tvalid(m_tkeep_tlast_fifo_tvalid),
    .m_axis_tready(s_aes_data_out_fifo_tready && s_aes_data_out_fifo_tvalid)
);

///////////////////////////
wire [SWITCH_DATA_WIDTH-1:0]          s_aes_data_in_fifo_tdata;
wire [SWITCH_KEEP_WIDTH-1:0]          s_aes_data_in_fifo_tkeep;
wire                                  s_aes_data_in_fifo_tvalid;
wire                                  s_aes_data_in_fifo_tready;
wire                                  s_aes_data_in_fifo_tlast;

assign m_data_buffer_fifo_tready = s_aes_desc_fifo_tready &&s_aes_data_in_fifo_tready;

assign s_aes_data_in_fifo_tdata  = m_data_buffer_fifo_tdata;
assign s_aes_data_in_fifo_tvalid = m_data_buffer_fifo_tready && m_data_buffer_fifo_tvalid && !if_aes_desc;
assign s_aes_data_in_fifo_tlast  = m_data_buffer_fifo_tlast;
assign s_aes_data_in_fifo_tkeep  = m_data_buffer_fifo_tkeep;


axis_fifo_adapter  #(
    .DEPTH(16 * SWITCH_KEEP_WIDTH),
    .S_DATA_WIDTH(SWITCH_DATA_WIDTH),
    .M_DATA_WIDTH(128),
    .S_KEEP_ENABLE (1),
    .M_KEEP_ENABLE (1),
    .S_KEEP_WIDTH (SWITCH_KEEP_WIDTH),
    .M_KEEP_WIDTH (16),
    .ID_ENABLE(0),
    .DEST_ENABLE(0),
    .USER_ENABLE(0),
    .FRAME_FIFO(0)
)
aes_data_in_fifo (
    .clk(clk),
    .rst(rst),

    // AXI input
    .s_axis_tdata(s_aes_data_in_fifo_tdata),
    .s_axis_tvalid(s_aes_data_in_fifo_tvalid),
    .s_axis_tready(s_aes_data_in_fifo_tready),
    .s_axis_tlast(s_aes_data_in_fifo_tlast),
    .s_axis_tkeep(s_aes_data_in_fifo_tkeep),

    // AXI output
    .m_axis_tdata(m_aes_data_in_fifo_tdata),
    .m_axis_tvalid(m_aes_data_in_fifo_tvalid_tmp),
    .m_axis_tready(m_aes_data_in_fifo_tready),
    .m_axis_tlast(m_aes_data_in_fifo_tlast),
    .m_axis_tkeep(m_aes_data_in_fifo_tkeep)
);

axis_fifo_adapter  #(
    .DEPTH(16 * SWITCH_KEEP_WIDTH),
    .S_DATA_WIDTH(128),
    .M_DATA_WIDTH(SWITCH_DATA_WIDTH),
    .S_KEEP_ENABLE (1),
    .M_KEEP_ENABLE (1),
    .S_KEEP_WIDTH (16),
    .M_KEEP_WIDTH (SWITCH_KEEP_WIDTH),
    .ID_ENABLE(0),
    .DEST_ENABLE(0),
    .USER_ENABLE(0),
    .FRAME_FIFO(0)
)aes_data_out_fifo (
    .clk(clk),
    .rst(rst),

    // AXI input
    .s_axis_tdata(s_aes_data_out_fifo_tdata),
    .s_axis_tvalid(s_aes_data_out_fifo_tvalid),
    .s_axis_tready(s_aes_data_out_fifo_tready),
    .s_axis_tkeep(m_tkeep_tlast_fifo_tdata_tkeep),
    .s_axis_tlast(m_tkeep_tlast_fifo_tdata_tlast),

    // AXI output
    .m_axis_tdata(m_aes_data_out_fifo_tdata),
    .m_axis_tvalid(m_aes_data_out_fifo_tvalid),
    .m_axis_tready(m_aes_data_out_fifo_tready),
    .m_axis_tkeep(m_aes_data_out_fifo_tkeep),
    .m_axis_tlast(m_aes_data_out_fifo_tlast)
);

wire [SWITCH_DATA_WIDTH-1:0]          m_aes_shape_fifo_tdata;
wire [SWITCH_KEEP_WIDTH-1:0]          m_aes_shape_fifo_tkeep;
wire                                  m_aes_shape_fifo_tvalid;
wire                                  m_aes_shape_fifo_tready;
wire                                  m_aes_shape_fifo_tlast;

reg                                   m_aes_shape_fifo_tready_reg;

assign m_aes_shape_fifo_tready = m_aes_shape_fifo_tready_reg;

reg [7:0]  shape_counter;
axis_fifo #(
    .DEPTH(32 * SWITCH_KEEP_WIDTH),
    .DATA_WIDTH(SWITCH_DATA_WIDTH),
    .KEEP_ENABLE(1),
    .KEEP_WIDTH(SWITCH_KEEP_WIDTH),
    .LAST_ENABLE(1),
    .USER_ENABLE(0),
    .ID_ENABLE(0),
    .DEST_ENABLE(0),
    .FRAME_FIFO(0)
)
aes_shape_fifo (
    .clk(clk),
    .rst(rst),

    // AXI input
    .s_axis_tdata(m_aes_data_out_fifo_tdata),
    .s_axis_tkeep(m_aes_data_out_fifo_tkeep),
    .s_axis_tvalid(m_aes_data_out_fifo_tvalid),
    .s_axis_tready(m_aes_data_out_fifo_tready),
    .s_axis_tlast(m_aes_data_out_fifo_tlast),

    // AXI output
    .m_axis_tdata(m_aes_shape_fifo_tdata),
    .m_axis_tkeep(m_aes_shape_fifo_tkeep),
    .m_axis_tvalid(m_aes_shape_fifo_tvalid),
    .m_axis_tready(m_aes_shape_fifo_tready),
    .m_axis_tlast(m_aes_shape_fifo_tlast)
);

always @ (posedge clk) begin
    if(rst) begin
        shape_counter <= 0;
    end
    else begin
        if(m_aes_data_out_fifo_tlast && m_aes_data_out_fifo_tready && m_aes_data_out_fifo_tvalid)
            shape_counter = shape_counter + 1;
        if(m_aes_shape_fifo_tlast && m_aes_shape_fifo_tready && m_aes_shape_fifo_tvalid)
            shape_counter = shape_counter - 1;
    end
end

aes_256 uut (
    .clk(clk), 
    .state(m_aes_data_in_fifo_tdata), 
    .key(aes_key), 
    .out(aes_out)
);


wire                                   s_aes_tiny_fifo_tready;
reg   [15:0]                           aes_tiny_fifo_counter;
wire                                   aes_tiny_fifo_half_full;

assign aes_tiny_fifo_half_full   = (aes_tiny_fifo_counter >= 32);
assign m_aes_data_in_fifo_tvalid = m_aes_data_in_fifo_tvalid_tmp && !aes_tiny_fifo_half_full;

always @(posedge clk) begin
    if(rst) begin
        aes_tiny_fifo_counter <= 0;
    end
    else begin
        if(aes_out && aes_state[0]) begin
            aes_tiny_fifo_counter = aes_tiny_fifo_counter + 1;
        end
        if(s_aes_data_out_fifo_tvalid && s_aes_data_out_fifo_tready) begin
            aes_tiny_fifo_counter = aes_tiny_fifo_counter - 1;
        end
    end
end

axis_fifo #(
    .DEPTH(64),
    .DATA_WIDTH(128),
    .KEEP_ENABLE(0),
    .LAST_ENABLE(0),
    .ID_ENABLE(0),
    .DEST_ENABLE(0),
    .USER_ENABLE(0),
    .FRAME_FIFO(0)
)
aes_tiny_fifo (
    .clk(clk),
    .rst(rst),

    // AXI input
    .s_axis_tdata(aes_out),
    .s_axis_tvalid(aes_state[0]),
    .s_axis_tready(s_aes_tiny_fifo_tready),

    // AXI output
    .m_axis_tdata(s_aes_data_out_fifo_tdata),
    .m_axis_tvalid(s_aes_data_out_fifo_tvalid),
    .m_axis_tready(s_aes_data_out_fifo_tready)
);

always @(posedge clk) begin
    if(rst) begin
        aes_state <= 0;
    end
    else begin
        aes_state = aes_state >> 1;
        aes_state[28] = m_aes_data_in_fifo_tvalid && m_aes_data_in_fifo_tready;
    end
end

always @(posedge clk) begin
    if(rst) begin
        compute_state <= STATE_IDLE;
        delay_counter <= 0;
    end
    else begin
        if(compute_state == STATE_IDLE) begin
           if(m_aes_desc_fifo_tvalid) begin
               compute_state <= STATE_EGRESS_HEAD;
            end
        end
        else if(compute_state == STATE_EGRESS_HEAD) begin
            if(m_aes_desc_fifo_tvalid && m_aes_desc_fifo_tready) begin
                compute_state <= STATE_EGRESS_DATA;
                switch_dest_reg <= m_switch_o2_axis_tdest;
            end
        end
        else if(compute_state == STATE_EGRESS_DATA) begin
            if(m_aes_shape_fifo_tvalid && m_aes_shape_fifo_tready && m_aes_shape_fifo_tlast) begin
                // compute_state <= STATE_EGRESS_CREDIT;
                compute_state <= STATE_IDLE;
            end
        end
    end
end 


always @* begin
    m_aes_shape_fifo_tready_reg = 0;
    m_aes_desc_fifo_tready_reg = 0;
    m_tkeep_tlast_fifo_tready_reg = 0;
    m_switch_o2_axis_tvalid = 0;
    m_switch_o2_axis_tdata = 0;
    m_switch_o2_axis_tkeep = 0;
    m_switch_o2_axis_tlast = 0;
    m_switch_o2_axis_tdest = 0;
    m_switch_o2_axis_tuser = 0;

    m_switch_o3_axis_tvalid = 0;
    m_switch_o3_axis_tdata = 0;
    m_switch_o3_axis_tkeep = 0;
    m_switch_o3_axis_tlast = 0;
    m_switch_o3_axis_tdest = 0;
    m_switch_o3_axis_tuser = 0;

    add_credit = 0;
    if(compute_state == STATE_EGRESS_HEAD) begin // finish processing, send the packet to the next hop
        m_switch_o2_axis_tvalid = m_aes_desc_fifo_tvalid && (shape_counter!= 0);
        if(m_switch_o2_axis_tready && m_aes_desc_fifo_tvalid && shape_counter!= 0) begin
            m_aes_desc_fifo_tready_reg = 1;   // read data from the memory buffer
            
            m_switch_o2_axis_tdata = m_aes_desc_fifo_tdata;
            m_switch_o2_axis_tdata[`PANIC_DESC_CHAIN_OF +: `PANIC_DESC_CHAIN_SIZE] = m_switch_o2_axis_tdata[`PANIC_DESC_CHAIN_OF +: `PANIC_DESC_CHAIN_SIZE] >> `PANIC_DESC_CHAIN_ITEM_SIZE; // switch to next dest
            
            // find next destination, and if there is no other destination, send it to the dma engine/central controller
            m_switch_o2_axis_tdest = m_switch_o2_axis_tdata[`PANIC_DESC_CHAIN_OF +: `PANIC_DESC_CHAIN_ITEM_SIZE];  
            if(m_switch_o2_axis_tdest == 0) begin
                m_switch_o2_axis_tdest = 1; // if equals 0, go to dma engine
            end
            m_switch_o2_axis_tkeep = {{(SWITCH_DATA_WIDTH - `PANIC_DESC_WIDTH)/8{1'd0}},{`PANIC_DESC_WIDTH/8{1'd1}}};;

            
            m_switch_o2_axis_tuser = 0;
            m_switch_o2_axis_tlast = 0;
        end
    end
    else if(compute_state == STATE_EGRESS_DATA) begin
        m_switch_o2_axis_tvalid = m_aes_shape_fifo_tvalid && (shape_counter!= 0);
        if(m_switch_o2_axis_tready && m_aes_shape_fifo_tvalid && shape_counter!= 0) begin
            m_aes_shape_fifo_tready_reg = 1;   // read data from the memory buffer
            m_tkeep_tlast_fifo_tready_reg = 1;
            
            m_switch_o2_axis_tdata = m_aes_shape_fifo_tdata;
            m_switch_o2_axis_tdest = switch_dest_reg;
            m_switch_o2_axis_tkeep = m_aes_shape_fifo_tkeep;
            m_switch_o2_axis_tuser = 0;
            m_switch_o2_axis_tlast = m_aes_shape_fifo_tlast;

            if(m_switch_o2_axis_tlast) begin
                // send back credit
                add_credit = 1;
            end
        end
    end
end

// calculate there are how many packets in this data buffer
always @ (posedge clk) begin
    if(rst) begin
        packet_counter = 0;
        // packet_counter_reg = 0;
    end
    else begin
        if(s_data_buffer_fifo_tready && s_data_buffer_fifo_tvalid && s_data_buffer_fifo_tlast) begin
            packet_counter = packet_counter + 1;
        end
        if(m_aes_shape_fifo_tready && m_aes_shape_fifo_tvalid && m_aes_shape_fifo_tlast) begin
            packet_counter = packet_counter - 1;
        end
        // if(m_switch_axis_tready && m_switch_axis_tready && m_switch_axis_tlast && (m_switch_axis_tuser == 0 && m_switch_axis_tdest != 0)) begin
        //     packet_counter = packet_counter - 1;
        // end
        // packet_counter_reg <= packet_counter;
    end
end

// credit manager: send credit to the panic scheduler

// multiplexer for egress port

wire [SWITCH_DATA_WIDTH-1:0]      s_output_fifo_tdata;
wire [SWITCH_KEEP_WIDTH-1:0]      s_output_fifo_tkeep;
wire                              s_output_fifo_tvalid;
wire                              s_output_fifo_tready;
wire                              s_output_fifo_tlast;
wire [SWITCH_DEST_WIDTH-1:0]      s_output_fifo_tdest;
wire [SWITCH_USER_WIDTH-1:0]      s_output_fifo_tuser;

axis_arb_mux  #(
    .S_COUNT(4),
    .DATA_WIDTH(SWITCH_DATA_WIDTH),
    .KEEP_ENABLE(1),
    .KEEP_WIDTH(SWITCH_KEEP_WIDTH),
    .ID_ENABLE(0),
    .DEST_ENABLE(1),
    .DEST_WIDTH(SWITCH_DEST_WIDTH),
    .USER_ENABLE(SWITCH_USER_ENABLE),
    .USER_WIDTH(SWITCH_USER_WIDTH)
)
switch_out_mux (
    .clk(clk),
    .rst(rst),
    // AXI inputs
    .s_axis_tdata({m_switch_o1_axis_tdata,m_switch_o2_axis_tdata,m_switch_o3_axis_tdata,m_switch_o4_axis_tdata}),
    .s_axis_tkeep({m_switch_o1_axis_tkeep,m_switch_o2_axis_tkeep,m_switch_o3_axis_tkeep,m_switch_o4_axis_tkeep}),
    .s_axis_tvalid({m_switch_o1_axis_tvalid,m_switch_o2_axis_tvalid,m_switch_o3_axis_tvalid,m_switch_o4_axis_tvalid}),
    .s_axis_tready({m_switch_o1_axis_tready,m_switch_o2_axis_tready,m_switch_o3_axis_tready,m_switch_o4_axis_tready}),
    .s_axis_tlast({m_switch_o1_axis_tlast,m_switch_o2_axis_tlast,m_switch_o3_axis_tlast,m_switch_o4_axis_tlast}),
    .s_axis_tdest({m_switch_o1_axis_tdest,m_switch_o2_axis_tdest,m_switch_o3_axis_tdest,m_switch_o4_axis_tdest}),
    .s_axis_tuser({m_switch_o1_axis_tuser,m_switch_o2_axis_tuser,m_switch_o3_axis_tuser,m_switch_o4_axis_tuser}),
    // AXI output
    .m_axis_tdata(s_output_fifo_tdata),
    .m_axis_tkeep(s_output_fifo_tkeep),
    .m_axis_tvalid(s_output_fifo_tvalid),
    .m_axis_tready(s_output_fifo_tready),
    .m_axis_tlast(s_output_fifo_tlast),
    .m_axis_tdest(s_output_fifo_tdest),
    .m_axis_tuser(s_output_fifo_tuser)
);


axis_fifo #(
    .DEPTH(32 * SWITCH_KEEP_WIDTH),
    .DATA_WIDTH(SWITCH_DATA_WIDTH),
    .KEEP_ENABLE(1),
    .KEEP_WIDTH(SWITCH_KEEP_WIDTH),
    .LAST_ENABLE(1),
    .ID_ENABLE(0),
    .DEST_ENABLE(1),
    .DEST_WIDTH(SWITCH_DEST_WIDTH),
    .USER_ENABLE(SWITCH_USER_ENABLE),
    .USER_WIDTH(SWITCH_USER_WIDTH),
    .FRAME_FIFO(0)
)
output_fifo (
    .clk(clk),
    .rst(rst),

    // AXI input
    .s_axis_tdata(s_output_fifo_tdata),
    .s_axis_tkeep(s_output_fifo_tkeep),
    .s_axis_tvalid(s_output_fifo_tvalid),
    .s_axis_tready(s_output_fifo_tready),
    .s_axis_tlast(s_output_fifo_tlast),
    .s_axis_tdest(s_output_fifo_tdest),
    .s_axis_tuser(s_output_fifo_tuser),
    
    // AXI output
    .m_axis_tdata(m_switch_axis_tdata),
    .m_axis_tkeep(m_switch_axis_tkeep),
    .m_axis_tvalid(m_switch_axis_tvalid),
    .m_axis_tready(m_switch_axis_tready),
    .m_axis_tlast(m_switch_axis_tlast),
    .m_axis_tdest(m_switch_axis_tdest),
    .m_axis_tuser(m_switch_axis_tuser)
);

always @ * begin
    if(!rst) begin
        if(aes_tiny_fifo_half_full) begin
            $display("Warning AES tiny fifo half full: %d",aes_tiny_fifo_counter);
        end
        if(s_tkeep_tlast_fifo_tready != 1) begin
             $display("ERROR keep last FIFO NOT READY");
        end
        if(aes_state[0] && !s_aes_tiny_fifo_tready) begin
            $display("ERROR keep last FIFO error empty");
        end
    end
end 

endmodule