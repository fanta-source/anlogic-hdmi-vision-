`timescale 1ns / 1ps
module rgb2ycbcr_skin (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        in_vsync,
    input  wire        in_de,
    input  wire [23:0] in_rgb,

    output reg         out_vsync,
    output reg         out_de,
    output reg         bin_val
);

    wire [7:0] r = in_rgb[23:16];
    wire [7:0] g = in_rgb[15:8];
    wire [7:0] b = in_rgb[7:0];

    reg [16:0] y_pos;
    reg [16:0] cb_add, cb_sub;
    reg [16:0] cr_add, cr_sub;
    reg de_d1, vsync_d1;

    always @(posedge clk) begin
        de_d1    <= in_de;
        vsync_d1 <= in_vsync;

        y_pos    <= (17'd77 * r) + (17'd150 * g) + (17'd29 * b);
        cb_add   <= 17'd32768 + (17'd128 * b);
        cb_sub   <= (17'd43 * r) + (17'd85 * g);
        cr_add   <= 17'd32768 + (17'd128 * r);
        cr_sub   <= (17'd107 * g) + (17'd21 * b);
    end

    reg [7:0] y_val, cb_val, cr_val;
    reg de_d2, vsync_d2;
    wire [16:0] final_cb = (cb_add > cb_sub) ? (cb_add - cb_sub) : 17'd0;
    wire [16:0] final_cr = (cr_add > cr_sub) ? (cr_add - cr_sub) : 17'd0;

    always @(posedge clk) begin
        de_d2    <= de_d1;
        vsync_d2 <= vsync_d1;

        y_val    <= y_pos[15:8];
        cb_val   <= final_cb[15:8];
        cr_val   <= final_cr[15:8];
    end

    wire is_skin = (cb_val >= 8'd95  && cb_val <= 8'd127) &&
                   (cr_val >= 8'd136 && cr_val <= 8'd170) &&
                   (y_val  >= 8'd60);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bin_val   <= 1'b0;
            out_de    <= 1'b0;
            out_vsync <= 1'b0;
        end else begin
            out_de    <= de_d2;
            out_vsync <= vsync_d2;
            bin_val   <= is_skin ? 1'b1 : 1'b0;
        end
    end

endmodule