`timescale 1ns / 1ps

module video_pipeline_top (
    input  wire        pixel_clk,
    input  wire        rst_n,
    input  wire        key3,
    input  wire [2:0]  mode_sel,

    input  wire        in_vs,
    input  wire        in_hs,
    input  wire        in_de,
    input  wire [23:0] in_rgb,

    output wire [2:0]  out_gesture_id, 
    output wire        is_locked,     

    output wire        out_vs,
    output wire        out_hs,
    output wire        out_de,
    output wire [23:0] out_rgb
);
    assign out_gesture_id = gesture_res;

    reg        r_raw_vs, r_raw_hs, r_raw_de;
    reg [23:0] r_raw_rgb;
    reg [11:0] cur_x, cur_y;
    reg        in_de_d;

    always @(posedge pixel_clk) begin
        r_raw_vs  <= in_vs;
        r_raw_hs  <= in_hs;
        r_raw_de  <= in_de;
        r_raw_rgb <= in_rgb;
    end

    always @(posedge pixel_clk or negedge rst_n) begin
        if (!rst_n) begin
            cur_x   <= 12'd0;
            cur_y   <= 12'd0;
            in_de_d <= 1'b0;
        end else begin
            in_de_d <= in_de;
            if (in_vs) begin
                cur_x <= 12'd0;
                cur_y <= 12'd0;
            end else if (in_de) begin
                cur_x <= cur_x + 1'b1;
            end else if (in_de_d && !in_de) begin
                cur_x <= 12'd0;
                cur_y <= cur_y + 1'b1;
            end
        end
    end

    wire       gray_vsync, gray_de;
    wire [7:0] gray_data;
    rgb2gray u_rgb2gray (  
        .clk(pixel_clk), .rst_n(rst_n),
        .in_vsync(in_vs), .in_de(in_de),
        .in_r(in_rgb[23:16]), .in_g(in_rgb[15:8]), .in_b(in_rgb[7:0]),
        .out_vsync(gray_vsync), .out_de(gray_de),
        .out_gray(gray_data), .out_binary()
    );
    wire [23:0] gray_rgb = {gray_data, gray_data, gray_data};

    wire sobel_vsync, sobel_de, sobel_edge;
    sobel_detector #(.IMG_WIDTH(1280), .SOBEL_THRES(8'd60)) u_sobel_detector (
        .clk(pixel_clk), .rst_n(rst_n),
        .in_vsync(gray_vsync), .in_de(gray_de), .in_gray(gray_data),
        .out_vsync(sobel_vsync), .out_de(sobel_de), .out_edge_data(sobel_edge)
    );
    wire [23:0] sobel_rgb = sobel_edge ? 24'hFF_FF_FF : 24'h00_00_00;

    wire hand_vsync, hand_de, hand_bin;
    wire [11:0] hand_x, hand_y;

    hand_extract_top #(.H_ACTIVE(1280), .V_ACTIVE(720)) u_hand_extract_top (
        .clk(pixel_clk), .rst_n(rst_n),
        .in_vsync(in_vs), .in_de(in_de), .in_rgb(in_rgb),
        .out_clk(), .out_vsync(hand_vsync), .out_de(hand_de),
        .out_x_pos(hand_x), .out_y_pos(hand_y),
        .hand_binary(hand_bin)
    );
    wire [23:0] hand_rgb = hand_bin ? 24'hFF_FF_FF : 24'h00_00_00;

    wire [2:0]  gesture_res;
    wire [11:0] box_x1, box_x2, box_y1, box_y2;

    gesture_recognizer u_gesture_recognizer (
        .clk        (pixel_clk),
        .rst_n      (rst_n),
        .key3       (key3),
        .vsync      (hand_vsync),
        .de         (hand_de),
        .x_pos      (hand_x),
        .y_pos      (hand_y),
        .hand_bin   (hand_bin),
        .box_xmin   (box_x1),
        .box_xmax   (box_x2),
        .box_ymin   (box_y1),
        .box_ymax   (box_y2),
        .gesture_id (gesture_res),
        .is_locked  (is_locked) 
    );

    wire        osd_vs, osd_hs, osd_de;
    wire [23:0] osd_rgb;

    osd_text_overlay u_osd_text_overlay (
        .clk        (pixel_clk),
        .rst_n      (rst_n),
        .in_vs      (hand_vsync),
        .in_hs      (r_raw_hs),
        .in_de      (hand_de),
        .in_rgb     (hand_rgb),
        .x_pos      (hand_x),
        .y_pos      (hand_y),
        .gesture_id (gesture_res),
        .box_xmin   (box_x1),
        .box_xmax   (box_x2),
        .box_ymin   (box_y1),
        .box_ymax   (box_y2),
        .out_vs     (osd_vs),
        .out_hs     (osd_hs),
        .out_de     (osd_de),
        .out_rgb    (osd_rgb)
    );

    wire [7:0] r = in_rgb[23:16];
    wire [7:0] g = in_rgb[15:8];
    wire [7:0] b = in_rgb[7:0];
    wire is_red_ball = (r > 8'd105) && (r > (g + 8'd45)) && (r > (b + 8'd45)) && (g < 8'd160);

    wire [11:0] ball_x_min, ball_x_max, ball_y_min, ball_y_max;
    wire        ball_valid;

    ball_tracker u_ball_tracker (
        .clk           (pixel_clk),
        .rst_n         (rst_n),
        .vsync         (in_vs),
        .de            (in_de),
        .pixel_x       (cur_x),
        .pixel_y       (cur_y),
        .is_ball_pixel (is_red_ball),
        .box_x_min     (ball_x_min),
        .box_x_max     (ball_x_max),
        .box_y_min     (ball_y_min),
        .box_y_max     (ball_y_max),
        .ball_valid    (ball_valid)
    );

    wire is_center_window = (cur_x >= 12'd320 && cur_x < 12'd960);
    wire [9:0] crop_ram_addr = cur_x - 12'd320;

    reg [23:0] line_buf_rgb   [0:639];
    reg        line_buf_sobel [0:639];

    always @(posedge pixel_clk) begin
        if (in_de && is_center_window) begin
            line_buf_rgb[crop_ram_addr]   <= in_rgb;
            line_buf_sobel[crop_ram_addr] <= sobel_edge;
        end
    end

    wire [9:0] read_ram_addr = (cur_x < 12'd640) ? cur_x[9:0] : (cur_x - 12'd640);
    wire [23:0] split_color_rgb = line_buf_rgb[read_ram_addr];
    wire        split_edge_bit  = line_buf_sobel[read_ram_addr];
    wire [23:0] split_sobel_rgb = split_edge_bit ? 24'hFF_FF_FF : 24'h10_10_10;

    wire [11:0] local_xmin = (ball_x_min >= 12'd320) ? (ball_x_min - 12'd320) : 12'd0;
    wire [11:0] local_xmax = (ball_x_max >= 12'd320) ? (ball_x_max - 12'd320) : 12'd0;
    wire [11:0] local_cx   = (local_xmin + local_xmax) >> 1;
    wire [11:0] center_y   = (ball_y_min + ball_y_max) >> 1;

    wire target_in_crop = ball_valid && (ball_x_max > 12'd320) && (ball_x_min < 12'd960);

    wire is_in_box = target_in_crop && (
        (((cur_y >= ball_y_min && cur_y <= ball_y_min + 3) || (cur_y <= ball_y_max && cur_y >= ball_y_max - 3)) && (read_ram_addr >= local_xmin && read_ram_addr <= local_xmax)) ||
        (((read_ram_addr >= local_xmin && read_ram_addr <= local_xmin + 3) || (read_ram_addr <= local_xmax && read_ram_addr >= local_xmax - 3)) && (cur_y >= ball_y_min && cur_y <= ball_y_max))
    );

    wire is_in_cross = target_in_crop && (
        (read_ram_addr == local_cx && cur_y >= center_y - 12 && cur_y <= center_y + 12) ||
        (cur_y == center_y && read_ram_addr >= local_cx - 12 && read_ram_addr <= local_cx + 12)
    );

    wire is_split_divider = (cur_x == 12'd639 || cur_x == 12'd640);
    wire [23:0] dual_view_base = (cur_x < 12'd640) ? split_sobel_rgb : split_color_rgb;

    wire [23:0] dual_view_rgb = is_split_divider ? 24'h00_FF_FF :
                                is_in_cross     ? 24'hFF_00_00 :
                                is_in_box       ? 24'h00_FF_00 :
                                dual_view_base;

    reg        mux_vs, mux_hs, mux_de;
    reg [23:0] mux_rgb;

    always @(posedge pixel_clk or negedge rst_n) begin
        if (!rst_n) begin
            mux_vs  <= 1'b0;
            mux_hs  <= 1'b0;
            mux_de  <= 1'b0;
            mux_rgb <= 24'd0;
        end else begin
            case (mode_sel)
                3'd0: begin
                    mux_vs  <= r_raw_vs;
                    mux_hs  <= r_raw_hs;
                    mux_de  <= r_raw_de;
                    mux_rgb <= r_raw_rgb;
                end
                3'd1: begin
                    mux_vs  <= gray_vsync;
                    mux_hs  <= r_raw_hs;
                    mux_de  <= gray_de;
                    mux_rgb <= gray_rgb;
                end
                3'd2: begin
                    mux_vs  <= sobel_vsync;
                    mux_hs  <= r_raw_hs;
                    mux_de  <= sobel_de;
                    mux_rgb <= sobel_rgb;
                end
                3'd3: begin
                    mux_vs  <= osd_vs;
                    mux_hs  <= osd_hs;
                    mux_de  <= osd_de;
                    mux_rgb <= osd_rgb;
                end
                3'd4: begin
                    mux_vs  <= in_vs;
                    mux_hs  <= in_hs;
                    mux_de  <= in_de;
                    mux_rgb <= dual_view_rgb;
                end
                default: begin
                    mux_vs  <= r_raw_vs;
                    mux_hs  <= r_raw_hs;
                    mux_de  <= r_raw_de;
                    mux_rgb <= r_raw_rgb;
                end
            endcase
        end
    end

    reg        mux_hs_d;
    reg [11:0] cur_x_d, cur_y_d;
    always @(posedge pixel_clk) begin
        mux_hs_d <= mux_hs;
        cur_x_d  <= cur_x;
        cur_y_d  <= cur_y;
    end
    assign out_hs = mux_hs_d;

    osd_overlay u_always_on_logo (
        .clk            (pixel_clk),
        .rst_n          (rst_n),
        .video_vs       (mux_vs),
        .video_de       (mux_de),
        .video_rgb      (mux_rgb),
        .pixel_x        (cur_x_d),
        .pixel_y        (cur_y_d),
        .post_video_vs  (out_vs),
        .post_video_de  (out_de),
        .post_video_rgb (out_rgb)
    );

endmodule