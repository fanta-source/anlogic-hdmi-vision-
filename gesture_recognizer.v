`timescale 1ns / 1ps
module gesture_recognizer #(
    parameter ROI_XMIN = 12'd360,
    parameter ROI_XMAX = 12'd920,
    parameter ROI_YMIN = 12'd110,
    parameter ROI_YMAX = 12'd610,

    parameter SCAN_INTERVAL_FRAMES = 8'd15
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        key3,
    input  wire        vsync,
    input  wire        de,
    input  wire [11:0] x_pos,
    input  wire [11:0] y_pos,
    input  wire        hand_bin,

    output wire [11:0] box_xmin,
    output wire [11:0] box_xmax,
    output wire [11:0] box_ymin,
    output wire [11:0] box_ymax,
    output reg  [2:0]  gesture_id,   // 0:NONE, 1:FORWARD, 2:STOP, 3:LEFT, 4:RIGHT
    output wire        is_locked    
);

    assign box_xmin = ROI_XMIN;
    assign box_xmax = ROI_XMAX;
    assign box_ymin = ROI_YMIN;
    assign box_ymax = ROI_YMAX;

    wire in_roi = (x_pos >= ROI_XMIN) && (x_pos <= ROI_XMAX) &&
                  (y_pos >= ROI_YMIN) && (y_pos <= ROI_YMAX);

    wire valid_hand = hand_bin & in_roi;

    reg vsync_d;
    always @(posedge clk) vsync_d <= vsync;
    wire frame_end = (vsync_d && !vsync);

localparam integer KEY_DEBOUNCE_CYCLES = 1485000;

reg        key3_meta;
reg        key3_sync;
reg        key3_stable;
reg        key3_stable_d;
reg [20:0] key3_cnt;

wire key3_down;
wire key3_press;

assign key3_down  = ~key3_sync;
assign key3_press = key3_stable & ~key3_stable_d;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        key3_meta     <= 1'b0;
        key3_sync     <= 1'b0;
        key3_stable   <= 1'b0;
        key3_stable_d <= 1'b0;
        key3_cnt      <= 21'd0;
    end else begin
        key3_meta <= ~key3;
        key3_sync <= key3_meta;

        if (key3_down != key3_stable) begin
            if (key3_cnt < KEY_DEBOUNCE_CYCLES - 1) begin
                key3_cnt <= key3_cnt + 1'b1;
            end else begin
                key3_stable <= key3_down;
                key3_cnt    <= 21'd0;
            end
        end else begin
            key3_cnt <= 21'd0;
        end

        key3_stable_d <= key3_stable;
    end
end

    reg [23:0] roi_hand_area;
    reg [23:0] prev_area;

    wire probe1 = (y_pos == 12'd230);
    wire probe2 = (y_pos == 12'd270);

    reg [3:0] fingers_p1, fingers_p2;
    reg [3:0] filt1, filt2;
    reg       state1, state2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fingers_p1 <= 4'd0; filt1 <= 4'd0; state1 <= 1'b0;
            fingers_p2 <= 4'd0; filt2 <= 4'd0; state2 <= 1'b0;
        end else if (frame_end) begin
            fingers_p1 <= 4'd0; filt1 <= 4'd0; state1 <= 1'b0;
            fingers_p2 <= 4'd0; filt2 <= 4'd0; state2 <= 1'b0;
        end else if (de && in_roi) begin
            //线 1
            if (probe1) begin
                if (valid_hand) begin
                    if (filt1 < 4'd7) filt1 <= filt1 + 1'b1;
                    else if (!state1) begin state1 <= 1'b1; fingers_p1 <= fingers_p1 + 1'b1; end
                end else begin
                    if (filt1 > 4'd0) filt1 <= filt1 - 1'b1;
                    else state1 <= 1'b0;
                end
            end
            //线 2
            if (probe2) begin
                if (valid_hand) begin
                    if (filt2 < 4'd7) filt2 <= filt2 + 1'b1;
                    else if (!state2) begin state2 <= 1'b1; fingers_p2 <= fingers_p2 + 1'b1; end
                end else begin
                    if (filt2 > 4'd0) filt2 <= filt2 - 1'b1;
                    else state2 <= 1'b0;
                end
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            roi_hand_area <= 24'd0;
            prev_area     <= 24'd0;
        end else if (frame_end) begin
            prev_area     <= roi_hand_area;
            roi_hand_area <= 24'd0;
        end else if (de && valid_hand) begin
            roi_hand_area <= roi_hand_area + 1'b1;
        end
    end

    wire [3:0] detected_fingers = (fingers_p1 >= fingers_p2) ? fingers_p1 : fingers_p2;

    reg [2:0] cur_frame_gesture;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cur_frame_gesture <= 3'd0;
        end else if (frame_end) begin
            if (prev_area < 24'd5000) begin
                cur_frame_gesture <= 3'd0; // 无手 (NONE)
            end
            else if (detected_fingers == 4'd0 && prev_area > 24'd12000) begin
                cur_frame_gesture <= 3'd1; // FORWARD (拳头)
            end
            else if (detected_fingers == 4'd1) begin
                cur_frame_gesture <= 3'd3; // LEFT (比1)
            end
            else if (detected_fingers == 4'd2 || detected_fingers == 4'd3) begin
                cur_frame_gesture <= 3'd4; // RIGHT (比3)
            end
            else if (detected_fingers >= 4'd4 || prev_area > 24'd55000) begin
                cur_frame_gesture <= 3'd2; // STOP (张开手)
            end else begin
                cur_frame_gesture <= 3'd0;
            end
        end
    end

    reg       scan_locked;
    reg [2:0] locked_gesture;
    reg [7:0] scan_interval_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gesture_id        <= 3'd0;
            locked_gesture    <= 3'd0;
            scan_locked       <= 1'b0;
            scan_interval_cnt <= 8'd0;
        end else begin

            if (key3_press) begin

                if (!scan_locked) begin
                    if (cur_frame_gesture != 3'd0) begin
                        scan_locked       <= 1'b1;
                        locked_gesture    <= cur_frame_gesture;
                        gesture_id        <= cur_frame_gesture;
                        scan_interval_cnt <= 8'd0;
                    end
                end else begin
                    scan_locked       <= 1'b0;
                    locked_gesture    <= 3'd0;
                    gesture_id        <= 3'd0;

                    scan_interval_cnt <= 8'd0;
                end

            end else if (!scan_locked && frame_end) begin

                if (scan_interval_cnt != 8'd0) begin
                    scan_interval_cnt <= scan_interval_cnt - 8'd1;
                end else begin
                    if (cur_frame_gesture != 3'd0)
                        gesture_id <= cur_frame_gesture;
                    else
                        gesture_id <= 3'd0;

                    scan_interval_cnt <= SCAN_INTERVAL_FRAMES - 8'd1;
                end
            end
        end
    end
     assign is_locked = scan_locked;
endmodule