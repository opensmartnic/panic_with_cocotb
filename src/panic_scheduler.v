`timescale 1ns / 1ps
`include "panic_define.v"

module panic_scheduler #
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

    parameter ENGINE_NUM = 8,
    parameter ENGINE_OFFSET = 3,
    parameter INIT_CREDIT_NUM = 2,
    parameter NODE_NUM = ENGINE_NUM + 1,

    parameter FREE_PORT_NUM = 2,

    parameter CELL_ID_WIDTH = 16,
    parameter NUMPIFO = 64,

    parameter PORT_NUM = 2,
    parameter TEST_MODE = 0,
    parameter   SMALL_PK_OPT = 0

)
(
    input  wire                       clk,
    input  wire                       rst,


    //memory port 
    /*
     * AXI write memory descriptor output
     */
    output  reg  [PORT_NUM*AXI_ADDR_WIDTH-1:0]       m_mem_p_axis_write_desc_addr,
    output  reg  [PORT_NUM*LEN_WIDTH-1:0]            m_mem_p_axis_write_desc_len,
    output  reg  [PORT_NUM*TAG_WIDTH-1:0]            m_mem_p_axis_write_desc_tag,
    output  reg  [PORT_NUM-1:0]                      m_mem_p_axis_write_desc_valid,
    input   wire [PORT_NUM-1:0]                      m_mem_p_axis_write_desc_ready,


    /*
     * AXI write memory descriptor status input
    */
    input wire [PORT_NUM*LEN_WIDTH-1:0]         s_mem_p_axis_write_desc_status_len,
    input wire [PORT_NUM*TAG_WIDTH-1:0]         s_mem_p_axis_write_desc_status_tag,
    input wire [PORT_NUM-1:0]                   s_mem_p_axis_write_desc_status_valid,


    /*
     * AXI stream write data output
    */
    output  reg  [PORT_NUM*AXIS_DATA_WIDTH-1:0]  m_mem_p_axis_write_data_tdata,
    output  reg  [PORT_NUM*AXIS_KEEP_WIDTH-1:0]  m_mem_p_axis_write_data_tkeep,
    output  wire [PORT_NUM-1:0]                  m_mem_p_axis_write_data_tvalid,
    input   wire [PORT_NUM-1:0]                  m_mem_p_axis_write_data_tready,
    output  reg  [PORT_NUM-1:0]                  m_mem_p_axis_write_data_tlast,
    
    
    /*
     * AXI read descriptor output
     */
    output  reg  [PORT_NUM*AXI_ADDR_WIDTH-1:0]  m_mem_p_axis_read_desc_addr,
    output  reg  [PORT_NUM*LEN_WIDTH-1:0]       m_mem_p_axis_read_desc_len,
    output  reg  [PORT_NUM*TAG_WIDTH-1:0]       m_mem_p_axis_read_desc_tag,
    output  reg  [PORT_NUM-1:0]                 m_mem_p_axis_read_desc_valid,
    input   wire [PORT_NUM-1:0]                 m_mem_p_axis_read_desc_ready,

    /*
     * AXI read descriptor status input
     */
    input wire [PORT_NUM*TAG_WIDTH-1:0]        s_mem_p_axis_read_desc_status_tag,
    input wire [PORT_NUM-1:0]                  s_mem_p_axis_read_desc_status_valid,

    /*
     * AXI stream read data input
     */
    input  wire [PORT_NUM*AXIS_DATA_WIDTH-1:0] s_mem_p_axis_read_data_tdata,
    input  wire [PORT_NUM*AXIS_KEEP_WIDTH-1:0] s_mem_p_axis_read_data_tkeep,
    input  wire [PORT_NUM-1:0]                 s_mem_p_axis_read_data_tvalid,
    output wire [PORT_NUM-1:0]                 s_mem_p_axis_read_data_tready,
    input  wire [PORT_NUM-1:0]                 s_mem_p_axis_read_data_tlast,

    
    /*
    * Crossbar port  interface input
    */
    input  wire [PORT_NUM*SWITCH_DATA_WIDTH-1:0]     s_switch_p_axis_tdata,
    input  wire [PORT_NUM*SWITCH_KEEP_WIDTH-1:0]     s_switch_p_axis_tkeep,
    input  wire [PORT_NUM-1:0]                       s_switch_p_axis_tvalid,
    output wire [PORT_NUM-1:0]                       s_switch_p_axis_tready,
    input  wire [PORT_NUM-1:0]                       s_switch_p_axis_tlast,
    input  wire [PORT_NUM*SWITCH_DEST_WIDTH-1:0]     s_switch_p_axis_tdest,
    input  wire [PORT_NUM*SWITCH_USER_WIDTH-1:0]     s_switch_p_axis_tuser,


    /*
    * Crossbar  port  interface output
    */
    output  reg [PORT_NUM*SWITCH_DATA_WIDTH-1:0]     m_switch_p_axis_tdata,
    output  reg [PORT_NUM*SWITCH_KEEP_WIDTH-1:0]     m_switch_p_axis_tkeep,
    output  reg [PORT_NUM-1:0]                       m_switch_p_axis_tvalid,
    input   wire[PORT_NUM-1:0]                       m_switch_p_axis_tready,
    output  reg [PORT_NUM-1:0]                       m_switch_p_axis_tlast,
    output  reg [PORT_NUM*SWITCH_DEST_WIDTH-1:0]     m_switch_p_axis_tdest,
    output  reg [PORT_NUM*SWITCH_USER_WIDTH-1:0]     m_switch_p_axis_tuser,


    // Credit interface

    input  wire [SWITCH_DATA_WIDTH-1:0]     s_credit_p_axis_tdata,
    input  wire                             s_credit_p_axis_tvalid,
    output wire                             s_credit_p_axis_tready,
    input  wire                             s_credit_p_axis_tlast,



    input   wire                                            alloc_mem_intense,
    /* Memory Allocator Interface*/
    output  reg                                             free_mem_req,
    input   wire                                            free_mem_ready,
    output  reg [LEN_WIDTH - 1 : 0]                         free_mem_size,
    output  reg                                             free_bank_id,
    // output  reg [FREE_PORT_NUM * AXI_ADDR_WIDTH -1 : 0]     free_mem_addr
    output  reg [CELL_ID_WIDTH - 1 : 0]                     free_cell_id,

    input wire  [ENGINE_NUM*2 -1 :0]                        credit_control
    
);

