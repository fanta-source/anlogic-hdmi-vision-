module rgb2gray(  
    input  wire        clk,        
    input  wire        rst_n,      
      
    input  wire        in_vsync,   
    input  wire        in_de,      
    input  wire [7:0]  in_r,      
    input  wire [7:0]  in_g,       
    input  wire [7:0]  in_b,      
      
    output reg         out_vsync, 
    output reg         out_de,    
    output reg  [7:0]  out_gray,  
    output reg         out_binary  
);  

parameter THRESHOLD = 8'd128;


reg [15:0] r_mult, g_mult, b_mult;  
reg        vsync_d1, de_d1;

reg [15:0] gray_sum;  
reg        vsync_d2, de_d2;  

always @(posedge clk or negedge rst_n) begin  
    if (!rst_n) begin  
        r_mult   <= 16'd0;  
        g_mult   <= 16'd0;  
        b_mult   <= 16'd0;  
        vsync_d1 <= 1'b0;
        de_d1    <= 1'b0;
    end else begin  
        r_mult   <= in_r * 8'd77;  
        g_mult   <= in_g * 8'd150;  
        b_mult   <= in_b * 8'd29;  
        vsync_d1 <= in_vsync;
        de_d1    <= in_de;
    end  
end  

always @(posedge clk or negedge rst_n) begin  
    if (!rst_n) begin  
        gray_sum <= 16'd0;  
        vsync_d2 <= 1'b0;  
        de_d2    <= 1'b0;  
    end else begin  
        gray_sum <= r_mult + g_mult + b_mult;  
        vsync_d2 <= vsync_d1;  
        de_d2    <= de_d1;  
    end  
end  

always @(posedge clk or negedge rst_n) begin  
    if (!rst_n) begin  
        out_vsync  <= 1'b0;  
        out_de     <= 1'b0;  
        out_gray   <= 8'd0;  
        out_binary <= 1'b0;
    end else begin  
        out_vsync  <= vsync_d2;  
        out_de     <= de_d2;  
        
        out_gray   <= gray_sum[15:8]; 

        if (gray_sum[15:8] >= THRESHOLD)
            out_binary <= 1'b1;
        else
            out_binary <= 1'b0;
    end  
end  

endmodule