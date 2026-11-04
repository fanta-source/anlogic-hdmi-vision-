module matrix_3x3_1bit #(
    parameter H_ACTIVE = 1280
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       in_de,
    input  wire       in_vsync,
    input  wire       in_bin,

    output reg        out_de,
    output reg        out_vsync,

    output reg        p11, p12, p13,
    output reg        p21, p22, p23,
    output reg        p31, p32, p33
);

    reg line_buf1 [0:H_ACTIVE-1];
    reg line_buf2 [0:H_ACTIVE-1];

    reg [11:0] col_cnt;
    reg row1_out, row2_out;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            col_cnt <= 12'd0;
        else if (in_vsync)
            col_cnt <= 12'd0;
        else if (in_de) begin
            if (col_cnt == H_ACTIVE - 1)
                col_cnt <= 12'd0;
            else
                col_cnt <= col_cnt + 1'b1;
        end
    end

    always @(posedge clk) begin
        if (in_de) begin
            row2_out <= line_buf1[col_cnt];
            line_buf1[col_cnt] <= in_bin;

            row1_out <= line_buf2[col_cnt];
            line_buf2[col_cnt] <= row2_out;
        end
    end

    always @(posedge clk) begin
        if (in_de) begin
            {p11, p12, p13} <= {p12, p13, row1_out};
            {p21, p22, p23} <= {p22, p23, row2_out};
            {p31, p32, p33} <= {p32, p33, in_bin};
        end
    end

    reg de_d1, de_d2;
    reg vsync_d1, vsync_d2;
    always @(posedge clk) begin
        de_d1 <= in_de;       de_d2 <= de_d1;       out_de <= de_d2;
        vsync_d1 <= in_vsync; vsync_d2 <= vsync_d1; out_vsync <= vsync_d2;
    end

endmodule