// flatten the input port
wire                              s_pifo_in_port_arb_ready  [PORT_NUM-1 : 0];
reg                               s_pifo_in_port_arb_valid  [PORT_NUM-1 : 0];
reg [`PANIC_DESC_PRIO_SIZE-1:0]   s_pifo_in_port_arb_prio   [PORT_NUM-1 : 0];
reg [`PANIC_DESC_WIDTH-1:0]       s_pifo_in_port_arb_data   [PORT_NUM-1 : 0];

reg                               m_pifo_in_port_arb_ready;
wire                              m_pifo_in_port_arb_valid;
wire [`PANIC_DESC_PRIO_SIZE-1:0]  m_pifo_in_port_arb_prio ;
wire [`PANIC_DESC_WIDTH-1:0]      m_pifo_in_port_arb_data ;

wire                              s_pifo_in_fifo_ready    [1:0];
reg                               s_pifo_in_fifo_valid    [1:0];
reg [`PANIC_DESC_PRIO_SIZE-1:0]   s_pifo_in_fifo_prio     [1:0];
reg [`PANIC_DESC_WIDTH-1:0]       s_pifo_in_fifo_data     [1:0];

wire                              pifo_in_ready      [1:0];
wire                              pifo_in_valid      [1:0];
wire [`PANIC_DESC_PRIO_SIZE-1:0]  pifo_in_prio       [1:0];
wire [`PANIC_DESC_WIDTH-1:0]      pifo_in_data       [1:0];

reg                               pifo_out_ready      [1:0];
wire                              pifo_out_valid      [1:0];
wire [`PANIC_DESC_PRIO_SIZE-1:0]  pifo_out_prio       [1:0];
wire [`PANIC_DESC_WIDTH-1:0]      pifo_out_data       [1:0];


wire                              pifo_out_drop_valid [1:0];
wire [`PANIC_DESC_PRIO_SIZE-1:0]  pifo_out_drop_prio  [1:0];
wire [`PANIC_DESC_WIDTH-1:0]      pifo_out_drop_data  [1:0];
wire                              pifo_out_drop_ready  [1:0];

wire                              m_pifo_drop_fifo_valid [1:0];
wire [`PANIC_DESC_PRIO_SIZE-1:0]  m_pifo_drop_fifo_prio  [1:0];
wire [`PANIC_DESC_WIDTH-1:0]      m_pifo_drop_fifo_data  [1:0];
wire                              m_pifo_drop_fifo_ready [1:0];

wire                              arb_pifo_drop_fifo_valid ;
wire [`PANIC_DESC_PRIO_SIZE-1:0]  arb_pifo_drop_fifo_prio  ; 
wire [`PANIC_DESC_WIDTH-1:0]      arb_pifo_drop_fifo_data  ; 
wire                              arb_pifo_drop_fifo_ready ;

wire                              s_pifo_out_fifo_ready;
reg                               s_pifo_out_fifo_valid;
reg [`PANIC_DESC_PRIO_SIZE-1:0]   s_pifo_out_fifo_prio;  
reg [`PANIC_DESC_WIDTH-1:0]       s_pifo_out_fifo_data;  
reg [3:0]                         s_pifo_out_fifo_select;

wire                              m_pifo_out_fifo_ready;
wire                              m_pifo_out_fifo_valid;
wire [`PANIC_DESC_PRIO_SIZE-1:0]  m_pifo_out_fifo_prio;  
wire [`PANIC_DESC_WIDTH-1:0]      m_pifo_out_fifo_data;  
wire [3:0]                        m_pifo_out_fifo_select;  

reg  [`PANIC_DESC_WIDTH-1:0]     m_pifo_out_fifo_data_clear;  // clear the drop mem bit



always @* begin
    m_pifo_out_fifo_data_clear = m_pifo_out_fifo_data;
    // m_pifo_out_fifo_data_clear[`PANIC_DESC_INTENSE_OF] = 0;
    m_pifo_out_fifo_data_clear[`PANIC_DESC_CHAIN_OF +: `PANIC_DESC_CHAIN_ITEM_SIZE] = m_pifo_out_fifo_select;
end


