
`timescale 1ns / 1ps
`include "panic_define.v"
module pifo_warp #
(
    parameter   NUMPIFO    = 1024,
    parameter   BITPORT    = 1,
    parameter   BITPRIO    = 16,
    parameter   BITDESC    = 32,
    parameter   PIFO_ID    = 0
)
(
    input  wire                             clk,
    input  wire                             rst,

    output wire                            pifo_in_ready,
    input wire                            pifo_in_valid,
    input wire [BITPRIO-1:0]              pifo_in_prio, 
    input wire [BITDESC-1:0]              pifo_in_data,
    input wire                            pifo_in_drop,


    input wire                            pifo_out_ready,
    output wire                            pifo_out_valid,
    output wire [BITPRIO-1:0]              pifo_out_prio, 
    output wire [BITDESC-1:0]              pifo_out_data,

    // drop wire
    output wire                            pifo_out_drop_valid,
    output wire [BITPRIO-1:0]              pifo_out_drop_prio, 
    output wire [BITDESC-1:0]              pifo_out_drop_data

);

wire plle3_locked;
wire plle3_clkfb;
wire clk_125;
wire rst_125;

// generate lower frequency clock
PLLE4_BASE #(
      .CLKFBOUT_MULT(4),          // Multiply value for all CLKOUT, (1-19)
      .CLKFBOUT_PHASE(0.0),       // Phase offset in degrees of CLKFB, (-360.000-360.000)
      .CLKIN_PERIOD(4.0),         // Input clock period in ns to ps resolution (i.e. 33.333 is 30 MHz).
      // CLKOUT0 Attributes: Divide, Phase and Duty Cycle for the CLKOUT0 output
      .CLKOUT0_DIVIDE(8),         // Divide amount for CLKOUT0 (1-128)
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
   PLLE4_BASE_inst (
      // Clock Outputs outputs: User configurable clock outputs
      .CLKOUT0(clk_125),         // 1-bit output: General Clock output
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
sync_reset_125mhz_inst (
    .clk(clk_125),
    .rst(~plle3_locked),
    .out(rst_125)
);


wire                            pifo_125_in_ready;
wire                            pifo_125_in_valid;
wire [BITPRIO-1:0]              pifo_125_in_prio;
wire [BITDESC-1:0]              pifo_125_in_data;

axis_async_fifo #(
    .DEPTH(4),
    .DATA_WIDTH(BITDESC + BITPRIO),
    .KEEP_ENABLE(0),
    .LAST_ENABLE(0),
    .ID_ENABLE(0),
    .DEST_ENABLE(0),
    .USER_ENABLE(0)
)
in_axis_async_fifo (
    // Common reset
    .async_rst(rst|rst_125),
    // AXI input
    .s_clk(clk),
    .s_axis_tdata({pifo_in_data,pifo_in_prio}),
    .s_axis_tvalid(pifo_in_valid),
    .s_axis_tready(pifo_in_ready),

    // AXI output
    .m_clk(clk_125),
    .m_axis_tdata({pifo_125_in_data,pifo_125_in_prio}),
    .m_axis_tvalid(pifo_125_in_valid),
    .m_axis_tready(pifo_125_in_ready)
);
wire                            pifo_125_out_ready;
wire                            pifo_125_out_valid;
wire [BITPRIO-1:0]              pifo_125_out_prio;
wire [BITDESC-1:0]              pifo_125_out_data;  

axis_async_fifo #(
    .DEPTH(4),
    .DATA_WIDTH(BITDESC + BITPRIO),
    .KEEP_ENABLE(0),
    .LAST_ENABLE(0),
    .ID_ENABLE(0),
    .DEST_ENABLE(0),
    .USER_ENABLE(0)
)
out_axis_async_fifo (
    // Common reset
    .async_rst(rst|rst_125),
    // AXI input
    .s_clk(clk_125),
    .s_axis_tdata({pifo_125_out_data,pifo_125_out_prio}),
    .s_axis_tvalid(pifo_125_out_valid),
    .s_axis_tready(pifo_125_out_ready),

    // AXI output
    .m_clk(clk),
    .m_axis_tdata({pifo_out_data,pifo_out_prio}),
    .m_axis_tvalid(pifo_out_valid),
    .m_axis_tready(pifo_out_ready)

);

