
`include "panic_define.v"

module asyn_SHA #
(

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
    output wire                             s_data_buffer_tready,
    input  wire                             s_data_buffer_tlast,



    output  wire [512-1:0]                    m_sha_tdata,
    output  wire                              m_sha_tvalid,
    input   wire                              m_sha_tready,
  

    output  wire [SWITCH_DATA_WIDTH-1:0]      m_data_buffer_tdata,
    output  wire [SWITCH_KEEP_WIDTH-1:0]      m_data_buffer_tkeep,
    output  wire                              m_data_buffer_tvalid,
    input   wire                              m_data_buffer_tready,
    output  wire                              m_data_buffer_tlast,

    output  wire [`PANIC_DESC_WIDTH-1:0]         m_sha_desc_fifo_tdata,
    output  wire                                 m_sha_desc_fifo_tvalid,
    input  wire                                  m_sha_desc_fifo_tready
    
);
reg [`PANIC_DESC_WIDTH-1:0]          s_sha_desc_fifo_tdata;
reg                                  s_sha_desc_fifo_tvalid;
wire                                 s_sha_desc_fifo_tready;

reg  if_sha_desc = 0;

always @(posedge clk) begin
    if(rst) begin
        if_sha_desc <= 1;
    end
    else begin
        if(if_sha_desc == 1) begin
            if(s_data_buffer_tready && s_data_buffer_tvalid) begin
                if_sha_desc <= 0;
            end
        end

        if(s_data_buffer_tlast && s_data_buffer_tready && s_data_buffer_tvalid) begin
            if_sha_desc <= 1;
        end
    end
end

axis_fifo #(
    .DEPTH(4),
    .DATA_WIDTH(`PANIC_DESC_WIDTH),
    .KEEP_ENABLE(0),
    .LAST_ENABLE(0),
    .ID_ENABLE(0),
    .DEST_ENABLE(0),
    .USER_ENABLE(0),
    .FRAME_FIFO(0)
)
sha_desc_fifo (
    .clk(clk),
    .rst(rst),

    // AXI input
    .s_axis_tdata(s_data_buffer_tdata),
    .s_axis_tvalid(s_data_buffer_tready && s_data_buffer_tvalid && if_sha_desc),
    .s_axis_tready(s_sha_desc_fifo_tready),

    // AXI output
    .m_axis_tdata(m_sha_desc_fifo_tdata),
    .m_axis_tvalid(m_sha_desc_fifo_tvalid),
    .m_axis_tready(m_sha_desc_fifo_tready)
);


wire plle3_locked;
wire plle3_clkfb;
wire clk_150;
wire rst_150;


