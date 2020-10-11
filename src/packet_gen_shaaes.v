`timescale 1ns / 1ps

module packet_gen_shaaes;

reg  clk;
reg rst;
reg start;
always begin
    clk = ~clk; 
    #2;
end

initial begin

    $display("   ___                              ");
    $display("  / __\\_ __  ___  _ __   ____ _   _ ");
    $display(" / _\\ | '__|/ _ \\| '_ \\ |_  /| | | |");
    $display("/ /   | |  |  __/| | | | / / | |_| |");
    $display("\\/    |_|   \\___||_| |_|/___| \\__, |");
    $display("                              |___/ ");
    $display("--------Simulation Parameter--------");
    $display("|* Simulation Frequency: 250Mhz    |");
    $display("|* Logging Interval: 4K cycles/log |");
    $display("|* Packet Size: 1500B              |");
    $display("|* Policy: Strict Priority         |");
    $display("|* Traffic Pattern 1:              |");
    $display("|   [G1: 30G, G2: 50G, G3: 20G]    |");
    $display("|* Traffic Pattern 2:              |");
    $display("|   [G1: 10G, G2: 60G, G3: 30G]    |");
    $display("|* Traffic Pattern 3:              |");
    $display("|   [G1: 30G, G2: 30G, G3: 40G]    |");
    $display("|* Traffic Pattern 4:              |");
    $display("|   [G1: 60G, G2: 40G, G3:  0G]    |");
    $display("|* Chain: -> S(S1,S2)-> A(A1,A2)-> |");
    $display("|                                  |");
    $display("|* More detail about the chainning |");
    $display("|  model please reference Fig.12   |");
    $display("|  in Frenzy paper                 |");
    $display("|----------------------------------|");

    clk = 0;
    rst = 1;
    start = 0;
    
    #1000;
    rst = 0;
    #600;
    start = 1;
end

localparam AXIS_DATA_WIDTH = 512;
localparam AXIS_KEEP_WIDTH = AXIS_DATA_WIDTH / 8;
localparam PORTS = 1;

reg  [PORTS*AXIS_DATA_WIDTH-1:0]    rx_axis_tdata;
reg  [PORTS*AXIS_KEEP_WIDTH-1:0]    rx_axis_tkeep;
reg  [PORTS-1:0]                    rx_axis_tvalid;
wire [PORTS-1:0]                    rx_axis_tready;
reg  [PORTS-1:0]                    rx_axis_tlast;
reg  [PORTS-1:0]                    rx_axis_tuser;

/*
* Receive data input
*/
wire [PORTS*AXIS_DATA_WIDTH-1:0]    panic_rx_axis_tdata;
wire [PORTS*AXIS_KEEP_WIDTH-1:0]    panic_rx_axis_tkeep;
wire [PORTS-1:0]                    panic_rx_axis_tvalid;
reg  [PORTS-1:0]                    panic_rx_axis_tready=1;
wire [PORTS-1:0]                    panic_rx_axis_tlast;
wire [PORTS-1:0]                    panic_rx_axis_tuser;


panic #
(
    /* MEMORY PARAMETER */
    // Width of AXI memory data bus in bits, normal is 512
    .AXI_DATA_WIDTH(AXIS_DATA_WIDTH),
    // Width of panic memory address bus in bits
    .AXI_ADDR_WIDTH(18),

    /*AXIS INTERFACE PARAMETER*/
    // Width of AXI stream interfaces in bits, normal is 512
    .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),
    .AXIS_KEEP_WIDTH(AXIS_KEEP_WIDTH),
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
    .INIT_CREDIT_NUM(2),
    .ENGINE_NUM(4),
    .TEST_MODE(0)

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
    .s_rx_axis_tuser(rx_axis_tuser),

    /*
    * Send data output to the dma
    */
    .m_rx_axis_tdata(panic_rx_axis_tdata),
    .m_rx_axis_tkeep(panic_rx_axis_tkeep),
    .m_rx_axis_tvalid(panic_rx_axis_tvalid),
    .m_rx_axis_tready(1),
    .m_rx_axis_tlast(panic_rx_axis_tlast)
);

reg [31:0] test_counter = 0;

reg [63:0] counter;
reg [63:0] c_counter;
reg [63:0] cycle_counter;
reg [63:0] byte_counter;

wire [15:0] packet_len;
wire [15:0] header_length;
assign packet_len = 23;
assign header_length = (packet_len)*64 - 14;

reg [4:0] flow_id;

reg [4:0] traffic_pattern1 [9:0];
reg [4:0] traffic_pattern2 [9:0];
reg [4:0] traffic_pattern3 [9:0];
reg [4:0] traffic_pattern4 [9:0];

always@(*) begin

    rx_axis_tvalid = 0;
    rx_axis_tlast = 0;
    if(start) begin
        if(cycle_counter%128 <= 101) begin
            rx_axis_tvalid = 1;
            if(c_counter == 0) begin
                rx_axis_tdata = 512'h1514131211100F0E0D0C0B0A0908070605040302010081B90801020001006501A8C06401A8C0B7B5114000400000F2050045000855545352515AD5D4D3D2D1DA; // udp header
                rx_axis_tdata[16*8 +: 8] = header_length[15:8];
                rx_axis_tdata[17*8 +: 8] = header_length[7:0];
                rx_axis_tdata[35*8 +: 8] = flow_id;
                rx_axis_tkeep = {64{1'b1}};
            end
            else begin
                rx_axis_tdata = c_counter + counter;  
                rx_axis_tkeep = {64{1'b1}};
            end
            if(c_counter == packet_len-1) begin
                rx_axis_tkeep = {64{1'b1}};
                rx_axis_tlast <= 1;
            end
        end
    end
         

end

always@(posedge clk) begin
    if(rst) begin
        counter <= 1;
        c_counter <= 0;
        cycle_counter <= 0;
        flow_id <= 0;
    end
    else begin
        if(start) begin
            cycle_counter <= cycle_counter + 1;
        end
        if(start && rx_axis_tready && rx_axis_tvalid) begin
            c_counter<= c_counter+1;
            if(c_counter == packet_len-1) begin
                c_counter <= 0;
                counter <= counter + 1;
            end
        end
        if(start && rx_axis_tlast && rx_axis_tvalid && rx_axis_tready) begin
            if(counter < 800) begin
                if(counter == 2)
                    $display("**************\n Switch to Pattern 1\n**************");
                flow_id <= traffic_pattern1[counter %10] ;
            end
            else if (counter < 1600) begin
                if(counter == 801)
                    $display("**************\n Switch to Pattern 2\n**************");
                flow_id <= traffic_pattern2[counter %10] ;
            end
            else if (counter < 2800) begin
                if(counter == 1601)
                    $display("**************\n Switch to Pattern 3\n**************");
                flow_id <= traffic_pattern3[counter %10] ;
            end
            else if (counter < 3600) begin
                if(counter == 2801)
                    $display("**************\n Switch to Pattern 4\n**************");
                flow_id <= traffic_pattern4[counter %10] ;
            end
            else begin
                $finish;
            end
        end
    end
end

reg [63:0] check_seq_counter;
reg [63:0] check_counter;
reg [2:0] pk_start;
always@(posedge clk) begin
    if(rst) begin
        check_counter <= 0;
        check_seq_counter <= 1;
        pk_start <= 1;
        byte_counter <= 0;
    end
    if(panic_rx_axis_tvalid && panic_rx_axis_tready) begin
        check_counter <= check_counter +1;
        byte_counter <= byte_counter + 512/8;
        if(pk_start == 1) begin
            pk_start <= 2;
        end
        else if (pk_start == 2) begin
            check_seq_counter = panic_rx_axis_tdata - check_counter;
            pk_start <= 0;
        end
        else if(!panic_rx_axis_tlast) begin
            if( panic_rx_axis_tkeep != {64{1'b1}}) begin
                $display("ERROR in compare %x with  %x",panic_rx_axis_tdata, check_counter + check_seq_counter);
            end
        end
        else if(panic_rx_axis_tlast) begin
            if(panic_rx_axis_tkeep != {64{1'b1}} || check_counter != 22) begin
                $display("ERROR in compare %x with  %x",panic_rx_axis_tdata, check_counter + check_seq_counter);
            end
            pk_start <= 1;
            check_counter <= 0;
            check_seq_counter <=check_seq_counter + 1; 
        end
    end

end

// define traffic pattern
always @(posedge clk) begin
    if(rst) begin
        traffic_pattern1[0] <= 0;
        traffic_pattern1[1] <= 1;
        traffic_pattern1[2] <= 2;
        traffic_pattern1[3] <= 0;
        traffic_pattern1[4] <= 1;
        traffic_pattern1[5] <= 1;
        traffic_pattern1[6] <= 0;
        traffic_pattern1[7] <= 1;
        traffic_pattern1[8] <= 2;
        traffic_pattern1[9] <= 1;

        traffic_pattern2[0] <= 0;
        traffic_pattern2[1] <= 1;
        traffic_pattern2[2] <= 2;
        traffic_pattern2[3] <= 1;
        traffic_pattern2[4] <= 1;
        traffic_pattern2[5] <= 1;
        traffic_pattern2[6] <= 2;
        traffic_pattern2[7] <= 1;
        traffic_pattern2[8] <= 1;
        traffic_pattern2[9] <= 2;

        traffic_pattern3[0] <= 0;
        traffic_pattern3[1] <= 1;
        traffic_pattern3[2] <= 2;
        traffic_pattern3[3] <= 0;
        traffic_pattern3[4] <= 2;
        traffic_pattern3[5] <= 1;
        traffic_pattern3[6] <= 0;
        traffic_pattern3[7] <= 2;
        traffic_pattern3[8] <= 1;
        traffic_pattern3[9] <= 2;

        traffic_pattern4[0] <= 0;
        traffic_pattern4[1] <= 0;
        traffic_pattern4[2] <= 0;
        traffic_pattern4[3] <= 0;
        traffic_pattern4[4] <= 1;
        traffic_pattern4[5] <= 1;
        traffic_pattern4[6] <= 0;
        traffic_pattern4[7] <= 1;
        traffic_pattern4[8] <= 0;
        traffic_pattern4[9] <= 1;

    end

end
endmodule