wire                            pifo_125_out_drop_tready;
wire                            pifo_125_out_drop_valid;
wire [BITPRIO-1:0]              pifo_125_out_drop_prio;
wire [BITDESC-1:0]              pifo_125_out_drop_data;  

axis_async_fifo #(
    .DEPTH(4),
    .DATA_WIDTH(BITDESC + BITPRIO),
    .KEEP_ENABLE(0),
    .LAST_ENABLE(0),
    .ID_ENABLE(0),
    .DEST_ENABLE(0),
    .USER_ENABLE(0)
)
out_drop_axis_async_fifo (
    // Common reset
    .async_rst(rst|rst_125),
    // AXI input
    .s_clk(clk_125),
    .s_axis_tdata({pifo_125_out_drop_data,pifo_125_out_drop_prio}),
    .s_axis_tvalid(pifo_125_out_drop_valid),
    .s_axis_tready(pifo_125_out_drop_tready),

    // AXI output
    .m_clk(clk),
    .m_axis_tdata({pifo_out_drop_data,pifo_out_drop_prio}),
    .m_axis_tvalid(pifo_out_drop_valid),
    .m_axis_tready(1)
);

wire                            pifo_125_in_drop; 
xpm_cdc_single #(
    .DEST_SYNC_FF(4),   // DECIMAL; range: 2-10
    .INIT_SYNC_FF(0),   // DECIMAL; 0=disable simulation init values, 1=enable simulation init values
    .SIM_ASSERT_CHK(0), // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
    .SRC_INPUT_REG(1)   // DECIMAL; 0=do not register input, 1=register input
)
xpm_cdc_single_inst (
    .dest_out(pifo_125_in_drop), // 1-bit output: src_in synchronized to the destination clock domain. This output is
                        // registered.

    .dest_clk(clk_125), // 1-bit input: Clock signal for the destination clock domain.
    .src_clk(clk),   // 1-bit input: optional; required when SRC_INPUT_REG = 1
    .src_in(pifo_in_drop)      // 1-bit input: Input signal to be synchronized to dest_clk domain.
);


localparam BITDATA = $clog2(NUMPIFO);



reg                 pop_0;
wire  [BITPORT-1:0] oprt_0;
wire                ovld_0;
wire  [BITPRIO-1:0] opri_0;
wire  [BITDATA-1:0] odout_0;

reg                 push_1;
wire  [BITPORT-1:0] uprt_1;
wire  [BITPRIO-1:0] upri_1;
wire  [BITDATA-1:0] udin_1;
wire                push_1_drop;

wire               odrop_vld_0;
wire [BITPRIO-1:0] odrop_pri_0;
wire [BITDATA-1:0] odrop_dout_0;


reg [BITDATA:0] pifo_counter_nxt;
reg [BITDATA:0] pifo_counter_reg;



reg  [BITDESC-1:0] pifo_data_buffer [NUMPIFO : 0];

reg                              alloc_mem_req;
wire                             alloc_mem_size;
// wire [$clog2(NUMPIFO) -1 : 0]    alloc_mem_addr;
wire [$clog2(NUMPIFO) - 1 : 0]    alloc_cell_id;
wire                             alloc_mem_success;

// wire for free memory 
reg                             free_mem_req_1;
wire                            free_mem_size_1;
// reg [$clog2(NUMPIFO) -1 : 0]    free_mem_addr_1;
reg [$clog2(NUMPIFO) -1 : 0]    free_cell_id_1;

reg                             free_mem_req_2;
wire                            free_mem_size_2;
// reg [$clog2(NUMPIFO) -1 : 0]    free_mem_addr_2;
reg [$clog2(NUMPIFO) -1 : 0]    free_cell_id_2;

