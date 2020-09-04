`timescale 1ns / 1ps
`include "panic_define.v"

module perf_counter #
(
    // Width of AXI stream interfaces in bits
    parameter AXIS_DATA_WIDTH = 256,
    // AXI stream tkeep signal width (words per cycle)
    parameter AXIS_KEEP_WIDTH = (AXIS_DATA_WIDTH/8),
    parameter TEST_MODE = 0


)
(
    input  wire                       clk,
    input  wire                       rst,

    /*
    * Send data output to the dma
    */
    input  wire [AXIS_DATA_WIDTH-1:0]          m_rx_axis_tdata,
    input  wire [AXIS_KEEP_WIDTH-1:0]          m_rx_axis_tkeep,
    input  wire                                m_rx_axis_tvalid,
    input  wire                                m_rx_axis_tready,
    input  wire                                m_rx_axis_tlast,


    /*
    * Receive data from the wire
    */
    input wire [AXIS_DATA_WIDTH-1:0]           s_rx_axis_tdata,
    input wire [AXIS_KEEP_WIDTH-1:0]           s_rx_axis_tkeep,
    input wire                                 s_rx_axis_tvalid,
    input wire                                 s_rx_axis_tready,
    input wire                                 s_rx_axis_tlast,
    
    input wire [4:0]                           s_flow_class
);

// reg [47:0] in_byte_counter;
// reg [47:0] out_byte_counter;

reg [31:0] in_pk_counter;
reg [31:0] out_pk_counter;
reg [47:0] in_frame_counter;
reg [47:0] out_frame_counter;

reg [11:0] inter_cycle_counter;
reg [31:0] inter_in_frame_counter[4:0];
reg [31:0] inter_out_frame_counter;
reg [31:0] last_inter_in_frame_counter[4:0];
reg [31:0] last_inter_out_frame_counter;
reg [31:0] max_in_frame_counter[4:0];
reg [31:0] max_out_frame_counter;


reg [63:0] cycle_counter;

reg [9:0] iter_counter;

// reg [15:0] out_keep_counter, in_keep_counter;


// ila_perf panic_perf_debug (
// 	.clk(clk), // input wire clk


// 	.probe0(s_rx_axis_tready), // input wire [0:0] probe0  
// 	.probe1({s_rx_axis_tkeep,s_rx_axis_tkeep,last_inter_in_frame_counter,last_inter_out_frame_counter,max_in_frame_counter,max_out_frame_counter,in_frame_counter,out_frame_counter,cycle_counter,in_pk_counter,out_pk_counter}), // input wire [511:0]  probe1 
// 	.probe2( 0), // input wire [63:0]  probe2 
// 	.probe3( s_rx_axis_tvalid), // input wire [0:0]  probe3 
// 	.probe4( s_rx_axis_tlast), // input wire [0:0]  probe4 
// 	.probe5( 0), // input wire [0:0]  probe5 
// 	.probe6( {{64{1'b1}}}), // input wire [63:0]  probe6 
// 	.probe7( 0), // input wire [0:0]  probe7  
// 	.probe8( 0) // input wire [0:0]  probe8
// );

// integer i;
// integer j;
// always @* begin
//     in_keep_counter = 0;
//     out_keep_counter = 0;
//     if(s_rx_axis_tvalid && s_rx_axis_tready) begin
//         in_keep_counter = 0;
//         for(i = 0; i < AXIS_KEEP_WIDTH; i=i+1) begin
//             if(s_rx_axis_tkeep[i] == 1) begin
//                 in_keep_counter = in_keep_counter + 1;
//             end
//         end
//     end

//     if(m_rx_axis_tvalid && m_rx_axis_tready) begin
//         out_keep_counter = 0;
//         for(j = 0; j < AXIS_KEEP_WIDTH; j=j+1) begin
//             if(m_rx_axis_tkeep[j] == 1) begin
//                 out_keep_counter = out_keep_counter + 1;
//             end
//         end
//     end
// end

