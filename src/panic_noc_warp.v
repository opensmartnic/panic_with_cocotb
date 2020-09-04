`timescale 1ns / 1ps

// `include "./Open-Source-Network-on-Chip-Router-RTL/src/clib/c_functions.v"
`include "./Open-Source-Network-on-Chip-Router-RTL/src/clib/c_constants.v"
`include "./Open-Source-Network-on-Chip-Router-RTL/src/rtr_constants.v"
`include "./Open-Source-Network-on-Chip-Router-RTL/src/vcr_constants.v"
// `include "./Open-Source-Network-on-Chip-Router-RTL/src/parameters.sv"
/*
 * AXI4-Stream switch
 */
module panic_noc_warp #
(
    // Number of AXI stream inputs
    parameter S_COUNT = 4,
    // Number of AXI stream outputs
    parameter M_COUNT = 4,
    // Width of AXI stream interfaces in bits
    parameter DATA_WIDTH = 8,
    // Propagate tkeep signal
    parameter KEEP_ENABLE = (DATA_WIDTH>8),
    // tkeep signal width (words per cycle)
    parameter KEEP_WIDTH = (DATA_WIDTH/8),
    // Propagate tid signal
    parameter ID_ENABLE = 0,
    // tid signal width
    parameter ID_WIDTH = 8,
    // tdest signal width
    // must be wide enough to uniquely address outputs
    parameter DEST_WIDTH = $clog2(M_COUNT),
    // Propagate tuser signal
    parameter USER_ENABLE = 1,
    // tuser signal width
    parameter USER_WIDTH = 1
   
)
(
    input  wire                   clk,
    input  wire                   rst,

    /*
     * AXI Stream inputs
     */
    input  wire [S_COUNT*DATA_WIDTH-1:0] s_axis_tdata,
    input  wire [S_COUNT*KEEP_WIDTH-1:0] s_axis_tkeep,
    input  wire [S_COUNT-1:0]            s_axis_tvalid,
    output reg  [S_COUNT-1:0]            s_axis_tready,
    input  wire [S_COUNT-1:0]            s_axis_tlast,
    // input  wire [S_COUNT*ID_WIDTH-1:0]   s_axis_tid,
    input  wire [S_COUNT*DEST_WIDTH-1:0] s_axis_tdest,
    input  wire [S_COUNT*USER_WIDTH-1:0] s_axis_tuser,

    /*
     * AXI Stream outputs
     */
    output wire  [M_COUNT*DATA_WIDTH-1:0] m_axis_tdata,
    output wire  [M_COUNT*KEEP_WIDTH-1:0] m_axis_tkeep,
    output wire  [M_COUNT-1:0]            m_axis_tvalid,
    input  wire  [M_COUNT-1:0]            m_axis_tready,
    output wire  [M_COUNT-1:0]            m_axis_tlast,
    // output wire [M_COUNT*ID_WIDTH-1:0]   m_axis_tid,
    output wire  [M_COUNT*DEST_WIDTH-1:0] m_axis_tdest,
    output wire  [M_COUNT*USER_WIDTH-1:0] m_axis_tuser
);

function integer clogb(input integer argument);
   integer 		     i;
   begin
      clogb = 0;
      for(i = argument - 1; i > 0; i = i >> 1)
	clogb = clogb + 1;
   end
endfunction

// compute ceiling of base-th root of argument
function integer croot(input integer argument, input integer base);
   integer i;
   integer j;
   begin
      croot = 0;
      i = 0;
      while(i < argument)
	begin
	   croot = croot + 1;
	   i = 1;
	   for(j = 0; j < base; j = j + 1)
	     i = i * croot;
	end
   end
endfunction

// population count (count ones)
function integer pop_count(input integer argument);
   integer i;
   begin
      pop_count = 0;
      for(i = argument; i > 0; i = i >> 1)
	pop_count = pop_count + (i & 1);
   end
endfunction