rand_mem_alloc #(
    // .AXI_ADDR_WIDTH(BITDATA),
    .CELL_NUM(NUMPIFO),
    .LEN_WIDTH (1),
    // .CELL_SIZE(1),
    .FREE_PORT_NUM(2)
)
desc_memory_alloc_inst (
    .clk(clk_125),
    .rst(rst_125),

    .alloc_mem_req(alloc_mem_req),
    .alloc_mem_size(alloc_mem_size),
    // .alloc_mem_addr(alloc_mem_addr),
    .alloc_cell_id(alloc_cell_id),
    .alloc_mem_success(alloc_mem_success),

    .free_mem_req({free_mem_req_1,free_mem_req_2}),
    .free_mem_size({free_mem_size_1,free_mem_size_2}),
    // .free_mem_addr({free_mem_addr_1,free_mem_addr_2})
    .free_cell_id({free_cell_id_1,free_cell_id_2})
);


pifo #(
    .NUMPIFO (NUMPIFO),
    .BITPORT (BITPORT), 
    .BITPRIO (BITPRIO),
    .BITDATA (BITDATA),
    .PIFO_ID(PIFO_ID)
)inst(
    .clk(clk_125),
    .rst(rst_125),
    .pop_0(pop_0), 
    .oprt_0(oprt_0), 
    .ovld_0(ovld_0), 
    .opri_0(opri_0), 
    .odout_0(odout_0),
    
    .push_1(push_1), 
    .uprt_1(uprt_1), 
    .upri_1(upri_1), 
    .udin_1(udin_1),
    .push_1_drop(push_1_drop & push_1),
    
        
    .push_2(0),
    .push_2_drop(0),

    .odrop_vld_0(odrop_vld_0),
    .odrop_pri_0(odrop_pri_0),
    .odrop_dout_0(odrop_dout_0)
);


assign alloc_mem_size = 1;
assign free_mem_size_1 = 1;
assign free_mem_size_2 = 1;


assign uprt_1 = 0;
assign upri_1 = pifo_125_in_prio;
// assign udin_1 = alloc_mem_addr;
assign udin_1 = alloc_cell_id;
assign pifo_125_in_ready = push_1;
assign push_1_drop = (pifo_125_in_drop || (pifo_counter_reg >= NUMPIFO -4)) && pifo_counter_reg > 8 ;

assign oprt_0 = 0;
assign pifo_125_out_prio = opri_0;
assign pifo_125_out_data = pifo_data_buffer[odout_0];
assign pifo_125_out_valid = ovld_0;

// always @* begin
//     if(!pifo_125_out_drop_tready) begin
//         $display("ERROR in pifo_warp syn drop fifo, should not full");
//     end
// end

always @* begin
    push_1 = 0;
    alloc_mem_req = 0;
    free_mem_req_1 = 0;
    free_cell_id_1 = 0;
    pop_0 = 0;
    if (pifo_125_in_valid ) begin
        alloc_mem_req = 1;
        push_1 = alloc_mem_success;
    end
    if(pifo_125_out_ready && pifo_counter_reg > 0 && !ovld_0) begin
        pop_0 = 1;
    end
    if(pifo_125_out_valid && pifo_125_out_ready) begin
        free_mem_req_1 = 1;
        // free_mem_addr_1 = odout_0;
        free_cell_id_1 = odout_0;
    end
end

// when pifo drop packet
assign pifo_125_out_drop_prio = odrop_pri_0;
assign pifo_125_out_drop_data = pifo_data_buffer[odrop_dout_0];
assign pifo_125_out_drop_valid = odrop_vld_0;

always @* begin
    free_mem_req_2 = 0;
    free_cell_id_2 = 0;
    if(odrop_vld_0) begin
        free_mem_req_2 = 1;
        // free_mem_addr_2 = odrop_dout_0;
        free_cell_id_2 = odrop_dout_0;
        // $display("DROP from pifo %d",odrop_pri_0);
    end
end

always @(posedge clk_125) begin
    if(rst_125) begin
        pifo_counter_reg <= 0;
    end
    else begin
        if(push_1)
            pifo_counter_reg = pifo_counter_reg + 1;
        
        if(odrop_vld_0) 
            pifo_counter_reg = pifo_counter_reg - 1;

        if(ovld_0) 
            pifo_counter_reg = pifo_counter_reg - 1;

        if(alloc_mem_success) begin  
            // pifo_data_buffer[alloc_mem_addr] <= pifo_125_in_data;
            pifo_data_buffer[alloc_cell_id] <= pifo_125_in_data;
        end
        if(!alloc_mem_success && push_1) begin
            $display("Error in pifo warp");
        end
    end
end


endmodule

