`include "panic_define.v"

module SHA_warper #
(

    // crossbar data width, current 512, but need refine
    parameter SWITCH_DATA_WIDTH = 512,
    parameter SWITCH_KEEP_WIDTH = (SWITCH_DATA_WIDTH/8)

)
(
    input  wire                       clk,
    input  wire                       rst,

    /*
    * Crossbar interface input
    */
    input  wire [SWITCH_DATA_WIDTH-1:0]     s_data_buffer_tdata,
    input  wire [SWITCH_KEEP_WIDTH-1:0]     s_data_buffer_tkeep,
    input  wire                             s_data_buffer_tvalid,
    output reg                              s_data_buffer_tready,
    input  wire                             s_data_buffer_tlast,



    output  reg  [512-1:0]                    m_sha_tdata,
    output  reg                               m_sha_tvalid,
    input   wire                              m_sha_tready,
  

    output  reg  [SWITCH_DATA_WIDTH-1:0]      m_data_buffer_tdata,
    output  reg  [SWITCH_KEEP_WIDTH-1:0]      m_data_buffer_tkeep,
    output  reg                               m_data_buffer_tvalid,
    input   wire                              m_data_buffer_tready,
    output  reg                               m_data_buffer_tlast,

    output  reg [`PANIC_DESC_WIDTH-1:0]         m_sha_desc_fifo_tdata,
    output  reg                                 m_sha_desc_fifo_tvalid,
    input   wire                                m_sha_desc_fifo_tready
    
);



reg  [SWITCH_DATA_WIDTH-1:0]         sn_data_buffer_tdata   [3:0];
reg  [SWITCH_KEEP_WIDTH-1:0]         sn_data_buffer_tkeep   [3:0];
reg                                  sn_data_buffer_tvalid   [3:0];
wire                                 sn_data_buffer_tready   [3:0];
reg                                  sn_data_buffer_tlast   [3:0];

wire [512-1:0]                      mn_sha_tdata   [3:0];
wire                                mn_sha_tvalid   [3:0];
reg                                 mn_sha_tready   [3:0];

wire [SWITCH_DATA_WIDTH-1:0]        mn_data_buffer_tdata   [3:0];
wire [SWITCH_KEEP_WIDTH-1:0]        mn_data_buffer_tkeep   [3:0];
wire                                mn_data_buffer_tvalid   [3:0];
reg                                 mn_data_buffer_tready   [3:0];
wire                                mn_data_buffer_tlast   [3:0];