generate
    genvar pc;
    for(pc = 0; pc < 2; pc = pc + 1) begin: pifo_array // generate pifo array with 2 pifo
        // priority queue
        pifo_warp #(
            .NUMPIFO    (NUMPIFO),
            .BITPORT    (1),
            .BITPRIO    (`PANIC_DESC_PRIO_SIZE),
            .BITDESC    (`PANIC_DESC_WIDTH),
            .PIFO_ID    (pc),
            .SMALL_PK_OPT (SMALL_PK_OPT)
        ) pf_inst (
            .clk                                (clk),
            .rst                                (rst),

            .pifo_in_ready                      (pifo_in_ready[pc]),
            .pifo_in_valid                      (pifo_in_valid[pc]),
            .pifo_in_prio                       (pifo_in_prio[pc]), 
            .pifo_in_data                       (pifo_in_data[pc]), 
            .pifo_in_drop                       (alloc_mem_intense),


            .pifo_out_ready                      (pifo_out_ready[pc]),
            .pifo_out_valid                      (pifo_out_valid[pc]),
            .pifo_out_prio                       (pifo_out_prio[pc]), 
            .pifo_out_data                       (pifo_out_data[pc]),

            .pifo_out_drop_valid                 (pifo_out_drop_valid[pc]),
            .pifo_out_drop_prio                  (pifo_out_drop_prio[pc]), 
            .pifo_out_drop_data                  (pifo_out_drop_data[pc])
        );

        // small fifo for pifo input
        axis_fifo #(
            .DEPTH(4),
            .DATA_WIDTH(`PANIC_DESC_WIDTH + `PANIC_DESC_PRIO_SIZE),
            .KEEP_ENABLE(0),
            .LAST_ENABLE(0),
            .ID_ENABLE(0),
            .DEST_ENABLE(0),
            .USER_ENABLE(0),
            .FRAME_FIFO(0)
        )
        pifo_in_fifo (
            .clk(clk),
            .rst(rst),

            // AXI input
            .s_axis_tdata({s_pifo_in_fifo_prio[pc],s_pifo_in_fifo_data[pc]}),
            .s_axis_tvalid(s_pifo_in_fifo_valid[pc]),
            .s_axis_tready(s_pifo_in_fifo_ready[pc]),

            // AXI output
            .m_axis_tdata({pifo_in_prio[pc],pifo_in_data[pc]}),
            .m_axis_tvalid(pifo_in_valid[pc]),
            .m_axis_tready(pifo_in_ready[pc])
        );

        // small fifo for pifo drop
        axis_fifo #(
            .DEPTH(4),
            .DATA_WIDTH(`PANIC_DESC_WIDTH + `PANIC_DESC_PRIO_SIZE),
            .KEEP_ENABLE(0),
            .LAST_ENABLE(0),
            .ID_ENABLE(0),
            .DEST_ENABLE(0),
            .USER_ENABLE(0),
            .FRAME_FIFO(0)
        )
        pifo_drop_fifo (
            .clk(clk),
            .rst(rst),

            // AXI input
            .s_axis_tdata({pifo_out_drop_prio[pc],pifo_out_drop_data[pc]}),
            .s_axis_tvalid(pifo_out_drop_valid[pc]),
            .s_axis_tready(pifo_out_drop_ready[pc]),

            // AXI output
            .m_axis_tdata({m_pifo_drop_fifo_prio[pc],m_pifo_drop_fifo_data[pc]}),
            .m_axis_tvalid(m_pifo_drop_fifo_valid[pc]),
            .m_axis_tready(m_pifo_drop_fifo_ready[pc])

        );
    end
endgenerate



// small fifo for pifo output
axis_fifo #(
    .DEPTH(2),
    .DATA_WIDTH(`PANIC_DESC_WIDTH + `PANIC_DESC_PRIO_SIZE + 4),
    .KEEP_ENABLE(0),
    .LAST_ENABLE(0),
    .ID_ENABLE(0),
    .DEST_ENABLE(0),
    .USER_ENABLE(0),
    .FRAME_FIFO(0)
)
pifo_out_fifo (
    .clk(clk),
    .rst(rst),

    // AXI input
    .s_axis_tdata({s_pifo_out_fifo_prio,s_pifo_out_fifo_data,s_pifo_out_fifo_select}),
    .s_axis_tvalid(s_pifo_out_fifo_valid),
    .s_axis_tready(s_pifo_out_fifo_ready),

    // AXI output
    .m_axis_tdata({m_pifo_out_fifo_prio,m_pifo_out_fifo_data,m_pifo_out_fifo_select}),
    .m_axis_tvalid(m_pifo_out_fifo_valid),
    .m_axis_tready(m_pifo_out_fifo_ready)

);


// arbiter logic for 2 port pifo
// input logic
always @* begin

    s_pifo_in_fifo_valid[0] = 0;
    s_pifo_in_fifo_valid[1] = 0;

    s_pifo_in_fifo_prio[0] = m_pifo_in_port_arb_prio;  
    s_pifo_in_fifo_prio[1] = m_pifo_in_port_arb_prio; 

    s_pifo_in_fifo_data[0] = m_pifo_in_port_arb_data;  
    s_pifo_in_fifo_data[1] = m_pifo_in_port_arb_data;  

    if(TEST_MODE == 0 ) begin
        if(m_pifo_in_port_arb_valid && s_pifo_in_fifo_ready[0] && m_pifo_in_port_arb_data[`PANIC_DESC_CHAIN_OF +: `PANIC_DESC_CHAIN_ITEM_SIZE] <= 5) begin // service 1 goto pifo 0
            s_pifo_in_fifo_valid[0] = 1;
            m_pifo_in_port_arb_ready = 1;
        end
        else if (m_pifo_in_port_arb_valid && s_pifo_in_fifo_ready[1] && m_pifo_in_port_arb_data[`PANIC_DESC_CHAIN_OF +: `PANIC_DESC_CHAIN_ITEM_SIZE] >= 6) begin // service 2 go to pifo 1
            s_pifo_in_fifo_valid[1] = 1;
            m_pifo_in_port_arb_ready = 1;
        end
    end
    else begin
        if(m_pifo_in_port_arb_valid && s_pifo_in_fifo_ready[0] ) begin // all goto pifo 0
            s_pifo_in_fifo_valid[0] = 1;
            m_pifo_in_port_arb_ready = 1;
        end
    end

end

// select logic for 2 port pifo drop
axis_arb_mux  #(
    .S_COUNT(2),
    .DATA_WIDTH(`PANIC_DESC_WIDTH + `PANIC_DESC_PRIO_SIZE),
    .KEEP_ENABLE(0),
    .USER_ENABLE(0),
    .ID_ENABLE(0),
    .DEST_ENABLE(0)
)
pifo_drop_arb (
    .clk(clk),
    .rst(rst),
    // AXI inputs
    .s_axis_tdata({{m_pifo_drop_fifo_data[0],m_pifo_drop_fifo_prio[0]}, {m_pifo_drop_fifo_data[1],m_pifo_drop_fifo_prio[1]}}),
    .s_axis_tvalid({m_pifo_drop_fifo_valid[0], m_pifo_drop_fifo_valid[1]}),
    .s_axis_tready({m_pifo_drop_fifo_ready[0], m_pifo_drop_fifo_ready[1]}),
    .s_axis_tlast({{1'b1},{1'b1}}),

    // AXI output
    .m_axis_tdata({arb_pifo_drop_fifo_data,arb_pifo_drop_fifo_prio}),
    .m_axis_tvalid(arb_pifo_drop_fifo_valid),
    .m_axis_tready(arb_pifo_drop_fifo_ready)
);
assign arb_pifo_drop_fifo_ready = 1;

