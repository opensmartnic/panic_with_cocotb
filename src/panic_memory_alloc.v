`timescale 1ns / 1ps


module panic_memory_alloc #
(
    // Width of AXI address bus in bits
    // parameter AXI_ADDR_WIDTH = 16,
    parameter LEN_WIDTH = 16,
    parameter CELL_NUM = 64,
    // parameter CELL_SIZE = 512 * 3 * 8,  // in bit
    parameter DROP_THRESH = 2,   // if current free memoey smaller than 2 cell, then drop the pacekt in PIFO
    parameter FREE_PORT_NUM = 2,
    // parameter CELL_ID_WIDTH = (AXI_ADDR_WIDTH - $clog2(CELL_SIZE))
    parameter CELL_ID_WIDTH = $clog2(CELL_NUM)
)
(
    input  wire                             clk,
    input  wire                             rst,

    input  wire                             alloc_mem_req,
    input  wire [LEN_WIDTH - 1 : 0]         alloc_mem_size,
    output reg [CELL_ID_WIDTH - 1 : 0]      alloc_cell_id,
    output reg                              alloc_port_id,
    output reg                              alloc_mem_success,
    output reg                              alloc_mem_intense,

    input  wire [FREE_PORT_NUM -1 : 0]                      free_mem_req,
    output reg  [FREE_PORT_NUM -1 : 0]                      free_mem_ready,
    input  wire [FREE_PORT_NUM * LEN_WIDTH - 1 : 0]         free_mem_size,
    input  wire [FREE_PORT_NUM * CELL_ID_WIDTH - 1 : 0]     free_cell_id,
    input  wire [FREE_PORT_NUM -1 : 0]                      free_bank_id 
    // input  wire [FREE_PORT_NUM * AXI_ADDR_WIDTH -1 : 0]     free_mem_addr

);

reg                              p_alloc_mem_req     [1:0];
reg  [LEN_WIDTH - 1 : 0]         p_alloc_mem_size    [1:0];
wire [CELL_ID_WIDTH -1 : 0]      p_alloc_cell_id     [1:0];
wire                             p_alloc_mem_success [1:0];
wire                             p_alloc_mem_intense [1:0];


// wire for free memory 
wire [FREE_PORT_NUM -1 : 0]                      p_free_mem_ready  [1:0];
reg  [FREE_PORT_NUM -1 : 0]                      p_free_mem_req    [1:0];
reg  [FREE_PORT_NUM * LEN_WIDTH - 1 : 0]         p_free_mem_size   [1:0];     
reg  [FREE_PORT_NUM * CELL_ID_WIDTH - 1 : 0]     p_free_cell_id    [1:0];



reg                      rr_counter;

always @* begin
    alloc_cell_id = 0;
    alloc_port_id = 0;
    alloc_mem_success = 0;
    alloc_mem_intense = p_alloc_mem_intense[0] && p_alloc_mem_intense[1];

    p_alloc_mem_req [0] = 0;
    p_alloc_mem_size [0] = 0;

    p_alloc_mem_req [1] = 0;
    p_alloc_mem_size [1] = 0;

    

    if(alloc_mem_req) begin
        // arbitration
        if(!p_alloc_mem_intense[0] && !p_alloc_mem_intense[1]) begin // both port are valid, use round robin
            alloc_cell_id = p_alloc_cell_id[rr_counter];
            alloc_port_id = rr_counter;
            alloc_mem_success = p_alloc_mem_success[rr_counter];
            p_alloc_mem_req[rr_counter] = alloc_mem_req;
            p_alloc_mem_size[rr_counter] = alloc_mem_size;
            // alloc_mem_intense = p_alloc_mem_intense[rr_counter];
        end
        else if (!p_alloc_mem_intense[0] || !p_alloc_mem_intense[1]) begin // only one port is not intense, go to that port
            if(!p_alloc_mem_intense[0]) begin
                alloc_cell_id = p_alloc_cell_id[0];
                alloc_port_id = 0;
                alloc_mem_success = p_alloc_mem_success[0];

                p_alloc_mem_req[0] = alloc_mem_req;
                p_alloc_mem_size[0] = alloc_mem_size;
                // alloc_mem_intense = p_alloc_mem_intense[0];
            end
            else begin
                alloc_cell_id = p_alloc_cell_id[1];
                alloc_port_id = 1;
                alloc_mem_success = p_alloc_mem_success[1];
                
                p_alloc_mem_req[1] = alloc_mem_req;
                p_alloc_mem_size[1] = alloc_mem_size;
                // alloc_mem_intense = p_alloc_mem_intense[1];
            end
        end
        else begin  // both mem are intense, use round robin
            alloc_cell_id = p_alloc_cell_id[rr_counter];
            alloc_port_id = rr_counter;
            alloc_mem_success = p_alloc_mem_success[rr_counter];
            p_alloc_mem_req[rr_counter] = alloc_mem_req;
            p_alloc_mem_size[rr_counter] = alloc_mem_size;
            // alloc_mem_intense = p_alloc_mem_intense[rr_counter];
        end
    end
end

always @(posedge clk) begin
    if(rst) begin
        rr_counter <= 0;
    end
    else begin
        if(alloc_mem_req && alloc_mem_success) begin
            rr_counter <= rr_counter +1;
        end
    end
end

always @* begin
    free_mem_ready = p_free_mem_ready[0] | p_free_mem_ready[1];
    p_free_mem_req  [0] = 0;
    p_free_mem_size [0] = 0;
    p_free_cell_id  [0] = 0;

    p_free_mem_req  [1] = 0;
    p_free_mem_size [1] = 0;
    p_free_cell_id  [1] = 0;


    if(free_mem_req[0] == 1 ) begin // drop from pifo
        p_free_mem_req  [free_bank_id[0]][0] = free_mem_req[0];
        p_free_mem_size [free_bank_id[0]][0 * LEN_WIDTH  +: LEN_WIDTH] = free_mem_size[0 * LEN_WIDTH  +: LEN_WIDTH];
        p_free_cell_id  [free_bank_id[0]][0 * CELL_ID_WIDTH  +: CELL_ID_WIDTH] = free_cell_id[0 * CELL_ID_WIDTH  +: CELL_ID_WIDTH];
    end

    if(free_mem_req[1] == 1) begin // drop from dma
        p_free_mem_req  [free_bank_id[1]][1] = free_mem_req[1];
        p_free_mem_size [free_bank_id[1]][1 * LEN_WIDTH  +: LEN_WIDTH] = free_mem_size[1 * LEN_WIDTH  +: LEN_WIDTH];
        p_free_cell_id  [free_bank_id[1]][1 * CELL_ID_WIDTH  +: CELL_ID_WIDTH] = free_cell_id[1 * CELL_ID_WIDTH  +: CELL_ID_WIDTH];
    end

end



rand_mem_alloc #(
    // .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .CELL_NUM(CELL_NUM/2),
    .CELL_ID_WIDTH(CELL_ID_WIDTH),
    .LEN_WIDTH(LEN_WIDTH),
    // .CELL_SIZE(512 * 3 * 8),
    .FREE_PORT_NUM(FREE_PORT_NUM)
)
rand_memory_alloc_inst1 (
    .clk(clk),
    .rst(rst),

    .alloc_mem_req(p_alloc_mem_req[0]),
    .alloc_mem_size(p_alloc_mem_size[0]),
    .alloc_cell_id(p_alloc_cell_id[0]),
    .alloc_mem_success(p_alloc_mem_success[0]),
    .alloc_mem_intense(p_alloc_mem_intense[0]),

    .free_mem_req(p_free_mem_req[0]),
    .free_mem_ready(p_free_mem_ready[0]),
    .free_mem_size(p_free_mem_size[0]),
    .free_cell_id(p_free_cell_id[0])
);

rand_mem_alloc #(
    // .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .CELL_NUM(CELL_NUM/2),
    .CELL_ID_WIDTH(CELL_ID_WIDTH),
    .LEN_WIDTH(LEN_WIDTH),
    // .CELL_SIZE(512 * 3 * 8),
    .FREE_PORT_NUM(FREE_PORT_NUM)
)
rand_memory_alloc_inst2 (
    .clk(clk),
    .rst(rst),

    .alloc_mem_req(p_alloc_mem_req[1]),
    .alloc_mem_size(p_alloc_mem_size[1]),
    .alloc_cell_id(p_alloc_cell_id[1]),
    .alloc_mem_success(p_alloc_mem_success[1]),
    .alloc_mem_intense(p_alloc_mem_intense[1]),

    .free_mem_req(p_free_mem_req[1]),
    .free_mem_ready(p_free_mem_ready[1]),
    .free_mem_size(p_free_mem_size[1]),
    .free_cell_id(p_free_cell_id[1])
);



endmodule