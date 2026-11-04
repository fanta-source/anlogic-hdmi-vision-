`timescale 1ns / 1ps

module osd_overlay( 
    input  wire        clk,           
    input  wire        rst_n,        

    input  wire        video_vs,      
    input  wire        video_de,      
    input  wire [23:0] video_rgb,    
    input  wire [11:0] pixel_x,      
    input  wire [11:0] pixel_y,      

    output reg         post_video_vs, 
    output reg         post_video_de, 
    output reg  [23:0] post_video_rgb
); 

    localparam OSD_X_START = 12'd1112; 
    localparam OSD_Y_START = 12'd40; 
    localparam OSD_WIDTH   = 12'd128; 
    localparam OSD_HEIGHT  = 12'd32; 

    wire [11:0] rel_x = pixel_x - OSD_X_START; 
    wire [11:0] rel_y = pixel_y - OSD_Y_START; 

    wire osd_en = (pixel_x >= OSD_X_START && pixel_x < OSD_X_START + OSD_WIDTH) && 
                  (pixel_y >= OSD_Y_START && pixel_y < OSD_Y_START + OSD_HEIGHT); 

    wire [11:0] rom_addr = osd_en ? ((rel_y[4:0] << 7) + rel_x[6:0]) : 12'd0;

    reg [0:0] mem [0:4095];
    reg       rom_data;

    initial begin
        $readmemb("anlogic_logo.dat", mem);
    end

    always @(posedge clk) begin
        rom_data <= mem[rom_addr];
    end

    reg [23:0] video_rgb_d1; 
    reg        osd_en_d1; 
    reg        video_vs_d1, video_de_d1; 

    always @(posedge clk) begin
        video_rgb_d1 <= video_rgb; 
        osd_en_d1    <= osd_en; 
        video_vs_d1  <= video_vs; 
        video_de_d1  <= video_de; 
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            post_video_vs  <= 1'b0; 
            post_video_de  <= 1'b0; 
            post_video_rgb <= 24'd0; 
        end else begin
            post_video_vs  <= video_vs_d1; 
            post_video_de  <= video_de_d1; 

            if (osd_en_d1 && (rom_data == 1'b1)) 
                post_video_rgb <= 24'hFFFF00; 
            else
                post_video_rgb <= video_rgb_d1; 
        end
    end

endmodule