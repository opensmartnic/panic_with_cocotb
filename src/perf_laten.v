`timescale 1ns / 1ps
`include "panic_define.v"

module perf_laten #
(
    // Width of AXI stream interfaces in bits
    parameter AXIS_DATA_WIDTH = 256,
    // AXI stream tkeep signal width (words per cycle)
    parameter AXIS_KEEP_WIDTH = (AXIS_DATA_WIDTH/8)


)
(
    input  wire                       clk,
    input  wire                       rst,

    /*
    * Receive data from the wire
    */
    input wire                                  s_rx_axis_tvalid,
    input wire [`PANIC_DESC_TS_SIZE-1:0]        s_rx_axis_ts,
    
    input wire [`PANIC_DESC_TS_SIZE-1:0]       timestamp,
    input wire [4:0]                           s_flow_class
);

// reg [47:0] in_byte_counter;
// reg [47:0] out_byte_counter;

reg     s_rx_axis_tvalid_reg;
reg [4:0] s_flow_class_reg;


reg [31:0] in_pk_counter;
reg [`PANIC_DESC_TS_SIZE-1:0] cur_pk_latency;

reg [63:0] latency_bucket [4:0];
reg [31:0] counter_bucket [4:0];

always@(posedge clk) begin
    if(rst) begin
        in_pk_counter <= 0;
        cur_pk_latency <= 0;

        s_rx_axis_tvalid_reg<= 0;
        s_flow_class_reg <= 0;
    end
    else begin
        s_rx_axis_tvalid_reg <= s_rx_axis_tvalid;
        s_flow_class_reg <= s_flow_class;
        if(s_rx_axis_tvalid)begin
            in_pk_counter <= in_pk_counter + 1;
            cur_pk_latency <= timestamp - s_rx_axis_ts;
            // $display("Latency %d ", s_flow_class ,timestamp - s_rx_axis_ts);
        end
    end
end
always @(posedge clk) begin
    if(rst) begin
        latency_bucket[0] =0;
        latency_bucket[1] =0;
        latency_bucket[2] =0;
        latency_bucket[3] =0;
        latency_bucket[4] =0;

        counter_bucket[0] =0;
        counter_bucket[1] =0;
        counter_bucket[2] =0;
        counter_bucket[3] =0;
        counter_bucket[4] =0;
    end
    else if(s_rx_axis_tvalid_reg) begin
        latency_bucket[s_flow_class_reg] <= cur_pk_latency + latency_bucket[s_flow_class_reg];
        counter_bucket[s_flow_class_reg] <= counter_bucket[s_flow_class_reg] + 1;
    end
end
endmodule
