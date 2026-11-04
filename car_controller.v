`timescale 1ns / 1ps
module car_controller (
    input  wire        clk,         
    input  wire        rst_n,
    input  wire [2:0]  mode_sel,     
    input  wire        is_locked,    // 锁定信号
    input  wire [2:0]  gesture_id,   

    // TB6612 硬件控制信号
    output reg         tb6612_stby,  
    output reg         motor_l_in1,  
    output reg         motor_l_in2,  
    output reg         motor_r_in1,  
    output reg         motor_r_in2,  
    output wire        motor_l_pwm,  
    output wire        motor_r_pwm   
);

    reg [4:0] prescaler;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            prescaler <= 5'd0;
        else
            prescaler <= prescaler + 1'b1;
    end

    wire pwm_tick = (prescaler == 5'd31);

    reg [7:0] pwm_cnt;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pwm_cnt <= 8'd0;
        else if (pwm_tick)
            pwm_cnt <= pwm_cnt + 1'b1;
    end

    reg [7:0] l_duty;
    reg [7:0] r_duty;

    assign motor_l_pwm = (pwm_cnt < l_duty);
    assign motor_r_pwm = (pwm_cnt < r_duty);

    localparam RUN_TIMEOUT = 27'd74_250_000;

    reg        is_locked_d;
    reg [26:0] run_timer;
    reg        run_enable;

    wire lock_start = (is_locked && !is_locked_d);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            is_locked_d <= 1'b0;
            run_timer   <= 27'd0;
            run_enable  <= 1'b0;
        end else begin
            is_locked_d <= is_locked;

            if (!is_locked || (mode_sel != 3'd3)) begin
                run_timer  <= 27'd0;
                run_enable <= 1'b0;
            end 
            else if (lock_start) begin
                run_timer  <= RUN_TIMEOUT;
                run_enable <= 1'b1;
            end 
            else if (run_enable) begin
                if (run_timer > 27'd0) begin
                    run_timer <= run_timer - 1'b1;
                end else begin
                    run_enable <= 1'b0;
                end
            end
        end
    end

    localparam SPEED_HIGH = 8'd150; 
    localparam SPEED_SLOW = 8'd80; 
    localparam SPEED_ZERO = 8'd0; 

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tb6612_stby <= 1'b0;
            motor_l_in1 <= 1'b0;
            motor_l_in2 <= 1'b0;
            motor_r_in1 <= 1'b0;
            motor_r_in2 <= 1'b0;
            l_duty      <= SPEED_ZERO;
            r_duty      <= SPEED_ZERO;
        end 
        else if (!run_enable) begin
            tb6612_stby <= 1'b0;
            motor_l_in1 <= 1'b0;
            motor_l_in2 <= 1'b0;
            motor_r_in1 <= 1'b0;
            motor_r_in2 <= 1'b0;
            l_duty      <= SPEED_ZERO;
            r_duty      <= SPEED_ZERO;
        end 
        else begin
            tb6612_stby <= 1'b1;

            case (gesture_id)
                3'd1: begin 
                    motor_l_in1 <= 1'b1; motor_l_in2 <= 1'b0; 
                    motor_r_in1 <= 1'b1; motor_r_in2 <= 1'b0; 
                    l_duty      <= SPEED_HIGH;
                    r_duty      <= SPEED_HIGH;
                end

                3'd3: begin 
                    motor_l_in1 <= 1'b1; motor_l_in2 <= 1'b0; 
                    motor_r_in1 <= 1'b1; motor_r_in2 <= 1'b0; 
                    l_duty      <= SPEED_SLOW;
                    r_duty      <= SPEED_HIGH;
                end

                3'd4: begin 
                    motor_l_in1 <= 1'b1; motor_l_in2 <= 1'b0; 
                    motor_r_in1 <= 1'b1; motor_r_in2 <= 1'b0; 
                    l_duty      <= SPEED_HIGH;
                    r_duty      <= SPEED_SLOW;
                end

                3'd2: begin 
                    motor_l_in1 <= 1'b0; motor_l_in2 <= 1'b0;
                    motor_r_in1 <= 1'b0; motor_r_in2 <= 1'b0;
                    l_duty      <= SPEED_ZERO;
                    r_duty      <= SPEED_ZERO;
                end

                default: begin 
                    motor_l_in1 <= 1'b0; motor_l_in2 <= 1'b0;
                    motor_r_in1 <= 1'b0; motor_r_in2 <= 1'b0;
                    l_duty      <= SPEED_ZERO;
                    r_duty      <= SPEED_ZERO;
                end
            endcase
        end
    end

endmodule