// compute the length of the longest disjoint suffix among two values
function integer suffix_length(input integer value1, input integer value2);
   integer v1, v2;
   begin
      v1 = value1;
      v2 = value2;
      suffix_length = 0;
      while(v1 != v2)
	begin
	   suffix_length = suffix_length + 1;
	   v1 = v1 >> 1;
	   v2 = v2 >> 1;
	end
   end
endfunction

localparam channel_latency = 1;
// select network topology
localparam topology = `TOPOLOGY_FBFLY;

// total buffer size per port in flits
localparam buffer_size = 8;

// number of message classes (e.g. request, reply)
localparam num_message_classes = 1;

// number of resource classes (e.g. minimal, adaptive)
localparam num_resource_classes = 1;

// number of VCs per class
localparam num_vcs_per_class = 1;

// total number of nodes
localparam num_nodes = 9;

// number of dimensions in network
localparam num_dimensions = 1;

// number of nodes per router (a.k.a. concentration factor)
localparam num_nodes_per_router = 8;

// select packet format
localparam packet_format = `PACKET_FORMAT_HEAD_TAIL;

// select type of flow control
localparam flow_ctrl_type = `FLOW_CTRL_TYPE_CREDIT;

// make incoming flow control signals bypass the output VC state tracking logic
localparam flow_ctrl_bypass = 0;

// maximum payload length (in flits)
localparam max_payload_length = 32;

// minimum payload length (in flits)
localparam min_payload_length = 0;

// select router implementation
localparam router_type = `ROUTER_TYPE_COMBINED;

// enable link power management
localparam enable_link_pm = 0;

// width of flit payload data
localparam flit_data_width = 512;

// configure error checking logic
localparam error_capture_mode = `ERROR_CAPTURE_MODE_NO_HOLD;

// filter out illegal destination ports
// (the intent is to allow synthesis to optimize away the logic associated with 
// such turns)
localparam restrict_turns = 1;

// store lookahead routing info in pre-decoded form
// (only useful with dual-path routing enable)
localparam predecode_lar_info = 1;

// select routing function type
localparam routing_type = `ROUTING_TYPE_PHASED_DOR;

// select order of dimension traversal
localparam dim_order = `DIM_ORDER_ASCENDING;

// use input register as part of the flit buffer (wormhole router only)
localparam input_stage_can_hold = 0;

// select implementation variant for flit buffer register file
localparam fb_regfile_type = `REGFILE_TYPE_FF_2D;

// select flit buffer management scheme
localparam fb_mgmt_type = `FB_MGMT_TYPE_STATIC;

// improve timing for peek access
localparam fb_fast_peek = 1;

// EXPERIMENTAL:
// for dynamic buffer management, only reserve a buffer slot for a VC while it 
// is active (i.e., while a packet is partially transmitted)
// (NOTE: This is currently broken!)
localparam disable_static_reservations = 0;

// use explicit pipeline register between flit buffer and crossbar?
localparam explicit_pipeline_register = 0;

// gate flit buffer write port if bypass succeeds
// (requires explicit pipeline register; may increase cycle time)
localparam gate_buffer_write = 0;

// enable dual-path allocation
localparam dual_path_alloc = 1;

// resolve output conflicts when using dual-path allocation via arbitration
// (otherwise, kill if more than one fast-path request per output port)
localparam dual_path_allow_conflicts = 0;

// only mask fast-path requests if any slow path requests are ready
localparam dual_path_mask_on_ready = 1;

// precompute input-side arbitration decision one cycle ahead
localparam precomp_ivc_sel = 0;

// precompute output-side arbitration decision one cycle ahead
localparam precomp_ip_sel = 0;

// select whether to exclude full or non-empty VCs from VC allocation
localparam elig_mask = `ELIG_MASK_FULL;

// select implementation variant for VC allocator
localparam vc_alloc_type = `VC_ALLOC_TYPE_SEP_IF;

// select which arbiter type to use for VC allocator
localparam vc_alloc_arbiter_type = `ARBITER_TYPE_ROUND_ROBIN_BINARY;

// prefer empty VCs over non-empty ones in VC allocation
localparam vc_alloc_prefer_empty = 0;

