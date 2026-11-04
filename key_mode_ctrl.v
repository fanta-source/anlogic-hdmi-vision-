`timescale 1ns / 1ps

module key_mode_ctrl ( 
    input            clk,       
    input            rst_n, 
    input            key_in,  
    output reg [2:0] mode_sel   
); 

    reg [20:0] cnt_delay; 
    reg        key_reg; 

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt_delay <= 21'd0; 
            key_reg   <= 1'b1; 
        end else begin
            key_reg <= key_in; 
            if (key_in != key_reg) begin
                cnt_delay <= 21'd0;
            end else if (cnt_delay < 21'd1_500_000) begin
                cnt_delay <= cnt_delay + 1'b1; 
            end
        end
    end

    wire key_press = (cnt_delay == 21'd1_499_999) && (key_in == 1'b0); 

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mode_sel <= 3'd0;
        end else if (key_press) begin
            if (mode_sel >= 3'd4)
                mode_sel <= 3'd0; 
            else
                mode_sel <= mode_sel + 1'b1; 
        end
    end

endmodule