always@(posedge clk) begin
    if(rst) begin
        in_frame_counter <= 0;
        out_frame_counter <= 0;
        in_pk_counter <= 0;
        out_pk_counter <= 0;
        cycle_counter <= 0;
        inter_cycle_counter <= 0;

        max_in_frame_counter[0] <= 0;
        max_in_frame_counter[1] <= 0;
        max_in_frame_counter[2] <= 0;
        max_in_frame_counter[3] <= 0;
        max_in_frame_counter[4] <= 0;

        max_out_frame_counter <= 0;
        inter_in_frame_counter[0] <= 0;
        inter_in_frame_counter[1] <= 0;
        inter_in_frame_counter[2] <= 0;
        inter_in_frame_counter[3] <= 0;
        inter_in_frame_counter[4] <= 0;



        inter_out_frame_counter <= 0;

        last_inter_in_frame_counter[0] <= 0;
        last_inter_in_frame_counter[1] <= 0;
        last_inter_in_frame_counter[2] <= 0;
        last_inter_in_frame_counter[3] <= 0;
        last_inter_in_frame_counter[4] <= 0;

        last_inter_out_frame_counter <= 0;

        iter_counter <= 0;
    end
    else begin
        cycle_counter <= cycle_counter + 1;
        inter_cycle_counter <= inter_cycle_counter + 1;

        if(s_rx_axis_tvalid && s_rx_axis_tready) begin
            in_frame_counter <= in_frame_counter + 1;
            if(s_flow_class == 0)
                inter_in_frame_counter[0] <= inter_in_frame_counter[0] + 1;
            if(s_flow_class == 1)
                inter_in_frame_counter[1] <= inter_in_frame_counter[1] + 1;
            if(s_flow_class == 2)
                inter_in_frame_counter[2] <= inter_in_frame_counter[2] + 1;
            if(s_flow_class == 3)
                inter_in_frame_counter[3] <= inter_in_frame_counter[3] + 1;
            if(s_flow_class == 4)
                inter_in_frame_counter[4] <= inter_in_frame_counter[4] + 1;
        end
        if(m_rx_axis_tvalid && m_rx_axis_tready)begin
            out_frame_counter <= out_frame_counter + 1;
            inter_out_frame_counter <= inter_out_frame_counter + 1;
        end
        if(s_rx_axis_tvalid && s_rx_axis_tready && s_rx_axis_tlast) begin
            in_pk_counter <= in_pk_counter + 1;
        end
        if(m_rx_axis_tvalid && m_rx_axis_tready && m_rx_axis_tlast) begin
            out_pk_counter <= out_pk_counter + 1;
        end

        if(inter_cycle_counter == 0) begin
            inter_in_frame_counter[0] <= 0;
            inter_in_frame_counter[1] <= 0;
            inter_in_frame_counter[2] <= 0;
            inter_in_frame_counter[3] <= 0;
            inter_in_frame_counter[4] <= 0;

            inter_out_frame_counter <= 0;

            last_inter_in_frame_counter[0] <= inter_in_frame_counter[0];
            last_inter_in_frame_counter[1] <= inter_in_frame_counter[1];
            last_inter_in_frame_counter[2] <= inter_in_frame_counter[2];
            last_inter_in_frame_counter[3] <= inter_in_frame_counter[3];
            last_inter_in_frame_counter[4] <= inter_in_frame_counter[4];

            last_inter_out_frame_counter <= inter_out_frame_counter;

            if(inter_in_frame_counter[0] > max_in_frame_counter[0]) begin
                max_in_frame_counter[0] <= inter_in_frame_counter[0];
            end
            if(inter_in_frame_counter[1] > max_in_frame_counter[1]) begin
                max_in_frame_counter[1] <= inter_in_frame_counter[1];
            end
            if(inter_in_frame_counter[2] > max_in_frame_counter[2]) begin
                max_in_frame_counter[2] <= inter_in_frame_counter[2];
            end
            if(inter_in_frame_counter[3] > max_in_frame_counter[3]) begin
                max_in_frame_counter[3] <= inter_in_frame_counter[3];
            end
            if(inter_in_frame_counter[4] > max_in_frame_counter[4]) begin
                max_in_frame_counter[4] <= inter_in_frame_counter[4];
            end


            if(inter_out_frame_counter > max_out_frame_counter) begin
                max_out_frame_counter <= inter_out_frame_counter;
            end

            if(TEST_MODE == 0) begin
                if(iter_counter > 1) begin
                    $display("--------------");
                    $display("- Traffic Group 1: %f Gbps " ,inter_in_frame_counter[0] * 512 * 1.0 / ((2**12) * 4.0) );
                    $display("- Traffic Group 2: %f Gbps " ,inter_in_frame_counter[1] * 512 * 1.0 / ((2**12) * 4.0) );
                    $display("- Traffic Group 3: %f Gbps " ,inter_in_frame_counter[2] * 512 * 1.0 / ((2**12) * 4.0) );
                end
            end
            else begin
                if(iter_counter > 1) begin
                    // $display("--------------");
                    $display("- Throughput %f Gbps " ,inter_in_frame_counter[3] * 512 * 1.0 / ((2**12) * 4.0) );
                end
            end
            
            
            iter_counter <= iter_counter + 1;
        end


    end
end

endmodule
