`timescale 1ns / 1ps

module ball_tracker (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        vsync,         
    input  wire        de,            
    input  wire [11:0] pixel_x,        
    input  wire [11:0] pixel_y,       
    input  wire        is_ball_pixel,  

    output reg  [11:0] box_x_min,    
    output reg  [11:0] box_x_max,
    output reg  [11:0] box_y_min,
    output reg  [11:0] box_y_max,
    output reg         ball_valid    
);

    reg vsync_d;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) vsync_d <= 1'b0;
        else        vsync_d <= vsync;
    end
    wire frame_start = (vsync && !vsync_d);

    reg [5:0] run_len;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) run_len <= 6'd0;
        else if (de) begin
            if (is_ball_pixel) begin
                if (run_len < 6'd31) run_len <= run_len + 1'b1;
            end else begin
                run_len <= 6'd0;
            end
        end
    end
 
    wire core_pixel = (run_len >= 6'd8);

    reg [23:0] acc_x;
    reg [23:0] acc_y;
    reg [17:0] acc_cnt;

  
    reg [11:0] t_xmin, t_xmax, t_ymin, t_ymax;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc_x   <= 24'd0;
            acc_y   <= 24'd0;
            acc_cnt <= 18'd0;
            t_xmin  <= 12'd1280;
            t_xmax  <= 12'd0;
            t_ymin  <= 12'd720;
            t_ymax  <= 12'd0;
        end else if (frame_start) begin
            acc_x   <= 24'd0;
            acc_y   <= 24'd0;
            acc_cnt <= 18'd0;
            t_xmin  <= 12'd1280;
            t_xmax  <= 12'd0;
            t_ymin  <= 12'd720;
            t_ymax  <= 12'd0;
        end else if (de && core_pixel) begin
            acc_cnt <= acc_cnt + 1'b1;
            acc_x   <= acc_x + pixel_x;
            acc_y   <= acc_y + pixel_y;

            if (pixel_x < t_xmin) t_xmin <= pixel_x;
            if (pixel_x > t_xmax) t_xmax <= pixel_x;
            if (pixel_y < t_ymin) t_ymin <= pixel_y;
            if (pixel_y > t_ymax) t_ymax <= pixel_y;
        end
    end

    reg [2:0] frame_div;
    wire update_tick = frame_start && (frame_div == 3'd3);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            frame_div <= 3'd0;
        end else if (frame_start) begin
            if (frame_div >= 3'd3) 
                frame_div <= 3'd0;
            else
                frame_div <= frame_div + 1'b1;
        end
    end

    wire raw_valid = (acc_cnt > 18'd500) && (t_xmax > t_xmin) && (t_ymax > t_ymin);

    wire [11:0] span_x = (t_xmax - t_xmin);
    wire [11:0] span_y = (t_ymax - t_ymin);
    wire [11:0] radius = (span_x + span_y) >> 2; 

    wire [11:0] target_cx = (t_xmin + t_xmax) >> 1;
    wire [11:0] target_cy = (t_ymin + t_ymax) >> 1;

    wire [11:0] calc_xmin = (target_cx > radius) ? (target_cx - radius) : 12'd0;
    wire [11:0] calc_xmax = (target_cx + radius < 12'd1280) ? (target_cx + radius) : 12'd1279;
    wire [11:0] calc_ymin = (target_cy > radius) ? (target_cy - radius) : 12'd0;
    wire [11:0] calc_ymax = (target_cy + radius < 12'd720) ? (target_cy + radius) : 12'd719;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            box_x_min  <= 12'd0;
            box_x_max  <= 12'd0;
            box_y_min  <= 12'd0;
            box_y_max  <= 12'd0;
            ball_valid <= 1'b0;
        end else if (update_tick) begin
            if (raw_valid) begin
                if (!ball_valid) begin
                    box_x_min  <= calc_xmin;
                    box_x_max  <= calc_xmax;
                    box_y_min  <= calc_ymin;
                    box_y_max  <= calc_ymax;
                    ball_valid <= 1'b1;
                end else begin
                    box_x_min  <= ((box_x_min * 3) + calc_xmin) >> 2;
                    box_x_max  <= ((box_x_max * 3) + calc_xmax) >> 2;
                    box_y_min  <= ((box_y_min * 3) + calc_ymin) >> 2;
                    box_y_max  <= ((box_y_max * 3) + calc_ymax) >> 2;
                    ball_valid <= 1'b1;
                end
            end else begin
                ball_valid <= 1'b0;
            end
        end
    end

endmodule