// generate lower frequency clock
PLLE4_BASE #(
      .CLKFBOUT_MULT(6),          // Multiply value for all CLKOUT, (1-19)
      .CLKFBOUT_PHASE(0.0),       // Phase offset in degrees of CLKFB, (-360.000-360.000)
      .CLKIN_PERIOD(4.0),         // Input clock period in ns to ps resolution (i.e. 33.333 is 30 MHz).
      // CLKOUT0 Attributes: Divide, Phase and Duty Cycle for the CLKOUT0 output
      .CLKOUT0_DIVIDE(10),         // Divide amount for CLKOUT0 (1-128)
      .CLKOUT0_DUTY_CYCLE(0.5),   // Duty cycle for CLKOUT0 (0.001-0.999)
      .CLKOUT0_PHASE(0.0),        // Phase offset for CLKOUT0 (-360.000-360.000)
      // CLKOUT1 Attributes: Divide, Phase and Duty Cycle for the CLKOUT1 output
      .CLKOUT1_DIVIDE(1),         // Divide amount for CLKOUT1 (1-128)
      .CLKOUT1_DUTY_CYCLE(0.5),   // Duty cycle for CLKOUT1 (0.001-0.999)
      .CLKOUT1_PHASE(0.0),        // Phase offset for CLKOUT1 (-360.000-360.000)
      .CLKOUTPHY_MODE("VCO_2X"),  // Frequency of the CLKOUTPHY (VCO, VCO_2X, VCO_HALF)
      .DIVCLK_DIVIDE(1),          // Master division value, (1-15)
      // Programmable Inversion Attributes: Specifies built-in programmable inversion on specific pins
      .IS_CLKFBIN_INVERTED(1'b0), // Optional inversion for CLKFBIN
      .IS_CLKIN_INVERTED(1'b0),   // Optional inversion for CLKIN
      .IS_PWRDWN_INVERTED(1'b0),  // Optional inversion for PWRDWN
      .IS_RST_INVERTED(1'b0),     // Optional inversion for RST
      .REF_JITTER(0.0),           // Reference input jitter in UI (0.000-0.999)
      .STARTUP_WAIT("FALSE")      // Delays DONE until PLL is locked (FALSE, TRUE)
   )
   sha_PLLE4_BASE_inst (
      // Clock Outputs outputs: User configurable clock outputs
      .CLKOUT0(clk_150),         // 1-bit output: General Clock output
      .CLKOUT0B(),       // 1-bit output: Inverted CLKOUT0
      .CLKOUT1(),         // 1-bit output: General Clock output
      .CLKOUT1B(),       // 1-bit output: Inverted CLKOUT1
      .CLKOUTPHY(),     // 1-bit output: Bitslice clock
      // Feedback Clocks outputs: Clock feedback ports
      .CLKFBOUT(plle3_clkfb),       // 1-bit output: Feedback clock
      .LOCKED(plle3_locked),           // 1-bit output: LOCK
      .CLKIN(clk),             // 1-bit input: Input clock
      // Control Ports inputs: PLL control ports
      .CLKOUTPHYEN(1'b0), // 1-bit input: CLKOUTPHY enable
      .PWRDWN(1'b0),           // 1-bit input: Power-down
      .RST(rst),                 // 1-bit input: Reset
      // Feedback Clocks inputs: Clock feedback ports
      .CLKFBIN(plle3_clkfb)          // 1-bit input: Feedback clock
   );



sync_reset #(
    .N(4)
)
sha_sync_reset_150mhz_inst (
    .clk(clk_150),
    .rst(~plle3_locked),
    .out(rst_150)
);


// Async FIFO change frequency

// wire [SWITCH_DATA_WIDTH-1:0]     s_data_buffer_150_tdata;
// wire [SWITCH_KEEP_WIDTH-1:0]     s_data_buffer_150_tkeep;
// wire                             s_data_buffer_150_tvalid;
// wire                             s_data_buffer_150_tready;
// wire                             s_data_buffer_150_tlast;

wire [SWITCH_DATA_WIDTH-1:0]     m_data_buffer_150_tdata;
wire [SWITCH_KEEP_WIDTH-1:0]     m_data_buffer_150_tkeep;
wire                             m_data_buffer_150_tvalid;
wire                             m_data_buffer_150_tready;
wire                             m_data_buffer_150_tlast;


wire s_in_axis_async_fifo_tready;

axis_async_fifo #(
    .DEPTH(16 * SWITCH_KEEP_WIDTH),
    .DATA_WIDTH(SWITCH_DATA_WIDTH),
    .KEEP_ENABLE(1),
    .KEEP_WIDTH(SWITCH_KEEP_WIDTH),
    .LAST_ENABLE(1),
    .USER_ENABLE(0),
    .ID_ENABLE(0),
    .DEST_ENABLE(0),
    .FRAME_FIFO(0)
)
in_axis_async_fifo (
    // Common reset
    .async_rst(rst|rst_150),
    // AXI input
    .s_clk(clk),
    .s_axis_tdata(s_data_buffer_tdata),
    .s_axis_tkeep(s_data_buffer_tkeep),
    .s_axis_tvalid(s_data_buffer_tready && s_data_buffer_tvalid && !if_sha_desc),
    .s_axis_tready(s_in_axis_async_fifo_tready),
    .s_axis_tlast(s_data_buffer_tlast),

    // AXI output
    .m_clk(clk_150),
    .m_axis_tdata(m_data_buffer_150_tdata),
    .m_axis_tkeep(m_data_buffer_150_tkeep),
    .m_axis_tvalid(m_data_buffer_150_tvalid),
    .m_axis_tready(m_data_buffer_150_tready),
    .m_axis_tlast(m_data_buffer_150_tlast)
);


//////////////////sha descriptor////////////////////////


wire [SWITCH_DATA_WIDTH-1:0]          s_sha_data_in_fifo_tdata;
wire [SWITCH_KEEP_WIDTH-1:0]          s_sha_data_in_fifo_tkeep;
wire                                  s_sha_data_in_fifo_tvalid;
wire                                  s_sha_data_in_fifo_tready;
wire                                  s_sha_data_in_fifo_tlast;

wire [64-1:0]                         m_sha_data_in_fifo_tdata;
wire [8-1:0]                          m_sha_data_in_fifo_tkeep;
reg [3-1:0]                           m_sha_data_in_fifo_byte_num;
wire                                  m_sha_data_in_fifo_tvalid;
wire                                  m_sha_data_in_fifo_tvalid_tmp;
wire                                  m_sha_data_in_fifo_nready;
wire                                  m_sha_data_in_fifo_tready;
wire                                  m_sha_data_in_fifo_tlast;
reg [3-1:0]                           m_sha_data_in_fifo_byte_num_pad;
reg                                   m_sha_data_in_fifo_tlast_pad;
reg                                   m_sha_data_in_fifo_tlast_pad_valid;
reg                                   start_nxt_msg;

assign s_sha_data_in_fifo_tdata = m_data_buffer_150_tdata;
assign s_sha_data_in_fifo_tvalid = m_data_buffer_150_tvalid;
assign s_sha_data_in_fifo_tlast = m_data_buffer_150_tlast;
assign s_sha_data_in_fifo_tkeep = m_data_buffer_150_tkeep;
assign m_data_buffer_150_tready = s_sha_data_in_fifo_tready;

assign m_sha_data_in_fifo_tready = !m_sha_data_in_fifo_nready && start_nxt_msg;


axis_fifo_adapter  #(
    .DEPTH(4 * SWITCH_KEEP_WIDTH),
    .S_DATA_WIDTH(SWITCH_DATA_WIDTH),
    .M_DATA_WIDTH(64),
    .S_KEEP_ENABLE (1),
    .M_KEEP_ENABLE (1),
    .S_KEEP_WIDTH (SWITCH_KEEP_WIDTH),
    .M_KEEP_WIDTH (8),
    .ID_ENABLE(0),
    .DEST_ENABLE(0),
    .USER_ENABLE(0),
    .FRAME_FIFO(0)
)
sha_data_in_fifo (
    .clk(clk_150),
    .rst(rst_150),

    // AXI input
    .s_axis_tdata(s_sha_data_in_fifo_tdata),
    .s_axis_tvalid(s_sha_data_in_fifo_tvalid),
    .s_axis_tready(s_sha_data_in_fifo_tready),
    .s_axis_tlast(s_sha_data_in_fifo_tlast),
    .s_axis_tkeep(s_sha_data_in_fifo_tkeep),

    // AXI output
    .m_axis_tdata(m_sha_data_in_fifo_tdata),
    .m_axis_tvalid(m_sha_data_in_fifo_tvalid),
    .m_axis_tready(m_sha_data_in_fifo_tready),
    .m_axis_tlast(m_sha_data_in_fifo_tlast),
    .m_axis_tkeep(m_sha_data_in_fifo_tkeep)
);


integer i;
always @* begin
    // if(s_rx_axis_tvalid && s_rx_axis_tready) begin
        m_sha_data_in_fifo_byte_num = 0;
        for(i = 0; i < 8; i = i + 1) begin
            if(m_sha_data_in_fifo_tkeep[i] == 1) begin
                // $display("Check: %d,%x, %d",m_sha_data_in_fifo_byte_num, m_sha_data_in_fifo_tkeep,m_sha_data_in_fifo_tkeep[i]);
                m_sha_data_in_fifo_byte_num = m_sha_data_in_fifo_byte_num + 1;
            end
        end
    // end
end

reg sha_rst;

wire  [511:0]                        s_sha_tiny_fifo_tdata;
wire                                 s_sha_tiny_fifo_tvalid;
wire                                 s_sha_tiny_fifo_tvalid_tmp;
wire                                 s_sha_tiny_fifo_tready;

wire  [511:0]                        m_sha_tiny_fifo_tdata;
wire                                 m_sha_tiny_fifo_tvalid;
wire                                 m_sha_tiny_fifo_tready;

always @(posedge clk_150) begin
    if(rst_150) begin
        sha_rst <= 1;
    end
    else begin
        if(sha_rst) begin
            sha_rst <= 0;
        end
        else if(s_sha_tiny_fifo_tvalid_tmp) begin
            sha_rst <= 1;
        end
    end
end

// logic for last block padding
always@(posedge clk_150) begin
    if(rst_150) begin
        m_sha_data_in_fifo_tlast_pad_valid <= 0;
        start_nxt_msg <= 1;
    end
    else begin
        // staet nxt msg logic
        if(m_sha_data_in_fifo_tready && m_sha_data_in_fifo_tvalid && m_sha_data_in_fifo_tlast ) begin
            start_nxt_msg <= 0;
        end
        if(sha_rst) begin
            start_nxt_msg <= 1;
        end

        if(!m_sha_data_in_fifo_nready && m_sha_data_in_fifo_tlast_pad_valid) begin
            m_sha_data_in_fifo_tlast_pad_valid <= 0;
        end
        if(m_sha_data_in_fifo_tready && m_sha_data_in_fifo_tvalid && m_sha_data_in_fifo_tlast && m_sha_data_in_fifo_byte_num == 0) begin// need padding
            m_sha_data_in_fifo_tlast_pad_valid <= 1;
        end 
    end
end

always @* begin
    m_sha_data_in_fifo_byte_num_pad = 0;
    m_sha_data_in_fifo_tlast_pad = 0;

    if(m_sha_data_in_fifo_tlast_pad_valid) begin  // fake pad last
        m_sha_data_in_fifo_byte_num_pad = 0;
        m_sha_data_in_fifo_tlast_pad = 1;
    end
    else if(m_sha_data_in_fifo_tlast && m_sha_data_in_fifo_byte_num != 0) begin // true last
        m_sha_data_in_fifo_byte_num_pad = m_sha_data_in_fifo_byte_num;
        m_sha_data_in_fifo_tlast_pad = m_sha_data_in_fifo_tlast;
    end


end



keccak uut (
    .clk(clk_150),
    .reset(sha_rst),
    .in(m_sha_data_in_fifo_tdata),
    .in_ready((m_sha_data_in_fifo_tvalid && start_nxt_msg) || m_sha_data_in_fifo_tlast_pad_valid),
    .is_last(m_sha_data_in_fifo_tlast_pad),
    .byte_num(m_sha_data_in_fifo_byte_num_pad),
    .buffer_full(m_sha_data_in_fifo_nready),
    .out(s_sha_tiny_fifo_tdata),
    .out_ready(s_sha_tiny_fifo_tvalid_tmp)
);


assign  s_sha_tiny_fifo_tvalid = s_sha_tiny_fifo_tvalid_tmp && !sha_rst;
axis_fifo #(
    .DEPTH(4),
    .DATA_WIDTH(512),
    .KEEP_ENABLE(0),
    .LAST_ENABLE(0),
    .ID_ENABLE(0),
    .DEST_ENABLE(0),
    .USER_ENABLE(0),
    .FRAME_FIFO(0)
)
sha_tiny_fifo (
    .clk(clk_150),
    .rst(rst_150),

    // AXI input
    .s_axis_tdata(s_sha_tiny_fifo_tdata),
    .s_axis_tvalid(s_sha_tiny_fifo_tvalid),
    .s_axis_tready(s_sha_tiny_fifo_tready),

    // AXI output
    .m_axis_tdata(m_sha_tiny_fifo_tdata),
    .m_axis_tvalid(m_sha_tiny_fifo_tvalid),
    .m_axis_tready(m_sha_tiny_fifo_tready)
);


axis_async_fifo #(
    .DEPTH(8),
    .DATA_WIDTH(512),
    .KEEP_ENABLE(0),
    .LAST_ENABLE(0),
    .USER_ENABLE(0),
    .ID_ENABLE(0),
    .DEST_ENABLE(0),
    .FRAME_FIFO(0)
)
out_sha_async_fifo (
    // Common reset
    .async_rst(rst|rst_150),
    // AXI input
    .s_clk(clk_150),
    .s_axis_tdata(m_sha_tiny_fifo_tdata),
    .s_axis_tvalid(m_sha_tiny_fifo_tvalid),
    .s_axis_tready(m_sha_tiny_fifo_tready),

    // AXI output
    .m_clk(clk),
    .m_axis_tdata(m_sha_tdata),
    .m_axis_tvalid(m_sha_tvalid),
    .m_axis_tready(m_sha_tready)
);

