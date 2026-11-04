`timescale 1ns / 1ps

module hand_extract_top #(
    parameter H_ACTIVE = 1280,
    parameter V_ACTIVE = 720
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        in_vsync,
    input  wire        in_de,
    input  wire [23:0] in_rgb,

    output wire        out_clk,
    output wire [11:0] out_x_pos,
    output wire [11:0] out_y_pos,
    output wire        hand_binary,

    output wire        out_vsync,
    output wire        out_de,
    output reg  [23:0] out_rgb,

    output wire [2:0]  gesture_id
);

    wire skin_vsync;
    wire skin_de;
    wire skin_bin;

    rgb2ycbcr_skin u_skin (
        .clk       (clk),
        .rst_n     (rst_n),
        .in_vsync  (in_vsync),
        .in_de     (in_de),
        .in_rgb    (in_rgb),
        .out_vsync (skin_vsync),
        .out_de    (skin_de),
        .bin_val   (skin_bin)
    );

    assign gesture_id = 3'd0;

    reg line_buf0 [0:H_ACTIVE-1];
    reg line_buf1 [0:H_ACTIVE-1];

    reg [11:0] col_cnt;

    reg p_top;
    reg p_mid;
    reg p_bottom;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            col_cnt  <= 12'd0;
            p_top    <= 1'b0;
            p_mid    <= 1'b0;
            p_bottom <= 1'b0;
        end else if (skin_de) begin
            if (col_cnt < H_ACTIVE - 1)
                col_cnt <= col_cnt + 12'd1;
            else
                col_cnt <= 12'd0;

            p_top    <= line_buf1[col_cnt];
            p_mid    <= line_buf0[col_cnt];
            p_bottom <= skin_bin;

            line_buf1[col_cnt] <= line_buf0[col_cnt];
            line_buf0[col_cnt] <= skin_bin;
        end else begin
            col_cnt <= 12'd0;
        end
    end

    reg p11, p12, p13;
    reg p21, p22, p23;
    reg p31, p32, p33;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            p11 <= 1'b0;
            p12 <= 1'b0;
            p13 <= 1'b0;
            p21 <= 1'b0;
            p22 <= 1'b0;
            p23 <= 1'b0;
            p31 <= 1'b0;
            p32 <= 1'b0;
            p33 <= 1'b0;
        end else if (skin_de) begin
            p11 <= p12;
            p12 <= p13;
            p13 <= p_top;

            p21 <= p22;
            p22 <= p23;
            p23 <= p_mid;

            p31 <= p32;
            p32 <= p33;
            p33 <= p_bottom;
        end
    end

    wire [3:0] sum_ones;

    assign sum_ones =
        {3'd0, p11} + {3'd0, p12} + {3'd0, p13} +
        {3'd0, p21} + {3'd0, p22} + {3'd0, p23} +
        {3'd0, p31} + {3'd0, p32} + {3'd0, p33};

    reg hand_filtered;
    reg de_d;
    reg vsync_d;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hand_filtered <= 1'b0;
            de_d          <= 1'b0;
            vsync_d       <= 1'b0;
        end else begin
            hand_filtered <= (sum_ones >= 4'd5);
            de_d          <= skin_de;
            vsync_d       <= skin_vsync;
        end
    end

    reg [11:0] x_cnt;
    reg [11:0] y_cnt;
    reg        de_d_last;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_cnt     <= 12'd0;
            y_cnt     <= 12'd0;
            de_d_last <= 1'b0;
        end else if (vsync_d) begin
            x_cnt     <= 12'd0;
            y_cnt     <= 12'd0;
            de_d_last <= 1'b0;
        end else begin
            de_d_last <= de_d;

            if (de_d) begin
                if (x_cnt < H_ACTIVE - 1)
                    x_cnt <= x_cnt + 12'd1;
                else
                    x_cnt <= 12'd0;
            end else begin
                x_cnt <= 12'd0;

                if (de_d_last) begin
                    if (y_cnt < V_ACTIVE - 1)
                        y_cnt <= y_cnt + 12'd1;
                    else
                        y_cnt <= 12'd0;
                end
            end
        end
    end

    assign out_clk     = clk;
    assign out_x_pos   = x_cnt;
    assign out_y_pos   = y_cnt;
    assign hand_binary = hand_filtered;

    assign out_vsync   = vsync_d;
    assign out_de      = de_d;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            out_rgb <= 24'h000000;
        else if (hand_filtered)
            out_rgb <= 24'hFFFFFF;
        else
            out_rgb <= 24'h000000;
    end

endmodule