// select implementation variant for switch allocator
localparam sw_alloc_type = `SW_ALLOC_TYPE_SEP_IF;

// select which arbiter type to use for switch allocator
localparam sw_alloc_arbiter_type = `ARBITER_TYPE_ROUND_ROBIN_BINARY;

// select speculation type for switch allocator
localparam sw_alloc_spec_type = `SW_ALLOC_SPEC_TYPE_REQ;

// select implementation variant for crossbar
localparam crossbar_type = `CROSSBAR_TYPE_MUX;

localparam reset_type = `RESET_TYPE_ASYNC;

// width required to select individual resource class
localparam resource_class_idx_width = clogb(num_resource_classes);

// total number of packet classes
localparam num_packet_classes = num_message_classes * num_resource_classes;

// number of VCs
localparam num_vcs = num_packet_classes * num_vcs_per_class;

// width required to select individual VC
localparam vc_idx_width = clogb(num_vcs);

// total number of routers
localparam num_routers
   = (num_nodes + num_nodes_per_router - 1) / num_nodes_per_router;

// number of routers in each dimension
localparam num_routers_per_dim = croot(num_routers, num_dimensions);

// width required to select individual router in a dimension
localparam dim_addr_width = clogb(num_routers_per_dim);

// width required to select individual router in entire network
localparam router_addr_width = num_dimensions * dim_addr_width;

// connectivity within each dimension
localparam connectivity
   = (topology == `TOPOLOGY_MESH) ?
      `CONNECTIVITY_LINE :
      (topology == `TOPOLOGY_TORUS) ?
      `CONNECTIVITY_RING :
      (topology == `TOPOLOGY_FBFLY) ?
      `CONNECTIVITY_FULL :
      -1;

// number of adjacent routers in each dimension
localparam num_neighbors_per_dim
   = ((connectivity == `CONNECTIVITY_LINE) ||
(connectivity == `CONNECTIVITY_RING)) ?
      2 :
      (connectivity == `CONNECTIVITY_FULL) ?
      (num_routers_per_dim - 1) :
      -1;

// number of input and output ports on router
localparam num_ports
   = num_dimensions * num_neighbors_per_dim + num_nodes_per_router;

// width required to select individual port
localparam port_idx_width = clogb(num_ports);

// width required to select individual node at current router
localparam node_addr_width = clogb(num_nodes_per_router);

// width required for lookahead routing information
localparam lar_info_width = port_idx_width + resource_class_idx_width;

// total number of bits required for storing routing information
localparam dest_info_width
   = (routing_type == `ROUTING_TYPE_PHASED_DOR) ? 
      (num_resource_classes * router_addr_width + node_addr_width) : 
      -1;

// total number of bits required for routing-related information
localparam route_info_width = lar_info_width + dest_info_width;

// width of flow control signals
localparam flow_ctrl_width
   = (flow_ctrl_type == `FLOW_CTRL_TYPE_CREDIT) ? (1 + vc_idx_width) :
      -1;

// width of link management signals
localparam link_ctrl_width = enable_link_pm ? 1 : 0;

// width of flit control signals
localparam flit_ctrl_width
   = (packet_format == `PACKET_FORMAT_HEAD_TAIL) ? 
      (1 + vc_idx_width + 1 + 1) : 
      (packet_format == `PACKET_FORMAT_TAIL_ONLY) ? 
      (1 + vc_idx_width + 1) : 
      (packet_format == `PACKET_FORMAT_EXPLICIT_LENGTH) ? 
      (1 + vc_idx_width + 1) : 
      -1;

// channel width
localparam channel_width
   = link_ctrl_width + flit_ctrl_width + flit_data_width;

// use atomic VC allocation
localparam atomic_vc_allocation = (elig_mask == `ELIG_MASK_USED);

// number of pipeline stages in the channels
localparam num_channel_stages = channel_latency - 1;



wire [0:num_ports*channel_width-1] channel_in_ip;
wire [0:num_ports*flow_ctrl_width-1] flow_ctrl_out_ip;
wire [0:num_ports-1] 		flit_valid_in_ip;
wire [0:num_ports-1] 		cred_valid_out_ip;

