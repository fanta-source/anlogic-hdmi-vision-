`timescale 1ns / 1ps
module osd_text_overlay (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        in_vs,
    input  wire        in_hs,
    input  wire        in_de,
    input  wire [23:0] in_rgb,
    input  wire [11:0] x_pos,
    input  wire [11:0] y_pos,

    input  wire [2:0]  gesture_id,
    input  wire [11:0] box_xmin,
    input  wire [11:0] box_xmax,
    input  wire [11:0] box_ymin,
    input  wire [11:0] box_ymax,

    output reg         out_vs,
    output reg         out_hs,
    output reg         out_de,
    output reg  [23:0] out_rgb
);

    wire on_border_x = (x_pos == box_xmin || x_pos == box_xmin+1 || x_pos == box_xmax || x_pos == box_xmax-1);
    wire on_border_y = (y_pos == box_ymin || y_pos == box_ymin+1 || y_pos == box_ymax || y_pos == box_ymax-1);

    //十字
    wire is_box = ((on_border_x && (y_pos >= box_ymin && y_pos <= box_ymax)) ||
                   (on_border_y && (x_pos >= box_xmin && x_pos <= box_xmax)));

    wire in_osd_bg   = (x_pos >= 12'd30 && x_pos < 12'd240 && y_pos >= 12'd30 && y_pos < 12'd80);
    wire in_text_box = (x_pos >= 12'd40 && x_pos < 12'd232 && y_pos >= 12'd40 && y_pos < 12'd72);

    wire [7:0] char_idx  = (x_pos - 12'd40) >> 4; 
    wire [2:0] char_x    = (x_pos - 12'd40) >> 1; 
    wire [3:0] char_y    = (y_pos - 12'd40) >> 1; 

    reg [7:0] ascii_code;
    always @(*) begin
        case (char_idx)
            8'd0: ascii_code = "C";
            8'd1: ascii_code = "M";
            8'd2: ascii_code = "D";
            8'd3: ascii_code = ":";
            8'd4: ascii_code = " ";
            default: begin
                case (gesture_id)
                    3'd1: begin // FORWARD
                        case (char_idx)
                            8'd5:  ascii_code = "F";
                            8'd6:  ascii_code = "O";
                            8'd7:  ascii_code = "R";
                            8'd8:  ascii_code = "W";
                            8'd9:  ascii_code = "A";
                            8'd10: ascii_code = "R";
                            8'd11: ascii_code = "D";
                            default: ascii_code = " ";
                        endcase
                    end
                    3'd2: begin // STOP
                        case (char_idx)
                            8'd5:  ascii_code = "S";
                            8'd6:  ascii_code = "T";
                            8'd7:  ascii_code = "O";
                            8'd8:  ascii_code = "P";
                            default: ascii_code = " ";
                        endcase
                    end
                    3'd3: begin // LEFT
                        case (char_idx)
                            8'd5:  ascii_code = "L";
                            8'd6:  ascii_code = "E";
                            8'd7:  ascii_code = "F";
                            8'd8:  ascii_code = "T";
                            default: ascii_code = " ";
                        endcase
                    end
                    3'd4: begin // RIGHT
                        case (char_idx)
                            8'd5:  ascii_code = "R";
                            8'd6:  ascii_code = "I";
                            8'd7:  ascii_code = "G";
                            8'd8:  ascii_code = "H";
                            8'd9:  ascii_code = "T";
                            default: ascii_code = " ";
                        endcase
                    end
                    default: begin // NONE
                        case (char_idx)
                            8'd5:  ascii_code = "N";
                            8'd6:  ascii_code = "O";
                            8'd7:  ascii_code = "N";
                            8'd8:  ascii_code = "E";
                            default: ascii_code = " ";
                        endcase
                    end
                endcase
            end
        endcase
    end

    reg [7:0] font_row;
    always @(*) begin
        case (ascii_code)
            "A": case(char_y) 4'd2,4'd3: font_row=8'h38; 4'd4,4'd5: font_row=8'h6C; 4'd6,4'd7: font_row=8'hFE; default: font_row=8'hC6; endcase
            "C": case(char_y) 4'd2,4'd3: font_row=8'h3C; 4'd12,4'd13: font_row=8'h3C; default: font_row=8'hC0; endcase
            "D": case(char_y) 4'd2,4'd13: font_row=8'hFC; default: font_row=8'h66; endcase
            "E": case(char_y) 4'd2,4'd7,4'd13: font_row=8'hFE; default: font_row=8'hC0; endcase
            "F": case(char_y) 4'd2,4'd7: font_row=8'hFE; default: font_row=8'hC0; endcase
            "G": case(char_y) 4'd2,4'd13: font_row=8'h7C; 4'd8: font_row=8'hCE; default: font_row=8'hC6; endcase
            "H": case(char_y) 4'd7,4'd8: font_row=8'hFE; default: font_row=8'hC6; endcase
            "I": case(char_y) 4'd2,4'd13: font_row=8'h7C; default: font_row=8'h18; endcase
            "L": case(char_y) 4'd12,4'd13: font_row=8'hFE; default: font_row=8'hC0; endcase
            "M": case(char_y) 4'd2: font_row=8'hC6; 4'd4: font_row=8'hEE; 4'd6: font_row=8'hFE; default: font_row=8'hD6; endcase
            "N": case(char_y) 4'd4: font_row=8'hE6; 4'd8: font_row=8'hCE; default: font_row=8'hC6; endcase
            "O": case(char_y) 4'd2,4'd13: font_row=8'h38; default: font_row=8'hC6; endcase
            "P": case(char_y) 4'd2,4'd7: font_row=8'hFC; 4'd3,4'd4,4'd5,4'd6: font_row=8'hC6; default: font_row=8'hC0; endcase
            "R": case(char_y) 4'd2,4'd7: font_row=8'hFC; 4'd3,4'd4,4'd5,4'd6: font_row=8'hC6; default: font_row=8'hC6; endcase
            "S": case(char_y) 4'd2,4'd7,4'd13: font_row=8'h7C; 4'd3,4'd4,4'd5,4'd6: font_row=8'hC0; default: font_row=8'h06; endcase
            "T": case(char_y) 4'd2,4'd3: font_row=8'hFE; default: font_row=8'h18; endcase
            "W": case(char_y) 4'd12: font_row=8'h7C; 4'd10: font_row=8'hEE; default: font_row=8'hC6; endcase
            ":": case(char_y) 4'd5,4'd6,4'd10,4'd11: font_row=8'h18; default: font_row=8'h00; endcase
            default: font_row = 8'h00;
        endcase
    end

    wire char_bit = font_row[3'd7 - char_x];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_vs  <= 1'b0;
            out_hs  <= 1'b0;
            out_de  <= 1'b0;
            out_rgb <= 24'd0;
        end else begin
            out_vs <= in_vs;
            out_hs <= in_hs;
            out_de <= in_de;

            if (in_text_box && char_bit) begin
                case (gesture_id)
                    3'd1: out_rgb <= 24'h00_FF_00; // FORWARD 绿
                    3'd2: out_rgb <= 24'hFF_00_00; // STOP 红
                    3'd3: out_rgb <= 24'hFF_FF_00; // LEFT 黄
                    3'd4: out_rgb <= 24'h00_FF_FF; // RIGHT 青
                    default: out_rgb <= 24'hAA_AA_AA; // NONE 灰
                endcase
            end
            else if (in_osd_bg) begin
                out_rgb <= 24'h10_10_10; 
            end
            else if (is_box) begin
                out_rgb <= 24'h00_FF_00; 
            end
            else begin
                out_rgb <= in_rgb;
            end
        end
    end

endmodule