// data bypass fifo
wire [SWITCH_DATA_WIDTH-1:0]            s_tmp_data_buffer_fifo_tdata;
wire [SWITCH_KEEP_WIDTH-1:0]            s_tmp_data_buffer_fifo_tkeep;
wire                                    s_tmp_data_buffer_fifo_tvalid;
wire                                    s_tmp_data_buffer_fifo_tready;
wire                                    s_tmp_data_buffer_fifo_tlast;

// wire [SWITCH_DATA_WIDTH-1:0]           m_tmp_data_buffer_fifo_tdata;
// wire [SWITCH_KEEP_WIDTH-1:0]           m_tmp_data_buffer_fifo_tkeep;
// wire                                   m_tmp_data_buffer_fifo_tvalid;
// wire                                   m_tmp_data_buffer_fifo_tready;
// wire                                   m_tmp_data_buffer_fifo_tlast;

assign s_tmp_data_buffer_fifo_tdata  = s_data_buffer_tdata;
assign s_tmp_data_buffer_fifo_tkeep  = s_data_buffer_tkeep;
assign s_tmp_data_buffer_fifo_tlast  = s_data_buffer_tlast;
assign s_tmp_data_buffer_fifo_tvalid = s_data_buffer_tready && s_data_buffer_tvalid && !if_sha_desc;

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
tmp_data_buffer_fifo (
    .clk(clk),
    .rst(rst),

    // AXI input
    .s_axis_tdata(s_tmp_data_buffer_fifo_tdata),
    .s_axis_tkeep(s_tmp_data_buffer_fifo_tkeep),
    .s_axis_tvalid(s_tmp_data_buffer_fifo_tvalid),
    .s_axis_tready(s_tmp_data_buffer_fifo_tready),
    .s_axis_tlast(s_tmp_data_buffer_fifo_tlast),

    // AXI output
    .m_axis_tdata(m_data_buffer_tdata),
    .m_axis_tkeep(m_data_buffer_tkeep),
    .m_axis_tvalid(m_data_buffer_tvalid),
    .m_axis_tready(m_data_buffer_tready),
    .m_axis_tlast(m_data_buffer_tlast)
);

assign s_data_buffer_tready = s_sha_desc_fifo_tready && s_in_axis_async_fifo_tready && s_tmp_data_buffer_fifo_tready;

endmodule
