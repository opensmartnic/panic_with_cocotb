module panic_mode1 # 
(
    parameter AXIS_DATA_WIDTH = 512, 
    parameter AXIS_KEEP_WIDTH = AXIS_DATA_WIDTH / 8, 
    parameter PORTS = 1
)
(
    input  wire                       clk,
    input  wire                       rst,
    input wire  [PORTS*AXIS_DATA_WIDTH-1:0]    rx_axis_tdata,
    input wire  [PORTS*AXIS_KEEP_WIDTH-1:0]    rx_axis_tkeep,
    input wire  [PORTS-1:0]                    rx_axis_tvalid,
    output reg [PORTS-1:0]                    rx_axis_tready,
    input wire  [PORTS-1:0]                    rx_axis_tlast,
    // input wire  [PORTS-1:0]                    rx_axis_tuser,

    output reg [PORTS*AXIS_DATA_WIDTH-1:0]    panic_rx_axis_tdata,
    output reg [PORTS*AXIS_KEEP_WIDTH-1:0]    panic_rx_axis_tkeep,
    output reg [PORTS-1:0]                    panic_rx_axis_tvalid,
    input wire  [PORTS-1:0]                    panic_rx_axis_tready,
    output reg [PORTS-1:0]                    panic_rx_axis_tlast
    // output reg [PORTS-1:0]                    panic_rx_axis_tuser
);

panic #
(   
    /* MEMORY PARAMETER */
    // Width of AXI memory data bus in bits, normal is 512
    .AXI_DATA_WIDTH(512),
    // Width of panic memory address bus in bits
    .AXI_ADDR_WIDTH(16),

    /*AXIS INTERFACE PARAMETER*/
    // Width of AXI stream interfaces in bits, normal is 512
    .AXIS_DATA_WIDTH(512),
    .AXIS_KEEP_WIDTH(64),
    .AXIS_LAST_ENABLE(1),
    .AXIS_ID_ENABLE(0),
    .AXIS_DEST_ENABLE(0),
    .AXIS_USER_ENABLE(0),
    .LEN_WIDTH(16),
    .TAG_WIDTH(8),
    .ENABLE_UNALIGNED(1),
    .ENABLE_SG(0),

    /*CROSSBAR PARAMETER*/
    // crossbar data width
    .SWITCH_DATA_WIDTH(512),
    // crossbar dest width, if it is 3, then we have 2^3 ports for the corssbar
    .SWITCH_DEST_WIDTH(3),
    .SWITCH_USER_ENABLE(1),  
    .SWITCH_USER_WIDTH(1),

    /*ENGINE PARAMETER*/
    .INIT_CREDIT_NUM(6),
    .ENGINE_NUM(4),
    .TEST_MODE(1)

)
panic_inst
(
    .clk(clk),
    .rst(rst),

    /*
    * Receive data from the wire
    */
    .s_rx_axis_tdata(rx_axis_tdata),
    .s_rx_axis_tkeep(rx_axis_tkeep),
    .s_rx_axis_tvalid(rx_axis_tvalid),
    .s_rx_axis_tready(rx_axis_tready),
    .s_rx_axis_tlast(rx_axis_tlast),
    // .s_rx_axis_tuser(rx_axis_tuser),

    /*
    * Send data output to the dma
    */
    .m_rx_axis_tdata(panic_rx_axis_tdata),
    .m_rx_axis_tkeep(panic_rx_axis_tkeep),
    .m_rx_axis_tvalid(panic_rx_axis_tvalid),
    .m_rx_axis_tready(panic_rx_axis_tready),
    .m_rx_axis_tlast(panic_rx_axis_tlast)
);

endmodule