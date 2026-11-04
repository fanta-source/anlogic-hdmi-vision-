`timescale 1ns / 1ps

module sobel_detector #(
    parameter IMG_WIDTH   = 1280,
    parameter SOBEL_THRES = 8'd95  
)(
    input  wire        clk,
    input  wire        rst_n,

    input  wire        in_vsync,
    input  wire        in_de,
    input  wire [7:0]  in_gray,

    output reg         out_vsync,
    output reg         out_de,
    output reg         out_edge_data
);

    wire       m_vsync;
    wire       m_de;
    wire [7:0] w_p11, w_p12, w_p13;
    wire [7:0] w_p21, w_p22, w_p23;
    wire [7:0] w_p31, w_p32, w_p33;

    matrix_3x3_core #(
        .IMG_WIDTH(IMG_WIDTH)
    ) u_matrix_3x3_core (
        .clk       (clk),
        .rst_n     (rst_n),
        .in_vsync  (in_vsync),
        .in_de     (in_de),
        .in_data   (in_gray),
        .out_vsync (m_vsync),
        .out_de    (m_de),
        .p11       (w_p11),
        .p12       (w_p12),
        .p13       (w_p13),
        .p21       (w_p21),
        .p22       (w_p22),
        .p23       (w_p23),
        .p31       (w_p31),
        .p32       (w_p32),
        .p33       (w_p33)
    );

    reg [10:0] gx_p, gx_n;
    reg [10:0] gy_p, gy_n;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gx_p <= 11'd0;
            gx_n <= 11'd0;
            gy_p <= 11'd0;
            gy_n <= 11'd0;
        end else if (m_de) begin
            gx_p <= w_p13 + (w_p23 << 1) + w_p33;
            gx_n <= w_p11 + (w_p21 << 1) + w_p31;
            gy_p <= w_p11 + (w_p12 << 1) + w_p13;
            gy_n <= w_p31 + (w_p32 << 1) + w_p33;
        end
    end

    reg [10:0] abs_gx;
    reg [10:0] abs_gy;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            abs_gx <= 11'd0;
            abs_gy <= 11'd0;
        end else if (m_de) begin
            abs_gx <= (gx_p >= gx_n) ? (gx_p - gx_n) : (gx_n - gx_p);
            abs_gy <= (gy_p >= gy_n) ? (gy_p - gy_n) : (gy_n - gy_p);
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_edge_data <= 1'b0;
        end else if (m_de) begin
            if ((abs_gx + abs_gy) >= {3'd0, SOBEL_THRES})
                out_edge_data <= 1'b1;
            else
                out_edge_data <= 1'b0;
        end else begin
            out_edge_data <= 1'b0;
        end
    end

    reg [2:0] vsync_d;
    reg [2:0] de_d;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            vsync_d   <= 3'd0;
            de_d      <= 3'd0;
            out_vsync <= 1'b0;
            out_de    <= 1'b0;
        end else begin
            vsync_d   <= {vsync_d[1:0], m_vsync};
            de_d      <= {de_d[1:0], m_de};
            out_vsync <= vsync_d[2];
            out_de    <= de_d[2];
        end
    end

endmodule

module matrix_3x3_core #(
    parameter IMG_WIDTH = 1280
)(
    input  wire        clk,
    input  wire        rst_n,

    input  wire        in_vsync,
    input  wire        in_de,
    input  wire [7:0]  in_data,

    output reg         out_vsync,
    output reg         out_de,
    output reg  [7:0]  p11, p12, p13,
    output reg  [7:0]  p21, p22, p23,
    output reg  [7:0]  p31, p32, p33
);

    reg [11:0] col_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            col_cnt <= 12'd0;
        else if (in_de) begin
            if (col_cnt == IMG_WIDTH - 1)
                col_cnt <= 12'd0;
            else
                col_cnt <= col_cnt + 1'b1;
        end else begin
            col_cnt <= 12'd0;
        end
    end

    reg [7:0] ram_line1 [0:IMG_WIDTH-1];
    reg [7:0] ram_line2 [0:IMG_WIDTH-1];

    reg [7:0] line1_out;
    reg [7:0] line2_out;

    always @(posedge clk) begin
        if (in_de) begin
            ram_line1[col_cnt] <= in_data;
            line1_out          <= ram_line1[col_cnt];
        end
    end

    always @(posedge clk) begin
        if (in_de) begin
            ram_line2[col_cnt] <= line1_out;
            line2_out          <= ram_line2[col_cnt];
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            p11 <= 8'd0; p12 <= 8'd0; p13 <= 8'd0;
            p21 <= 8'd0; p22 <= 8'd0; p23 <= 8'd0;
            p31 <= 8'd0; p32 <= 8'd0; p33 <= 8'd0;
        end else if (in_de) begin
            p11 <= p12;
            p12 <= p13;
            p13 <= line2_out;

            p21 <= p22;
            p22 <= p23;
            p23 <= line1_out;

            p31 <= p32;
            p32 <= p33;
            p33 <= in_data;
        end
    end

    reg [1:0] vsync_d;
    reg [1:0] de_d;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            vsync_d   <= 2'd0;
            de_d      <= 2'd0;
            out_vsync <= 1'b0;
            out_de    <= 1'b0;
        end else begin
            vsync_d   <= {vsync_d[0], in_vsync};
            de_d      <= {de_d[0], in_de};
            out_vsync <= vsync_d[1];
            out_de    <= de_d[1];
        end
    end

endmodule