wire [0:num_ports*channel_width-1] 	channel_out_op;
wire [0:num_ports*flow_ctrl_width-1] flow_ctrl_in_op;
wire [0:num_ports-1] 		flit_valid_out_op;
wire [0:num_ports-1] 		cred_valid_in_op;

wire [0:router_addr_width-1] 		router_address;

reg 					run;

generate
    genvar n;

    for (n = 0; n < S_COUNT; n = n + 1) begin : noc_input
        reg [15:0] input_credit_counter;
        reg if_head;
        
        wire [0:flow_ctrl_width-1] flow_ctrl_out;
        reg [0:channel_width-1] channel_dly;

        assign flow_ctrl_out = flow_ctrl_out_ip[n*flow_ctrl_width:(n+1)*flow_ctrl_width-1];
        assign channel_in_ip[n*channel_width:(n+1)*channel_width-1] = channel_dly;

         // find the packet header
        always @ (posedge clk) begin
            if(rst) begin
                if_head <= 1;
            end
            else begin
                if(s_axis_tready[n] && s_axis_tvalid[n] && if_head) begin
                    if_head <= 0;
                end

                if(s_axis_tready[n] && s_axis_tvalid[n] && s_axis_tlast[n +: 1]) begin
                    if_head <= 1;
                end
            end
        end

        always @* begin
           channel_dly  = {channel_width{1'b0}};
           s_axis_tready[n +: 1] = (input_credit_counter > 1); // TODO: add real VCS

           if(s_axis_tready[n] && s_axis_tvalid[n]) begin
               // channel_dly[0] = 1;
               channel_dly[0] = 1; // flit valid
               // channel_dly[1] = s_axis_tuser[n*USER_WIDTH +: USER_WIDTH]; // flit vcs
               channel_dly[1] = if_head;
               channel_dly[2] = s_axis_tlast[n +: 1];
               if(if_head) begin
                  channel_dly[3] = 0;
                  channel_dly[4:6] = s_axis_tdest[n*DEST_WIDTH +: DEST_WIDTH];
                  // channel_dly[12] = 1;
                  channel_dly[20] = s_axis_tuser[n*USER_WIDTH +: USER_WIDTH];
                  channel_dly[21 : 21 + 2] = s_axis_tdest[n*DEST_WIDTH +: DEST_WIDTH];

                  channel_dly[64:64+`PANIC_DESC_WIDTH] = s_axis_tdata[n*DATA_WIDTH +: `PANIC_DESC_WIDTH];
               end
               else begin
                  channel_dly[3:channel_width-1] = s_axis_tdata[n*DATA_WIDTH +: DATA_WIDTH];
               end
               
           end
        end

        integer i;
        always @(posedge clk) begin
           if(rst) begin
              
               input_credit_counter = buffer_size;

           end
           else begin
              if(flow_ctrl_out) begin  // credit valid in
                 input_credit_counter = input_credit_counter + 1;
              end

              if(channel_dly[0]) begin  // sned flit valid
                 input_credit_counter = input_credit_counter - 1;
              end
           end
        end

    end

endgenerate

// assign flow_ctrl_out = flow_ctrl_out_ip[n*flow_ctrl_width:(n+1)*flow_ctrl_width-1];
assign channel_in_ip[8*channel_width:(8+1)*channel_width-1] = 0;

////////// receive logic//////////////

generate
    genvar m;

    for (m = 0; m < M_COUNT; m = m + 1) begin : noc_output
        

        reg [DATA_WIDTH-1:0]      s_output_fifo_tdata;
        reg [KEEP_WIDTH-1:0]      s_output_fifo_tkeep;
        reg                       s_output_fifo_tvalid;
        wire                      s_output_fifo_tready;
        reg                       s_output_fifo_tlast;
        reg [DEST_WIDTH-1:0]      s_output_fifo_tdest;
        reg [USER_WIDTH-1:0]      s_output_fifo_tuser;
        reg [DEST_WIDTH-1:0]      out_dest_addr, out_dest_addr_reg;
        reg [USER_WIDTH-1:0]      out_user, out_user_reg;
        reg                      if_header;

        reg [15:0]                output_fifo_counter;
        reg [15:0]                output_credit_counter;
        

        reg  [0:flow_ctrl_width-1] flow_ctrl_in;
        wire  [0:channel_width-1] channel_dly_o;

        assign flow_ctrl_in_op[m*flow_ctrl_width:(m+1)*flow_ctrl_width-1] = flow_ctrl_in;
        assign channel_dly_o = channel_out_op[m*channel_width:(m+1)*channel_width-1];

        axis_fifo #(
            .DEPTH(buffer_size * KEEP_WIDTH),
            .DATA_WIDTH(DATA_WIDTH),
            .KEEP_ENABLE(1),
            .KEEP_WIDTH(KEEP_WIDTH),
            .LAST_ENABLE(1),
            .ID_ENABLE(0),
            .DEST_ENABLE(1),
            .DEST_WIDTH(DEST_WIDTH),
            .USER_ENABLE(1),
            .USER_WIDTH(USER_WIDTH),
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
            .m_axis_tdata(m_axis_tdata[m*DATA_WIDTH +: DATA_WIDTH]),
            .m_axis_tkeep(m_axis_tkeep[m*KEEP_WIDTH +: KEEP_WIDTH]),
            .m_axis_tvalid(m_axis_tvalid[m +: 1]),
            .m_axis_tready(m_axis_tready[m +: 1]),
            .m_axis_tlast(m_axis_tlast[m +: 1]),
            .m_axis_tdest(m_axis_tdest[m*DEST_WIDTH +: DEST_WIDTH]),
            .m_axis_tuser(m_axis_tuser[m*USER_WIDTH +: USER_WIDTH])
        );


        integer i;
        always @(posedge clk) begin
           if(rst) begin

               output_credit_counter = buffer_size;

           end
           else begin
              if(channel_dly_o[0]) begin  // receive flit
                 output_credit_counter = output_credit_counter - 1;
              end

               if(m_axis_tvalid[m +: 1] && m_axis_tready[m +: 1]) begin  // buffer out
                 output_credit_counter = output_credit_counter + 1;
              end
           end
        end


        always @* begin
            s_output_fifo_tvalid = 0;
            s_output_fifo_tdata  = 0;
            s_output_fifo_tlast  = 0;
            s_output_fifo_tdest  = 0;
            s_output_fifo_tuser  = 0;

            out_dest_addr = out_dest_addr_reg;
            out_user = out_user_reg;
            if_header = 0;

            flow_ctrl_in = 0;
            

            if(s_output_fifo_tready && channel_dly_o[0]) begin

               s_output_fifo_tvalid = 1;
               if_header           = channel_dly_o[1];
               s_output_fifo_tlast = channel_dly_o[2];
               // s_output_fifo_tuser = channel_dly_o[1]; // need check
               
               
               if(if_header) begin
                  s_output_fifo_tdata[0 +: `PANIC_DESC_WIDTH] = channel_dly_o[64:64+`PANIC_DESC_WIDTH];
                  out_dest_addr = channel_dly_o[21 : 21 + 2];
                  out_user =  channel_dly_o[20];
                  // $display("CEHCK VC IF THE SMAE: %d -- %d", channel_dly_o[1], channel_dly_o[20]);
               end
               else begin
                  s_output_fifo_tdata = channel_dly_o[3:channel_width-1];
               end
            end

            s_output_fifo_tdest = out_dest_addr;
            s_output_fifo_tuser = out_user;

            if(m_axis_tvalid[m +: 1] && m_axis_tready[m +: 1]) begin
               flow_ctrl_in[0] = 1;
               // flow_ctrl_in[1] = m_axis_tuser[m*USER_WIDTH +: USER_WIDTH];
            end
            
        end

        reg [0  : `PANIC_DESC_LEN_SIZE -1] output_length_counter, output_length_counter_reg;
        // find the packet header
        always @ (posedge clk) begin
            if(rst) begin
                output_length_counter_reg <= 0;
                out_dest_addr_reg <= 0;
                out_user_reg <= 0;
            end
            else begin
                output_length_counter_reg <= output_length_counter;
                out_dest_addr_reg <= out_dest_addr;
                out_user_reg <= out_user;
            end
        end


        // calculate the tkeep bit
        always @* begin
            output_length_counter = output_length_counter_reg;
            s_output_fifo_tkeep = 0;
            if(s_output_fifo_tvalid && s_output_fifo_tready && if_header) begin // parse panic header
                // if this lenghth = 0, menas there is only 1 cycle descriptor
                output_length_counter = s_output_fifo_tdata[`PANIC_DESC_LEN_OF   +: `PANIC_DESC_LEN_SIZE];

                s_output_fifo_tkeep = {{(DATA_WIDTH - `PANIC_CREDIT_WIDTH)/8{1'd0}},{256/8{1'd1}}};
            end
            else if(s_output_fifo_tvalid && s_output_fifo_tready && !if_header) begin // calculate data length
                if(output_length_counter >= 64) begin
                    s_output_fifo_tkeep = {64{1'd1}};
                    output_length_counter = output_length_counter - 64;
                end
                else begin
                    s_output_fifo_tkeep = {64{1'd1}} >> (64 - output_length_counter);
                    // s_output_fifo_tkeep = {{(64 - output_length_counter/8){1'd0}},{output_length_counter{1'd1}}};
                    output_length_counter = 0;
                end
            end
        end

    end

endgenerate

assign flow_ctrl_in_op[8*flow_ctrl_width:(8+1)*flow_ctrl_width-1] = 0;

assign router_address = 1;
   router_wrap
     #(.topology(topology),
       .buffer_size(buffer_size),
       .num_message_classes(num_message_classes),
       .num_resource_classes(num_resource_classes),
       .num_vcs_per_class(num_vcs_per_class),
       .num_nodes(num_nodes),
       .num_dimensions(num_dimensions),
       .num_nodes_per_router(num_nodes_per_router),
       .packet_format(packet_format),
       .flow_ctrl_type(flow_ctrl_type),
       .flow_ctrl_bypass(flow_ctrl_bypass),
       .max_payload_length(max_payload_length),
       .min_payload_length(min_payload_length),
       .router_type(router_type),
       .enable_link_pm(enable_link_pm),
       .flit_data_width(flit_data_width),
       .error_capture_mode(error_capture_mode),
       .restrict_turns(restrict_turns),
       .predecode_lar_info(predecode_lar_info),
       .routing_type(routing_type),
       .dim_order(dim_order),
       .input_stage_can_hold(input_stage_can_hold),
       .fb_regfile_type(fb_regfile_type),
       .fb_mgmt_type(fb_mgmt_type),
       .explicit_pipeline_register(explicit_pipeline_register),
       .dual_path_alloc(dual_path_alloc),
       .dual_path_allow_conflicts(dual_path_allow_conflicts),
       .dual_path_mask_on_ready(dual_path_mask_on_ready),
       .precomp_ivc_sel(precomp_ivc_sel),
       .precomp_ip_sel(precomp_ip_sel),
       .elig_mask(elig_mask),
       .vc_alloc_type(vc_alloc_type),
       .vc_alloc_arbiter_type(vc_alloc_arbiter_type),
       .vc_alloc_prefer_empty(vc_alloc_prefer_empty),
       .sw_alloc_type(sw_alloc_type),
       .sw_alloc_arbiter_type(sw_alloc_arbiter_type),
       .sw_alloc_spec_type(sw_alloc_spec_type),
       .crossbar_type(crossbar_type),
       .reset_type(reset_type))
   rtr
     (.clk(clk),
      .reset(rst),
      .router_address(router_address),
      .channel_in_ip(channel_in_ip),
      .flow_ctrl_out_ip(flow_ctrl_out_ip),
      .channel_out_op(channel_out_op),
      .flow_ctrl_in_op(flow_ctrl_in_op),
      .error());
   

endmodule