always@*begin
    s_pifo_out_fifo_data = 0;
    s_pifo_out_fifo_prio = 0;
    s_pifo_out_fifo_select = 0;
    s_pifo_out_fifo_valid = 0;
    pifo_out_ready[1] = 0;
    pifo_out_ready[0] = 0;

    if(pifo_out_valid[1]&&(max_credit[1]>0)) begin
        s_pifo_out_fifo_data = pifo_out_data[1];
        s_pifo_out_fifo_prio = pifo_out_prio[1];
        s_pifo_out_fifo_select = selected_engine[1];
        s_pifo_out_fifo_valid = 1;
        pifo_out_ready[1] = 1;
    end
    else if(pifo_out_valid[0]&&(max_credit[0]>0)) begin
        s_pifo_out_fifo_data = pifo_out_data[0];
        s_pifo_out_fifo_prio = pifo_out_prio[0];
        s_pifo_out_fifo_select = selected_engine[0];
        s_pifo_out_fifo_valid = 1;
        pifo_out_ready[0] = 1;
    end
end


// free memory request when pifo drop
always @* begin
    free_mem_req = arb_pifo_drop_fifo_valid;
    // free_mem_addr[ 1 * AXI_ADDR_WIDTH +: AXI_ADDR_WIDTH ]  = pifo_out_drop_data[`PANIC_DESC_ADDR_OF   +: `PANIC_DESC_ADDR_SIZE];
    free_cell_id  = arb_pifo_drop_fifo_data[`PANIC_DESC_CELL_ID_OF   +: `PANIC_DESC_CELL_ID_SIZE];
    free_mem_size  = arb_pifo_drop_fifo_data[`PANIC_DESC_LEN_OF   +: `PANIC_DESC_LEN_SIZE];
    free_bank_id = arb_pifo_drop_fifo_data[`PANIC_DESC_PORT_OF];
end

always @* begin
    if(!free_mem_ready)
        $display("ERROR! free_mem_ready in scheduler is not ready.");
    if(!rst && (!pifo_out_drop_ready[0] || !pifo_out_drop_ready[1]) )
        $display("ERROR! cannot drop at such high speed??");
end

axis_arb_mux  #(
    .S_COUNT(2),
    .DATA_WIDTH(`PANIC_DESC_WIDTH + `PANIC_DESC_PRIO_SIZE),
    .KEEP_ENABLE(0),
    .USER_ENABLE(0),
    .ID_ENABLE(0),
    .DEST_ENABLE(0)
)
pifo_in_arb (
    .clk(clk),
    .rst(rst),
    // AXI inputs
    .s_axis_tdata({{s_pifo_in_port_arb_data[0],s_pifo_in_port_arb_prio[0]}, {s_pifo_in_port_arb_data[1],s_pifo_in_port_arb_prio[1]}}),
    .s_axis_tvalid({s_pifo_in_port_arb_valid[0], s_pifo_in_port_arb_valid[1]}),
    .s_axis_tready({s_pifo_in_port_arb_ready[0], s_pifo_in_port_arb_ready[1]}),
    .s_axis_tlast({{1'b1},{1'b1}}),

    // AXI output
    .m_axis_tdata({m_pifo_in_port_arb_data,m_pifo_in_port_arb_prio}),
    .m_axis_tvalid(m_pifo_in_port_arb_valid),
    .m_axis_tready(m_pifo_in_port_arb_ready)
);

// select unit with maximum credit number

wire [3:0] selected_engine [1:0]; // 2 port pifo

integer wk1, wk2;

reg [3:0] max_engine [1:0];
reg [3:0] max_credit [1:0];
assign selected_engine[0] = max_engine[0];
assign selected_engine[1] = max_engine[1];
always @* begin
    max_credit[0] = 0;
    max_credit[1] = 0;
    max_engine[0] = 4;
    max_engine[1] = 6;

    if(TEST_MODE == 0) begin
        // [SHA TAG] --
        if(pifo_out_data[0][`PANIC_DESC_CHAIN_OF +: `PANIC_DESC_CHAIN_ITEM_SIZE] == 4 || pifo_out_data[0][`PANIC_DESC_CHAIN_OF +: `PANIC_DESC_CHAIN_ITEM_SIZE] == 5) begin
            max_engine[0] = 4;
            for(wk1 = 4; wk1 < 4 + 2 ; wk1 = wk1 + 1 ) begin
                if( credit_regs[wk1] > max_credit[0]) begin
                    max_credit[0] = credit_regs[wk1];
                    max_engine[0] = wk1;
                end
            end
        end

        if(pifo_out_data[1][`PANIC_DESC_CHAIN_OF +: `PANIC_DESC_CHAIN_ITEM_SIZE] == 6 || pifo_out_data[1][`PANIC_DESC_CHAIN_OF +: `PANIC_DESC_CHAIN_ITEM_SIZE] ==7) begin // it is the second offload service
            max_engine[1] = 6;
            for(wk2 = 6; wk2 < 6 + 2 ; wk2 = wk2 + 1 ) begin
                if( credit_regs[wk2] > max_credit[1]) begin
                    max_credit[1] = credit_regs[wk2];
                    max_engine[1] = wk2;
                end
            end
        end
        // [SHA TAG] --
    end
    else begin
        max_engine[0] = 4;
        for(wk1 = 4; wk1 < 4 + 3 ; wk1 = wk1 + 1 ) begin
            if( credit_regs[wk1] > max_credit[0]) begin
                max_credit[0] = credit_regs[wk1];
                max_engine[0] = wk1;
            end
        end
    end
end


//need prepost ready signal
assign m_pifo_out_fifo_ready = (pifo_out_ready_array[0] && m_pifo_out_fifo_data[`PANIC_DESC_PORT_OF] == 0) || (pifo_out_ready_array[1] && m_pifo_out_fifo_data[`PANIC_DESC_PORT_OF] == 1) ;

wire  pifo_out_ready_array  [PORT_NUM-1 : 0];

// switch input port generator
generate
    genvar op;

    for(op = 0; op < PORT_NUM; op = op + 1) begin: noc_output
        always @* begin
            // pifo_out_ready_reg = 0;
            // selected_engine = 0;
            m_mem_p_axis_read_desc_valid[op] = 0;
            m_mem_p_axis_read_desc_addr[op*AXI_ADDR_WIDTH +: AXI_ADDR_WIDTH] = 0;
            m_mem_p_axis_read_desc_len[op*LEN_WIDTH +: LEN_WIDTH] = 0;
            m_mem_p_axis_read_desc_tag[op*TAG_WIDTH +: TAG_WIDTH] = 0;
            if(m_pifo_out_fifo_valid && m_pifo_out_fifo_ready && (m_pifo_out_fifo_data[`PANIC_DESC_PORT_OF] == op) ) begin
                // read descriptor from the pifo
                // pifo_out_ready_reg = 1; 
                // TODO: select from multiple engine, need modify this value

                // generate data buffer read descriptor
                m_mem_p_axis_read_desc_addr[op*AXI_ADDR_WIDTH +: AXI_ADDR_WIDTH] = m_pifo_out_fifo_data[`PANIC_DESC_CELL_ID_OF  +: `PANIC_DESC_CELL_ID_SIZE] * `PANIC_CELL_SIZE;
                m_mem_p_axis_read_desc_len[op*LEN_WIDTH +: LEN_WIDTH] = m_pifo_out_fifo_data[`PANIC_DESC_LEN_OF   +: `PANIC_DESC_LEN_SIZE];
                m_mem_p_axis_read_desc_tag[op*TAG_WIDTH +: TAG_WIDTH] = 0;
                m_mem_p_axis_read_desc_valid[op] = 1;
                // use the read descriptor to generate corssbar packet 
            end

        end

            
        wire                                 s_crossbar_desc_fifo_ready;
        wire [`PANIC_DESC_WIDTH-1:0]         m_crossbar_desc_fifo_tdata;
        wire                                 m_crossbar_desc_fifo_tvalid;
        wire                                 m_crossbar_desc_fifo_tready;
        reg                                  m_crossbar_desc_fifo_tready_reg;
        
        assign pifo_out_ready_array[op] = m_mem_p_axis_read_desc_ready[op] && s_crossbar_desc_fifo_ready;

        assign  m_crossbar_desc_fifo_tready = m_crossbar_desc_fifo_tready_reg;
        //descriptor fifo, size need > 5, inorder to pipeline the ram read cycle
        axis_fifo #(
            .DEPTH(8),
            .DATA_WIDTH(`PANIC_DESC_WIDTH),
            .KEEP_ENABLE(0),
            .LAST_ENABLE(0),
            .USER_ENABLE(0),
            .ID_ENABLE(0),
            .DEST_ENABLE(0),
            .FRAME_FIFO(0)
        )
        crossbar_desc_fifo (
            .clk(clk),
            .rst(rst),

            // AXI input
            .s_axis_tdata(m_pifo_out_fifo_data_clear),
            .s_axis_tvalid(m_mem_p_axis_read_desc_valid[op]),
            .s_axis_tready(s_crossbar_desc_fifo_ready),

            // AXI output
            .m_axis_tdata(m_crossbar_desc_fifo_tdata),
            .m_axis_tvalid(m_crossbar_desc_fifo_tvalid),
            .m_axis_tready(m_crossbar_desc_fifo_tready)

        );


        wire [AXIS_DATA_WIDTH-1:0]           m_crossbar_data_fifo_tdata;
        wire [AXIS_KEEP_WIDTH-1:0]           m_crossbar_data_fifo_tkeep;
        wire                                 m_crossbar_data_fifo_tvalid;
        wire                                 m_crossbar_data_fifo_tready;
        reg                                  m_crossbar_data_fifo_tready_reg;
        wire                                 m_crossbar_data_fifo_tlast;

        assign m_crossbar_data_fifo_tready = m_crossbar_data_fifo_tready_reg;

        // small sending data buffer for crossbar, we assume that corssbar has fast throughput
        axis_fifo #(
            .DEPTH(8 * AXIS_KEEP_WIDTH),
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
        crossbar_data_fifo (
            .clk(clk),
            .rst(rst),

            // AXI input
            .s_axis_tdata(s_mem_p_axis_read_data_tdata[op*AXIS_DATA_WIDTH +: AXIS_DATA_WIDTH]),
            .s_axis_tkeep(s_mem_p_axis_read_data_tkeep[op*AXIS_KEEP_WIDTH +: AXIS_KEEP_WIDTH]),
            .s_axis_tvalid(s_mem_p_axis_read_data_tvalid[op]),
            .s_axis_tready(s_mem_p_axis_read_data_tready[op]),
            .s_axis_tlast(s_mem_p_axis_read_data_tlast[op]),

            // AXI output
            .m_axis_tdata(m_crossbar_data_fifo_tdata),
            .m_axis_tkeep(m_crossbar_data_fifo_tkeep),
            .m_axis_tvalid(m_crossbar_data_fifo_tvalid),
            .m_axis_tready(m_crossbar_data_fifo_tready),
            .m_axis_tlast(m_crossbar_data_fifo_tlast)
        );

        // combine the packet descriptor and the packet data into a single crossbar message
        reg [2:0] switch_write_state;
        reg [SWITCH_DEST_WIDTH-1:0] switch_dest_reg;
        // localparam SWITCH_WRITE_INIT    = 0;
        localparam SWITCH_WRITE_DESC    = 1;
        localparam SWITCH_WRITE_DATA    = 2;

        always @(posedge clk) begin
        if(rst) begin
                switch_write_state <= SWITCH_WRITE_DESC;
                switch_dest_reg <= 0;
        end
        else begin
                case (switch_write_state)
                    SWITCH_WRITE_DESC: begin
                        if(m_crossbar_desc_fifo_tvalid && m_crossbar_desc_fifo_tready) begin
                            switch_write_state <= SWITCH_WRITE_DATA;
                            // switch_dest_reg <= 1;
                            switch_dest_reg <= m_crossbar_desc_fifo_tdata[`PANIC_DESC_CHAIN_OF  +: `PANIC_DESC_CHAIN_ITEM_SIZE];
                            // if(m_crossbar_desc_fifo_tdata[`PANIC_DESC_FLOW_OF +: `PANIC_DESC_FLOW_SIZE] == 0 && m_crossbar_desc_fifo_tdata[`PANIC_DESC_PRIO_OF  +: `PANIC_DESC_PRIO_SIZE] < 9)
                            // $display("From sche: flow %d, to node %d", m_crossbar_desc_fifo_tdata[`PANIC_DESC_FLOW_OF +: `PANIC_DESC_FLOW_SIZE] ,m_crossbar_desc_fifo_tdata[`PANIC_DESC_CHAIN_OF  +: `PANIC_DESC_CHAIN_ITEM_SIZE]);
                        end
                    end
                    SWITCH_WRITE_DATA: begin
                        if(m_crossbar_data_fifo_tlast && m_crossbar_data_fifo_tvalid && m_crossbar_data_fifo_tready) begin
                            switch_write_state <= SWITCH_WRITE_DESC;
                        end
                    end
                    
                endcase
        end

        end

        always @(*) begin
            m_crossbar_desc_fifo_tready_reg = 0;
            m_crossbar_data_fifo_tready_reg = 0;
            m_switch_p_axis_tvalid[op] = 0;
            m_switch_p_axis_tdata[op*SWITCH_DATA_WIDTH +: SWITCH_DATA_WIDTH] = 0;
            m_switch_p_axis_tlast[op] = 0;
            m_switch_p_axis_tkeep[op*SWITCH_KEEP_WIDTH +: SWITCH_KEEP_WIDTH] = 0;
            m_switch_p_axis_tdest[op*SWITCH_DEST_WIDTH +: SWITCH_DEST_WIDTH]  = 0;
            m_switch_p_axis_tuser[op*SWITCH_USER_WIDTH +: SWITCH_USER_WIDTH] = 0;
            if(switch_write_state == SWITCH_WRITE_DESC) begin
                if(m_crossbar_desc_fifo_tvalid && m_switch_p_axis_tready[op] ) begin //(gurantee no deassert need  && m_crossbar_data_fifo_tvalid) this may effect small packet performance
                    m_crossbar_desc_fifo_tready_reg = 1;

                    // fill the crossbar input
                    m_switch_p_axis_tvalid[op] = 1;
                    m_switch_p_axis_tdata[op*SWITCH_DATA_WIDTH +: SWITCH_DATA_WIDTH] = {{(SWITCH_DATA_WIDTH - `PANIC_DESC_WIDTH){1'd0}},m_crossbar_desc_fifo_tdata};
                    m_switch_p_axis_tlast[op] = 0;
                    m_switch_p_axis_tdest[op*SWITCH_DEST_WIDTH +: SWITCH_DEST_WIDTH] = m_crossbar_desc_fifo_tdata[`PANIC_DESC_CHAIN_OF  +: `PANIC_DESC_CHAIN_ITEM_SIZE];  // choose the first element of this chain
                    m_switch_p_axis_tuser[op*SWITCH_USER_WIDTH +: SWITCH_USER_WIDTH] = 1;        // 1 means this packet is from the scheduler
                    m_switch_p_axis_tkeep[op*SWITCH_KEEP_WIDTH +: SWITCH_KEEP_WIDTH] = {{(SWITCH_DATA_WIDTH - `PANIC_DESC_WIDTH)/8{1'd0}},{`PANIC_DESC_WIDTH/8{1'd1}}};
                end
            end
            else if (switch_write_state == SWITCH_WRITE_DATA) begin
                if(m_crossbar_data_fifo_tvalid && m_switch_p_axis_tready[op]) begin
                    m_crossbar_data_fifo_tready_reg = 1;

                    //fill the crossbar input
                    m_switch_p_axis_tvalid[op] = 1;
                    m_switch_p_axis_tdata[op*SWITCH_DATA_WIDTH +: SWITCH_DATA_WIDTH] = m_crossbar_data_fifo_tdata;
                    m_switch_p_axis_tlast[op] = m_crossbar_data_fifo_tlast;
                    m_switch_p_axis_tdest[op*SWITCH_DEST_WIDTH +: SWITCH_DEST_WIDTH] = switch_dest_reg;
                    m_switch_p_axis_tuser[op*SWITCH_USER_WIDTH +: SWITCH_USER_WIDTH] = 1;
                    m_switch_p_axis_tkeep[op*SWITCH_KEEP_WIDTH +: SWITCH_KEEP_WIDTH] = m_crossbar_data_fifo_tkeep;
                end
            end
        end
    end

endgenerate

// switch input port generator
generate
    genvar sp;

    for(sp = 0; sp < PORT_NUM; sp = sp + 1) begin: noc_input
        reg [AXIS_DATA_WIDTH-1:0]           s_detour_data_fifo_tdata;
        reg [AXIS_KEEP_WIDTH-1:0]           s_detour_data_fifo_tkeep;
        reg                                 s_detour_data_fifo_tvalid;
        wire                                s_detour_data_fifo_tready;
        reg                                 s_detour_data_fifo_tlast;

        wire [AXIS_DATA_WIDTH-1:0]           m_detour_data_fifo_tdata;
        wire [AXIS_KEEP_WIDTH-1:0]           m_detour_data_fifo_tkeep;
        wire                                 m_detour_data_fifo_tvalid;
        wire                                 m_detour_data_fifo_tready;
        wire                                 m_detour_data_fifo_tlast;
        reg                                  m_detour_data_fifo_tready_reg;

        reg                                 selected_switch_axis_tready;
        wire                                 selected_switch_axis_tvalid;
        // if is credit, will not go into the fifo

        if(sp == 0) begin
            assign  s_switch_p_axis_tready[sp] = selected_switch_axis_tready || ( s_switch_p_axis_tvalid[sp] && s_switch_p_axis_tuser[sp*SWITCH_USER_WIDTH +: SWITCH_USER_WIDTH] ); 
            assign  selected_switch_axis_tvalid = s_switch_p_axis_tvalid[sp] && (s_switch_p_axis_tuser[sp*SWITCH_USER_WIDTH +: SWITCH_USER_WIDTH] == 0);
            assign  m_detour_data_fifo_tready = m_detour_data_fifo_tready_reg;
        end
        else begin
            assign  s_switch_p_axis_tready[sp] = selected_switch_axis_tready ; 
            assign  selected_switch_axis_tvalid = s_switch_p_axis_tvalid[sp];
            assign  m_detour_data_fifo_tready = m_detour_data_fifo_tready_reg;
        end

        always @ * begin
            s_detour_data_fifo_tdata = s_switch_p_axis_tdata[sp*SWITCH_DATA_WIDTH +: SWITCH_DATA_WIDTH];
            s_detour_data_fifo_tkeep = s_switch_p_axis_tkeep[sp*SWITCH_KEEP_WIDTH +: SWITCH_KEEP_WIDTH];
            s_detour_data_fifo_tvalid = selected_switch_axis_tvalid;
            selected_switch_axis_tready = s_detour_data_fifo_tready;
            s_detour_data_fifo_tlast = s_switch_p_axis_tlast[sp];
        end


        axis_fifo #(
            .DEPTH(24 * AXIS_KEEP_WIDTH),
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
        detour_data_fifo (
            .clk(clk),
            .rst(rst),

            // AXI input
            .s_axis_tdata(s_detour_data_fifo_tdata),
            .s_axis_tkeep(s_detour_data_fifo_tkeep),
            .s_axis_tvalid(s_detour_data_fifo_tvalid),
            .s_axis_tready(s_detour_data_fifo_tready),
            .s_axis_tlast(s_detour_data_fifo_tlast),

            // AXI output
            .m_axis_tdata(m_detour_data_fifo_tdata),
            .m_axis_tkeep(m_detour_data_fifo_tkeep),
            .m_axis_tvalid(m_detour_data_fifo_tvalid),
            .m_axis_tready(m_detour_data_fifo_tready),
            .m_axis_tlast(m_detour_data_fifo_tlast)
        );

        // new mem writer
        reg [2:0] scheduler_write_state;

        localparam SCHE_STATE_WRITE_BUFFER_DESC    = 1;
        localparam SCHE_STATE_WRITE_BUFFER_DATA    = 2;
        localparam SCHE_STATE_DROP_DATA            = 3;
        localparam SCHE_STATE_FIN_PACKET           = 4;

        assign m_mem_p_axis_write_data_tvalid[sp] = m_detour_data_fifo_tvalid && (scheduler_write_state == SCHE_STATE_WRITE_BUFFER_DATA);

        always @(posedge clk) begin
            if (rst) begin
                scheduler_write_state <= SCHE_STATE_WRITE_BUFFER_DESC;
            end
            else begin
                case (scheduler_write_state)

                    SCHE_STATE_WRITE_BUFFER_DESC: begin
                        if(m_detour_data_fifo_tvalid && m_detour_data_fifo_tready) begin
                            if(m_detour_data_fifo_tdata[`PANIC_DESC_DROP_OF]) begin
                                scheduler_write_state <= SCHE_STATE_DROP_DATA;
                                $display("ERRORRR DROP from buffer %d",m_detour_data_fifo_tdata[`PANIC_DESC_PRIO_OF  +: `PANIC_DESC_PRIO_SIZE]);
                            end
                            else if(m_detour_data_fifo_tdata[`PANIC_DESC_CHAIN_OF +: `PANIC_DESC_CHAIN_SIZE] == 0) begin
                                scheduler_write_state <= SCHE_STATE_FIN_PACKET;
                                $display("ERRORRR FIN from buffer ");
                            end
                            else begin
                                scheduler_write_state <= SCHE_STATE_WRITE_BUFFER_DATA;
                            end
                            
                        end
                    end
                    SCHE_STATE_WRITE_BUFFER_DATA:begin
                        if(m_detour_data_fifo_tvalid && m_detour_data_fifo_tready && m_detour_data_fifo_tlast) begin
                            scheduler_write_state <= SCHE_STATE_WRITE_BUFFER_DESC; 
                        end
                    end
                    SCHE_STATE_DROP_DATA:begin
                        if(m_detour_data_fifo_tvalid && m_detour_data_fifo_tready && m_detour_data_fifo_tlast) begin
                        scheduler_write_state <= SCHE_STATE_WRITE_BUFFER_DESC; 
                        end
                    end
                    SCHE_STATE_FIN_PACKET: begin
                        if(m_detour_data_fifo_tvalid && m_detour_data_fifo_tready && m_detour_data_fifo_tlast) begin
                            scheduler_write_state <= SCHE_STATE_WRITE_BUFFER_DESC;
                        end

                    end

                endcase
            
            end
        end

        /*buffer write comb logic*/
        always @* begin
            m_detour_data_fifo_tready_reg = 0;
            m_mem_p_axis_write_desc_valid[sp] = 0;
            m_mem_p_axis_write_desc_addr[sp*AXI_ADDR_WIDTH +: AXI_ADDR_WIDTH] = 0;
            m_mem_p_axis_write_desc_len[sp*LEN_WIDTH +: LEN_WIDTH] = 0;
            m_mem_p_axis_write_desc_tag[sp*TAG_WIDTH +: TAG_WIDTH] = 0;

            m_mem_p_axis_write_data_tdata[sp*AXIS_DATA_WIDTH +: AXIS_DATA_WIDTH] = 0;
            m_mem_p_axis_write_data_tkeep[sp*AXIS_KEEP_WIDTH +: AXIS_KEEP_WIDTH] = 0;
            m_mem_p_axis_write_data_tlast[sp] = 0;

            s_pifo_in_port_arb_valid[sp] = 0;
            s_pifo_in_port_arb_data[sp] = 0;
            s_pifo_in_port_arb_prio[sp] = 0;

            if(scheduler_write_state == SCHE_STATE_WRITE_BUFFER_DESC) begin
                if(m_detour_data_fifo_tvalid && m_mem_p_axis_write_desc_ready[sp] ) begin
                    // if finish packet
                    if(m_detour_data_fifo_tdata[`PANIC_DESC_CHAIN_OF +: `PANIC_DESC_CHAIN_SIZE] == 0) begin
                        m_detour_data_fifo_tready_reg = 1;
                        $display("Error happens in the NIC chain in scheduler 1");
                    end
                    else if (m_detour_data_fifo_tdata[`PANIC_DESC_DROP_OF]) begin
                        m_detour_data_fifo_tready_reg = 1;
                        $display("Error happens in the NIC chain in scheduler 2");
                    end
                    else begin
                        s_pifo_in_port_arb_valid[sp] = 1; // pre post the valid signal
                        if( s_pifo_in_port_arb_ready[sp] ) begin  // if not drop packet
                            m_detour_data_fifo_tready_reg = 1;
                            m_mem_p_axis_write_desc_addr[sp*AXI_ADDR_WIDTH +: AXI_ADDR_WIDTH] = m_detour_data_fifo_tdata[`PANIC_DESC_CELL_ID_OF  +: `PANIC_DESC_CELL_ID_SIZE] * `PANIC_CELL_SIZE;
                            m_mem_p_axis_write_desc_len[sp*LEN_WIDTH +: LEN_WIDTH] = m_detour_data_fifo_tdata[`PANIC_DESC_LEN_OF   +: `PANIC_DESC_LEN_SIZE];
                            m_mem_p_axis_write_desc_tag[sp*TAG_WIDTH +: TAG_WIDTH] = 0;
                            m_mem_p_axis_write_desc_valid[sp] = 1;


                            s_pifo_in_port_arb_valid[sp] = 1;
                            s_pifo_in_port_arb_data[sp] = m_detour_data_fifo_tdata;
                            s_pifo_in_port_arb_data[sp][`PANIC_DESC_PRIO_OF  +: `PANIC_DESC_PRIO_SIZE] = m_detour_data_fifo_tdata[`PANIC_DESC_PRIO_OF  +: `PANIC_DESC_PRIO_SIZE] -1;
                            s_pifo_in_port_arb_prio[sp] = s_pifo_in_port_arb_data[sp][`PANIC_DESC_PRIO_OF   +: `PANIC_DESC_PRIO_SIZE];
                        end

                    end
                    

                end
            end
            else if(scheduler_write_state == SCHE_STATE_WRITE_BUFFER_DATA) begin
                if(m_detour_data_fifo_tvalid && m_mem_p_axis_write_data_tready[sp]) begin
                    m_mem_p_axis_write_data_tdata[sp*AXIS_DATA_WIDTH +: AXIS_DATA_WIDTH] = m_detour_data_fifo_tdata;
                    m_mem_p_axis_write_data_tkeep[sp*AXIS_KEEP_WIDTH +: AXIS_KEEP_WIDTH] = m_detour_data_fifo_tkeep;
                    m_mem_p_axis_write_data_tlast[sp] = m_detour_data_fifo_tlast;

                    // m_mem_axis_write_data_tvalid = 1;
                    m_detour_data_fifo_tready_reg = 1;
                end
            end
        end

    end

endgenerate


/*credit manager*/

// credit regiters

reg [3:0] credit_regs [NODE_NUM-1 : 0];

integer i, init_i1;

wire [SWITCH_DATA_WIDTH-1 : 0] check_credit_data;

assign check_credit_data = s_switch_p_axis_tdata[0  +: SWITCH_DATA_WIDTH];

always @(posedge clk) begin
    if(rst) begin
        for(init_i1 = 0; init_i1 < NODE_NUM; init_i1 = init_i1 + 1)
        begin
            credit_regs[init_i1] <= INIT_CREDIT_NUM;

            if(TEST_MODE == 0) begin
                // [SHA TAG] --
                if(init_i1 == 4 || init_i1 == 5) begin
                    credit_regs[init_i1] <= 4;
                end
                // [SHA TAG] --
            end

        end
        // credit_regs <= INIT_CREDIT_NUM;
    end
    else begin
        // if(s_switch_p_axis_tvalid[0] && s_switch_p_axis_tready[0] &&  s_switch_p_axis_tuser[0*SWITCH_USER_WIDTH +: SWITCH_USER_WIDTH]) begin // credit in
            for(i = 0; i < ENGINE_NUM; i= i + 1) begin
                if(credit_control[i*2]) begin
                    if(TEST_MODE == 0) begin
                        // [SHA TAG] --
                        if(i == 0 || i == 1) begin
                            if(credit_regs[i + ENGINE_OFFSET] <= 4 -1)
                                credit_regs[i + ENGINE_OFFSET] = credit_regs[i + ENGINE_OFFSET] + 1 ;
                        end
                        // [SHA TAG] --
                        else begin
                            if(credit_regs[i + ENGINE_OFFSET] <= INIT_CREDIT_NUM -1)
                                credit_regs[i + ENGINE_OFFSET] = credit_regs[i + ENGINE_OFFSET] + 1 ;
                        end
                    end
                    else begin
                        if(credit_regs[i + ENGINE_OFFSET] <= INIT_CREDIT_NUM -1)
                                credit_regs[i + ENGINE_OFFSET] = credit_regs[i + ENGINE_OFFSET] + 1 ;
                    end
                  
                end
                if(credit_control[i*2 + 1]) begin
                    if(credit_regs[i + ENGINE_OFFSET] >= 1)
                        credit_regs[i + ENGINE_OFFSET] = credit_regs[i + ENGINE_OFFSET] - 1 ;
                end
            end

        if(s_pifo_out_fifo_ready && s_pifo_out_fifo_valid) begin
            if(credit_regs[s_pifo_out_fifo_select] >= 1)
                credit_regs[s_pifo_out_fifo_select] = credit_regs[s_pifo_out_fifo_select] - 1;
        end
    end
end

endmodule