wire [`PANIC_DESC_WIDTH-1:0]        mn_sha_desc_fifo_tdata   [3:0];
wire                                mn_sha_desc_fifo_tvalid   [3:0];
reg                                 mn_sha_desc_fifo_tready   [3:0];

///////////////////////BIG ARBITER///////////////////////
reg [1:0] input_selector;
reg [1:0] output_selector;

integer i;
always @* begin
    for(i = 0; i < 4; i = i+1) begin
        sn_data_buffer_tdata  [i] = 0;
        sn_data_buffer_tkeep  [i] = 0;
        sn_data_buffer_tvalid [i] = 0;
        sn_data_buffer_tlast  [i] = 0;
    end
    sn_data_buffer_tdata  [input_selector] = s_data_buffer_tdata;
    sn_data_buffer_tkeep  [input_selector] = s_data_buffer_tkeep;
    sn_data_buffer_tvalid [input_selector] = s_data_buffer_tvalid;
    sn_data_buffer_tlast  [input_selector] = s_data_buffer_tlast;
    s_data_buffer_tready = sn_data_buffer_tready  [input_selector];
end

integer j;
always @* begin
    for(j = 0; j < 4; j = j+1) begin
        mn_data_buffer_tready[j] = 0;
        mn_sha_desc_fifo_tready[j] = 0;
        mn_sha_tready[j] =0;
    end
    m_data_buffer_tdata  = mn_data_buffer_tdata  [output_selector];
    m_data_buffer_tkeep  = mn_data_buffer_tkeep  [output_selector];
    m_data_buffer_tvalid = mn_data_buffer_tvalid [output_selector];
    m_data_buffer_tlast  = mn_data_buffer_tlast  [output_selector];
    mn_data_buffer_tready[output_selector] = m_data_buffer_tready;

    m_sha_desc_fifo_tdata  = mn_sha_desc_fifo_tdata  [output_selector];
    m_sha_desc_fifo_tvalid = mn_sha_desc_fifo_tvalid [output_selector];
    mn_sha_desc_fifo_tready[output_selector] = m_sha_desc_fifo_tready;

    m_sha_tdata  = mn_sha_tdata  [output_selector];
    m_sha_tvalid = mn_sha_tvalid [output_selector];
    mn_sha_tready[output_selector] = m_sha_tready;

end

always @(posedge clk) begin
    if (rst) begin
        input_selector <= 0;
        output_selector <= 0;
    end
    else begin
        if(s_data_buffer_tlast && s_data_buffer_tvalid && s_data_buffer_tready) begin
            input_selector <= input_selector + 1;
        end
        if(mn_data_buffer_tvalid [output_selector] && mn_data_buffer_tready[output_selector] && mn_data_buffer_tlast  [output_selector]) begin
            output_selector <= output_selector + 1;
        end
    end

end



/////////////////////////////////////////////////////////
asyn_SHA #
(
    .SWITCH_DATA_WIDTH(SWITCH_DATA_WIDTH),
    .SWITCH_KEEP_WIDTH(SWITCH_KEEP_WIDTH)
)
asyn_SHA_inst1 (
    .clk(clk),
    .rst(rst),

    .s_data_buffer_tdata(sn_data_buffer_tdata[0]),
    .s_data_buffer_tkeep(sn_data_buffer_tkeep[0]),
    .s_data_buffer_tvalid(sn_data_buffer_tvalid[0]),
    .s_data_buffer_tready(sn_data_buffer_tready[0]),
    .s_data_buffer_tlast(sn_data_buffer_tlast[0]),

    .m_sha_tdata(mn_sha_tdata[0]),
    .m_sha_tvalid(mn_sha_tvalid[0]),
    .m_sha_tready(mn_sha_tready[0]),
  
    .m_data_buffer_tdata(mn_data_buffer_tdata[0]),
    .m_data_buffer_tkeep(mn_data_buffer_tkeep[0]),
    .m_data_buffer_tvalid(mn_data_buffer_tvalid[0]),
    .m_data_buffer_tready(mn_data_buffer_tready[0]),
    .m_data_buffer_tlast(mn_data_buffer_tlast[0]),

    .m_sha_desc_fifo_tdata(mn_sha_desc_fifo_tdata[0]),
    .m_sha_desc_fifo_tvalid(mn_sha_desc_fifo_tvalid[0]),
    .m_sha_desc_fifo_tready(mn_sha_desc_fifo_tready[0])
);

asyn_SHA #
(
    .SWITCH_DATA_WIDTH(SWITCH_DATA_WIDTH),
    .SWITCH_KEEP_WIDTH(SWITCH_KEEP_WIDTH)
)
asyn_SHA_inst2 (
    .clk(clk),
    .rst(rst),

    .s_data_buffer_tdata(sn_data_buffer_tdata[1]),
    .s_data_buffer_tkeep(sn_data_buffer_tkeep[1]),
    .s_data_buffer_tvalid(sn_data_buffer_tvalid[1]),
    .s_data_buffer_tready(sn_data_buffer_tready[1]),
    .s_data_buffer_tlast(sn_data_buffer_tlast[1]),

    .m_sha_tdata(mn_sha_tdata[1]),
    .m_sha_tvalid(mn_sha_tvalid[1]),
    .m_sha_tready(mn_sha_tready[1]),
  
    .m_data_buffer_tdata(mn_data_buffer_tdata[1]),
    .m_data_buffer_tkeep(mn_data_buffer_tkeep[1]),
    .m_data_buffer_tvalid(mn_data_buffer_tvalid[1]),
    .m_data_buffer_tready(mn_data_buffer_tready[1]),
    .m_data_buffer_tlast(mn_data_buffer_tlast[1]),

    .m_sha_desc_fifo_tdata(mn_sha_desc_fifo_tdata[1]),
    .m_sha_desc_fifo_tvalid(mn_sha_desc_fifo_tvalid[1]),
    .m_sha_desc_fifo_tready(mn_sha_desc_fifo_tready[1])
);
asyn_SHA #
(
    .SWITCH_DATA_WIDTH(SWITCH_DATA_WIDTH),
    .SWITCH_KEEP_WIDTH(SWITCH_KEEP_WIDTH)
)
asyn_SHA_inst3 (
    .clk(clk),
    .rst(rst),

    .s_data_buffer_tdata(sn_data_buffer_tdata[2]),
    .s_data_buffer_tkeep(sn_data_buffer_tkeep[2]),
    .s_data_buffer_tvalid(sn_data_buffer_tvalid[2]),
    .s_data_buffer_tready(sn_data_buffer_tready[2]),
    .s_data_buffer_tlast(sn_data_buffer_tlast[2]),

    .m_sha_tdata(mn_sha_tdata[2]),
    .m_sha_tvalid(mn_sha_tvalid[2]),
    .m_sha_tready(mn_sha_tready[2]),
  
    .m_data_buffer_tdata(mn_data_buffer_tdata[2]),
    .m_data_buffer_tkeep(mn_data_buffer_tkeep[2]),
    .m_data_buffer_tvalid(mn_data_buffer_tvalid[2]),
    .m_data_buffer_tready(mn_data_buffer_tready[2]),
    .m_data_buffer_tlast(mn_data_buffer_tlast[2]),

    .m_sha_desc_fifo_tdata(mn_sha_desc_fifo_tdata[2]),
    .m_sha_desc_fifo_tvalid(mn_sha_desc_fifo_tvalid[2]),
    .m_sha_desc_fifo_tready(mn_sha_desc_fifo_tready[2])
);
asyn_SHA #
(
    .SWITCH_DATA_WIDTH(SWITCH_DATA_WIDTH),
    .SWITCH_KEEP_WIDTH(SWITCH_KEEP_WIDTH)
)
asyn_SHA_inst4 (
    .clk(clk),
    .rst(rst),

    .s_data_buffer_tdata(sn_data_buffer_tdata[3]),
    .s_data_buffer_tkeep(sn_data_buffer_tkeep[3]),
    .s_data_buffer_tvalid(sn_data_buffer_tvalid[3]),
    .s_data_buffer_tready(sn_data_buffer_tready[3]),
    .s_data_buffer_tlast(sn_data_buffer_tlast[3]),

    .m_sha_tdata(mn_sha_tdata[3]),
    .m_sha_tvalid(mn_sha_tvalid[3]),
    .m_sha_tready(mn_sha_tready[3]),
  
    .m_data_buffer_tdata(mn_data_buffer_tdata[3]),
    .m_data_buffer_tkeep(mn_data_buffer_tkeep[3]),
    .m_data_buffer_tvalid(mn_data_buffer_tvalid[3]),
    .m_data_buffer_tready(mn_data_buffer_tready[3]),
    .m_data_buffer_tlast(mn_data_buffer_tlast[3]),

    .m_sha_desc_fifo_tdata(mn_sha_desc_fifo_tdata[3]),
    .m_sha_desc_fifo_tvalid(mn_sha_desc_fifo_tvalid[3]),
    .m_sha_desc_fifo_tready(mn_sha_desc_fifo_tready[3])
);
endmodule

