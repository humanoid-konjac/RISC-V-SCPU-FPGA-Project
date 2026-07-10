`timescale 1ns / 1ps
`default_nettype none

module vga_game_text(
    input wire [9:0] pixel_x,
    input wire [9:0] pixel_y,
    input wire [31:0] active_ui,
    input wire [31:0] active_meta,
    input wire [31:0] active_seed_lo,
    input wire [31:0] active_seed_hi,
    output reg text_on,
    output reg [11:0] text_rgb
);
    wire playing = active_ui[9];
    wire finished = active_ui[8];
    wire history_full = active_ui[10];
    wire input_error = active_ui[11];
    wire [1:0] difficulty = active_meta[1:0];

    reg [3:0] line_id;
    reg [9:0] line_x;
    reg [9:0] line_y;
    reg [6:0] char_index;
    reg [2:0] glyph_row;
    reg [2:0] glyph_col;
    reg [7:0] character;
    reg line_valid;
    reg [34:0] glyph;

    function [7:0] seed_character;
        input [3:0] index;
        reg [3:0] digit;
        begin
            case (index)
                0: digit = active_seed_hi[7:4];
                1: digit = active_seed_hi[3:0];
                2: digit = active_seed_lo[31:28];
                3: digit = active_seed_lo[27:24];
                4: digit = active_seed_lo[23:20];
                5: digit = active_seed_lo[19:16];
                6: digit = active_seed_lo[15:12];
                7: digit = active_seed_lo[11:8];
                8: digit = active_seed_lo[7:4];
                default: digit = active_seed_lo[3:0];
            endcase
            seed_character = 8'h30 + digit;
        end
    endfunction

    function [7:0] difficulty_character;
        input [2:0] index;
        begin
            difficulty_character = " ";
            if (difficulty == 0) begin
                case (index) 0:difficulty_character="E";1:difficulty_character="A";
                    2:difficulty_character="S";3:difficulty_character="Y"; default:; endcase
            end else if (difficulty == 2) begin
                case (index) 0:difficulty_character="H";1:difficulty_character="A";
                    2:difficulty_character="R";3:difficulty_character="D"; default:; endcase
            end else begin
                case (index) 0:difficulty_character="N";1:difficulty_character="O";
                    2:difficulty_character="R";3:difficulty_character="M";
                    4:difficulty_character="A";5:difficulty_character="L"; default:; endcase
            end
        end
    endfunction

    function [7:0] fixed_character;
        input [3:0] line;
        input [6:0] index;
        begin
            fixed_character = " ";
            case (line)
                0: case(index) 0:fixed_character="W";1:fixed_character="A";2:fixed_character="T";3:fixed_character="E";4:fixed_character="R";6:fixed_character="S";7:fixed_character="O";8:fixed_character="R";9:fixed_character="T";default:;endcase
                1: case(index) 0:fixed_character="M";1:fixed_character="O";2:fixed_character="D";3:fixed_character="E";5:fixed_character="<";14:fixed_character=">";default:;endcase
                2: case(index) 0:fixed_character="S";1:fixed_character="E";2:fixed_character="E";3:fixed_character="D";default:;endcase
                3: case(index) 0:fixed_character="A";1:fixed_character="/";2:fixed_character="D";4:fixed_character="M";5:fixed_character="O";6:fixed_character="D";7:fixed_character="E";10:fixed_character="0";11:fixed_character="-";12:fixed_character="9";14:fixed_character="S";15:fixed_character="E";16:fixed_character="E";17:fixed_character="D";default:;endcase
                4: case(index) 0:fixed_character="R";2:fixed_character="R";3:fixed_character="A";4:fixed_character="N";5:fixed_character="D";6:fixed_character="O";7:fixed_character="M";10:fixed_character="E";11:fixed_character="N";12:fixed_character="T";13:fixed_character="E";14:fixed_character="R";16:fixed_character="S";17:fixed_character="T";18:fixed_character="A";19:fixed_character="R";20:fixed_character="T";default:;endcase
                5: case(index) 0:fixed_character="S";1:fixed_character="E";2:fixed_character="E";3:fixed_character="D";5:fixed_character="T";6:fixed_character="O";7:fixed_character="O";9:fixed_character="L";10:fixed_character="A";11:fixed_character="R";12:fixed_character="G";13:fixed_character="E";default:;endcase
                7: case(index) 0:fixed_character="A";1:fixed_character="/";2:fixed_character="D";4:fixed_character="M";5:fixed_character="O";6:fixed_character="V";7:fixed_character="E";10:fixed_character="E";11:fixed_character="N";12:fixed_character="T";13:fixed_character="E";14:fixed_character="R";16:fixed_character="P";17:fixed_character="O";18:fixed_character="U";19:fixed_character="R";22:fixed_character="U";24:fixed_character="U";25:fixed_character="N";26:fixed_character="D";27:fixed_character="O";default:;endcase
                8: case(index) 0:fixed_character="E";1:fixed_character="S";2:fixed_character="C";4:fixed_character="C";5:fixed_character="A";6:fixed_character="N";7:fixed_character="C";8:fixed_character="E";9:fixed_character="L";12:fixed_character="R";14:fixed_character="R";15:fixed_character="E";16:fixed_character="S";17:fixed_character="T";18:fixed_character="A";19:fixed_character="R";20:fixed_character="T";23:fixed_character="M";25:fixed_character="M";26:fixed_character="E";27:fixed_character="N";28:fixed_character="U";default:;endcase
                9: case(index) 0:fixed_character="Y";1:fixed_character="O";2:fixed_character="U";4:fixed_character="W";5:fixed_character="I";6:fixed_character="N";default:;endcase
                10:case(index) 0:fixed_character="H";1:fixed_character="I";2:fixed_character="S";3:fixed_character="T";4:fixed_character="O";5:fixed_character="R";6:fixed_character="Y";8:fixed_character="F";9:fixed_character="U";10:fixed_character="L";11:fixed_character="L";default:;endcase
                default:;
            endcase
        end
    endfunction

    function [34:0] glyph_for;
        input [7:0] c;
        begin
            case (c)
                "A":glyph_for={5'b01110,5'b10001,5'b10001,5'b11111,5'b10001,5'b10001,5'b10001};
                "C":glyph_for={5'b01111,5'b10000,5'b10000,5'b10000,5'b10000,5'b10000,5'b01111};
                "D":glyph_for={5'b11110,5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b11110};
                "E":glyph_for={5'b11111,5'b10000,5'b10000,5'b11110,5'b10000,5'b10000,5'b11111};
                "F":glyph_for={5'b11111,5'b10000,5'b10000,5'b11110,5'b10000,5'b10000,5'b10000};
                "G":glyph_for={5'b01111,5'b10000,5'b10000,5'b10111,5'b10001,5'b10001,5'b01111};
                "H":glyph_for={5'b10001,5'b10001,5'b10001,5'b11111,5'b10001,5'b10001,5'b10001};
                "I":glyph_for={5'b11111,5'b00100,5'b00100,5'b00100,5'b00100,5'b00100,5'b11111};
                "L":glyph_for={5'b10000,5'b10000,5'b10000,5'b10000,5'b10000,5'b10000,5'b11111};
                "M":glyph_for={5'b10001,5'b11011,5'b10101,5'b10101,5'b10001,5'b10001,5'b10001};
                "N":glyph_for={5'b10001,5'b11001,5'b10101,5'b10011,5'b10001,5'b10001,5'b10001};
                "O":glyph_for={5'b01110,5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b01110};
                "P":glyph_for={5'b11110,5'b10001,5'b10001,5'b11110,5'b10000,5'b10000,5'b10000};
                "R":glyph_for={5'b11110,5'b10001,5'b10001,5'b11110,5'b10100,5'b10010,5'b10001};
                "S":glyph_for={5'b01111,5'b10000,5'b10000,5'b01110,5'b00001,5'b00001,5'b11110};
                "T":glyph_for={5'b11111,5'b00100,5'b00100,5'b00100,5'b00100,5'b00100,5'b00100};
                "U":glyph_for={5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b01110};
                "V":glyph_for={5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b01010,5'b00100};
                "W":glyph_for={5'b10001,5'b10001,5'b10001,5'b10101,5'b10101,5'b11011,5'b10001};
                "Y":glyph_for={5'b10001,5'b10001,5'b01010,5'b00100,5'b00100,5'b00100,5'b00100};
                "0":glyph_for={5'b01110,5'b10001,5'b10011,5'b10101,5'b11001,5'b10001,5'b01110};
                "1":glyph_for={5'b00100,5'b01100,5'b00100,5'b00100,5'b00100,5'b00100,5'b01110};
                "2":glyph_for={5'b01110,5'b10001,5'b00001,5'b00010,5'b00100,5'b01000,5'b11111};
                "3":glyph_for={5'b11110,5'b00001,5'b00001,5'b01110,5'b00001,5'b00001,5'b11110};
                "4":glyph_for={5'b00010,5'b00110,5'b01010,5'b10010,5'b11111,5'b00010,5'b00010};
                "5":glyph_for={5'b11111,5'b10000,5'b10000,5'b11110,5'b00001,5'b00001,5'b11110};
                "6":glyph_for={5'b01110,5'b10000,5'b10000,5'b11110,5'b10001,5'b10001,5'b01110};
                "7":glyph_for={5'b11111,5'b00001,5'b00010,5'b00100,5'b01000,5'b01000,5'b01000};
                "8":glyph_for={5'b01110,5'b10001,5'b10001,5'b01110,5'b10001,5'b10001,5'b01110};
                "9":glyph_for={5'b01110,5'b10001,5'b10001,5'b01111,5'b00001,5'b00001,5'b01110};
                "/":glyph_for={5'b00001,5'b00010,5'b00010,5'b00100,5'b01000,5'b01000,5'b10000};
                "-":glyph_for={5'b00000,5'b00000,5'b00000,5'b11111,5'b00000,5'b00000,5'b00000};
                "<":glyph_for={5'b00010,5'b00100,5'b01000,5'b10000,5'b01000,5'b00100,5'b00010};
                ">":glyph_for={5'b01000,5'b00100,5'b00010,5'b00001,5'b00010,5'b00100,5'b01000};
                default:glyph_for=35'b0;
            endcase
        end
    endfunction

    always @(*) begin
        line_valid = 1'b1; line_id = 0; line_x = 0; line_y = 0;
        if (!playing) begin
            if (pixel_y >= 90 && pixel_y < 104) begin line_id=0;line_x=260;line_y=90;end
            else if (pixel_y >= 170 && pixel_y < 184) begin line_id=1;line_x=226;line_y=170;end
            else if (pixel_y >= 220 && pixel_y < 234) begin line_id=2;line_x=220;line_y=220;end
            else if (pixel_y >= 300 && pixel_y < 314) begin line_id=3;line_x=206;line_y=300;end
            else if (pixel_y >= 335 && pixel_y < 349) begin line_id=4;line_x=190;line_y=335;end
            else if (input_error && pixel_y >= 385 && pixel_y < 399) begin line_id=5;line_x=236;line_y=385;end
            else line_valid=1'b0;
        end else begin
            if (pixel_y >= 24 && pixel_y < 38) begin line_id=6;line_x=20;line_y=24;end
            else if (pixel_y >= 402 && pixel_y < 416) begin line_id=7;line_x=148;line_y=402;end
            else if (pixel_y >= 434 && pixel_y < 448) begin line_id=8;line_x=142;line_y=434;end
            else if (finished && pixel_y >= 70 && pixel_y < 84) begin line_id=9;line_x=278;line_y=70;end
            else if (history_full && pixel_y >= 70 && pixel_y < 84) begin line_id=10;line_x=248;line_y=70;end
            else line_valid=1'b0;
        end

        char_index = 0; glyph_row = 0; glyph_col = 0; character = " ";
        if (line_valid && pixel_x >= line_x) begin
            char_index = (pixel_x - line_x) / 12;
            glyph_col = ((pixel_x - line_x) - char_index * 12) >> 1;
            glyph_row = (pixel_y - line_y) >> 1;
            if (line_id == 1 && char_index >= 7 && char_index < 13)
                character = difficulty_character(char_index - 7);
            else if (line_id == 2 && char_index >= 5 && char_index < 15)
                character = seed_character(char_index - 5);
            else if (line_id == 6) begin
                if (char_index < 6) character = difficulty_character(char_index);
                else if (char_index >= 8 && char_index < 12)
                    case(char_index) 8:character="S";9:character="E";10:character="E";default:character="D";endcase
                else if (char_index >= 13 && char_index < 23)
                    character = seed_character(char_index - 13);
                else if (char_index >= 25 && char_index < 30)
                    case(char_index) 25:character="M";26:character="O";27:character="V";28:character="E";default:character="S";endcase
                else if (char_index >= 31 && char_index < 35)
                    case(char_index) 31:character=8'h30+active_meta[31:28];32:character=8'h30+active_meta[27:24];33:character=8'h30+active_meta[23:20];default:character=8'h30+active_meta[19:16];endcase
            end else character = fixed_character(line_id, char_index);
        end
        glyph = glyph_for(character);
        text_on = line_valid && glyph_row < 7 && glyph_col < 5 &&
                  glyph[(6-glyph_row)*5 + (4-glyph_col)];
        text_rgb = input_error && line_id == 5 ? 12'hf44 :
                   (finished && line_id == 9 ? 12'h4f4 : 12'hfff);
    end
endmodule

`default_nettype wire
