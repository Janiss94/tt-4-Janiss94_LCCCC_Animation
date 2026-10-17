// src/project.v
// LCCC / Chipathon / organisers / powered by / supported by slideshow.
// All declared data vectors are <= 8 bits.
// Standalone: VGA timing is integrated; no hvsync_generator is instantiated.
// Pixel clock: 25 MHz. Raster: 800 clocks per line, 525 lines per frame.
// The output bus carries 2-bit R, G, B plus horizontal and vertical sync.
`default_nettype none

module tt_um_janiss94_LCCC_Animation #(
    // Valid range: 1..255. Each unit is TWO complete visible frames.
    // 150 pairs = 300 frames = 5.04 seconds at 25 MHz and 800x525 timing.
    parameter [7:0] SLIDE_FRAME_PAIRS = 8'd150
) (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    // A group holds four physical pixels or four physical lines.
    // Keep the group and phase separate throughout; no wide coordinate bus.
    reg [7:0] x_group;
    reg [1:0] x_phase;
    reg [7:0] y_group;
    reg [1:0] y_phase;

    always @(posedge clk) begin
        if (!rst_n) begin
            x_group <= 8'd0;
            x_phase <= 2'd0;
            y_group <= 8'd0;
            y_phase <= 2'd0;
        end else if (x_phase == 2'd3) begin
            x_phase <= 2'd0;
            if (x_group == 8'd199) begin
                x_group <= 8'd0;
                // Physical line 524 is group 131, phase 0.
                // Wrap here because the 525-line raster is not divisible by 4.
                if ((y_group == 8'd131) && (y_phase == 2'd0)) begin
                    y_group <= 8'd0;
                    y_phase <= 2'd0;
                end else if (y_phase == 2'd3) begin
                    y_group <= y_group + 8'd1;
                    y_phase <= 2'd0;
                end else begin
                    y_phase <= y_phase + 2'd1;
                end
            end else begin
                x_group <= x_group + 8'd1;
            end
        end else begin
            x_phase <= x_phase + 2'd1;
        end
    end

    wire hsync, vsync, display_on;
    // Horizontal sync: physical pixels [656,752).
    assign hsync = !((x_group >= 8'd164) && (x_group < 8'd188));
    // Vertical sync: physical lines [490,492).
    assign vsync = !((y_group == 8'd122) && (y_phase >= 2'd2));
    assign display_on = (x_group < 8'd160) && (y_group < 8'd120);

    // One pulse at physical x=0,y=480, in vertical blanking.
    wire frame_tick;
    assign frame_tick =
        (x_group == 8'd0) && (x_phase == 2'd0) &&
        (y_group == 8'd120) && (y_phase == 2'd0);

    reg [7:0] slide_pair_count;
    reg       frame_half;
    reg [2:0] slide_select; // 0 = LCCC, 1 = Chipathon, 2 = organisers, 3 = sponsors, 4 = supporters
    reg [7:0] frame_count;

    always @(posedge clk) begin
        if (!rst_n) begin
            slide_pair_count <= 8'd0;
            frame_half       <= 1'b0;
            slide_select     <= 3'd0;
            frame_count      <= 8'd0;
        end else if (frame_tick) begin
            frame_count <= frame_count + 8'd1;
            if (frame_half) begin
                frame_half <= 1'b0;
                if (slide_pair_count == (SLIDE_FRAME_PAIRS - 8'd1)) begin
                    slide_pair_count <= 8'd0;
                    if (slide_select == 3'd4) begin
                        slide_select <= 3'd0;
                    end else begin
                        slide_select <= slide_select + 3'd1;
                    end
                end else begin
                    slide_pair_count <= slide_pair_count + 8'd1;
                end
            end else begin
                frame_half <= 1'b1;
            end
        end
    end

    // ---------------- Slide 0: LCCC ----------------
    wire [2:0] glow_phase;
    wire glow_low, glow_mid;
    assign glow_phase = frame_count[7:5];
    assign glow_low = (glow_phase == 3'd0) || (glow_phase == 3'd7);
    assign glow_mid = (glow_phase == 3'd1) || (glow_phase == 3'd6);

    wire logo_pixel;
    assign logo_pixel =
        // Left stem.
        ((x_group >= 8'd40) && (x_group < 8'd65) &&
         (y_group >= 8'd20)  && (y_group < 8'd100)) ||
        // Left foot.
        ((x_group >= 8'd40) && (x_group < 8'd75) &&
         (y_group >= 8'd75) && (y_group < 8'd100)) ||
        // Upper right block.
        ((x_group >= 8'd70) && (x_group < 8'd105) &&
         (y_group >= 8'd20)  && (y_group < 8'd45)) ||
        // Right stem.
        ((x_group >= 8'd95) && (x_group < 8'd120) &&
         (y_group >= 8'd35) && (y_group < 8'd100)) ||
        // Middle tooth.
        ((x_group >= 8'd75) && (x_group < 8'd95) &&
         (y_group >= 8'd55) && (y_group < 8'd65)) ||
        // Lower right block. Vertical gap x=300..319 remains open.
        ((x_group >= 8'd80) && (x_group < 8'd120) &&
         (y_group >= 8'd75) && (y_group < 8'd100));

    wire accent_pixel;
    assign accent_pixel =
        (x_group >= 8'd115) && (x_group < 8'd130) &&
        (y_group >= 8'd10)  && (y_group < 8'd25);

    // ---------------- Slide 1: Chipathon ----------------
    wire panel_pixel, shadow_pixel, circuit_pixel;
    assign panel_pixel =
        (x_group >= 8'd6) && (x_group < 8'd154) &&
        (y_group >= 8'd30) && (y_group < 8'd80);
    assign shadow_pixel =
        (x_group >= 8'd8) && (x_group < 8'd156) &&
        (y_group >= 8'd32) && (y_group < 8'd82);
    // Phase bit 1 distinguishes the lower and upper two pixels of a group.
    // Retain the original two-pixel traces and ten-pixel terminal squares.
    wire y_before_98, y_98_to_108;
    assign y_before_98 =
        (y_group < 8'd24) || ((y_group == 8'd24) && !y_phase[1]);
    assign y_98_to_108 =
        ((y_group > 8'd24) || ((y_group == 8'd24) && y_phase[1])) &&
        (y_group < 8'd27);

    assign circuit_pixel =
        // Left trace, x=[0,162), y=[48,50).
        (((x_group < 8'd40) || ((x_group == 8'd40) && !x_phase[1])) &&
         (y_group == 8'd12) && !y_phase[1]) ||
        // Left vertical branch, x=[80,82), y=[48,98).
        ((x_group == 8'd20) && !x_phase[1] &&
         (y_group >= 8'd12) && y_before_98) ||
        // Left terminal, x=[76,86), y=[98,108).
        ((x_group >= 8'd19) &&
         ((x_group < 8'd21) || ((x_group == 8'd21) && !x_phase[1])) &&
         y_98_to_108) ||
        // Right trace, x >= 478, y=[72,74).
        (((x_group > 8'd119) || ((x_group == 8'd119) && x_phase[1])) &&
         (y_group == 8'd18) && !y_phase[1]) ||
        // Right vertical branch, x=[558,560), y=[72,98).
        ((x_group == 8'd139) && x_phase[1] &&
         (y_group >= 8'd18) && y_before_98) ||
        // Right terminal, x=[554,564), y=[98,108).
        (((x_group > 8'd138) || ((x_group == 8'd138) && x_phase[1])) &&
         (x_group < 8'd141) && y_98_to_108);

    // Chip body, two pins on each side, and a concentric square die.
    wire chip_body, chip_pins, chip_hole, chip_die, chip_core, chip_pixel;
    assign chip_body =
        (x_group >= 8'd16) && (x_group < 8'd32) &&
        (y_group >= 8'd40) && (y_group < 8'd56);
    assign chip_pins =
        ((((x_group >= 8'd20) && (x_group < 8'd22)) ||
         ((x_group >= 8'd26) && (x_group < 8'd28))) &&
         (y_group >= 8'd37) && (y_group < 8'd59)) ||
        ((((y_group >= 8'd44) && (y_group < 8'd46)) ||
         ((y_group >= 8'd50) && (y_group < 8'd52))) &&
         (x_group >= 8'd13) && (x_group < 8'd35));
    assign chip_hole =
        (x_group >= 8'd19) && (x_group < 8'd29) &&
        (y_group >= 8'd43) && (y_group < 8'd53);
    assign chip_die =
        (x_group >= 8'd21) && (x_group < 8'd27) &&
        (y_group >= 8'd45) && (y_group < 8'd51);
    assign chip_core =
        (x_group >= 8'd23) && (x_group < 8'd25) &&
        (y_group >= 8'd47) && (y_group < 8'd49);
    assign chip_pixel =
        ((chip_body || chip_pins) && !chip_hole) ||
        (chip_die && !chip_core);

    // Fixed lowercase "chipathon" wordmark: 54 columns x 9 rows.
    // The original bitmap is read one byte at a time; each bit is 8x8 pixels.
    // Two unused zero bits pad the last byte of each row.
    function [7:0] title_byte;
        input [3:0] row_number;
        input [2:0] byte_number;
        begin
            title_byte = 8'd0;
            case (row_number)
                4'd0: begin
                    case (byte_number)
                        3'd0: title_byte = 8'b00000010;
                        3'd1: title_byte = 8'b00000010;
                        3'd3: title_byte = 8'b00000001;
                        3'd4: title_byte = 8'b00001000;
                        default: title_byte = 8'd0;
                    endcase
                end
                4'd1: begin
                    case (byte_number)
                        3'd0: title_byte = 8'b00000010;
                        3'd3: title_byte = 8'b00000001;
                        3'd4: title_byte = 8'b00001000;
                        default: title_byte = 8'd0;
                    endcase
                end
                4'd2: begin
                    case (byte_number)
                        3'd0: title_byte = 8'b01110011;
                        3'd1: title_byte = 8'b11000110;
                        3'd2: title_byte = 8'b00111100;
                        3'd3: title_byte = 8'b01110011;
                        3'd4: title_byte = 8'b11001111;
                        3'd5: title_byte = 8'b00011100;
                        3'd6: title_byte = 8'b11110000;
                        default: title_byte = 8'd0;
                    endcase
                end
                4'd3: begin
                    case (byte_number)
                        3'd0: title_byte = 8'b10001010;
                        3'd1: title_byte = 8'b00100010;
                        3'd2: title_byte = 8'b00100010;
                        3'd3: title_byte = 8'b00001001;
                        3'd4: title_byte = 8'b00001000;
                        3'd5: title_byte = 8'b10100010;
                        3'd6: title_byte = 8'b10001000;
                        default: title_byte = 8'd0;
                    endcase
                end
                4'd4: begin
                    case (byte_number)
                        3'd0: title_byte = 8'b10000010;
                        3'd1: title_byte = 8'b00100010;
                        3'd2: title_byte = 8'b00100010;
                        3'd3: title_byte = 8'b01111001;
                        3'd4: title_byte = 8'b00001000;
                        3'd5: title_byte = 8'b10100010;
                        3'd6: title_byte = 8'b10001000;
                        default: title_byte = 8'd0;
                    endcase
                end
                4'd5: begin
                    case (byte_number)
                        3'd0: title_byte = 8'b10001010;
                        3'd1: title_byte = 8'b00100010;
                        3'd2: title_byte = 8'b00111100;
                        3'd3: title_byte = 8'b10001001;
                        3'd4: title_byte = 8'b00101000;
                        3'd5: title_byte = 8'b10100010;
                        3'd6: title_byte = 8'b10001000;
                        default: title_byte = 8'd0;
                    endcase
                end
                4'd6: begin
                    case (byte_number)
                        3'd0: title_byte = 8'b01110010;
                        3'd1: title_byte = 8'b00100111;
                        3'd2: title_byte = 8'b00100000;
                        3'd3: title_byte = 8'b01111000;
                        3'd4: title_byte = 8'b11001000;
                        3'd5: title_byte = 8'b10011100;
                        3'd6: title_byte = 8'b10001000;
                        default: title_byte = 8'd0;
                    endcase
                end
                4'd7: begin
                    case (byte_number)
                        3'd2: title_byte = 8'b00100000;
                        default: title_byte = 8'd0;
                    endcase
                end
                4'd8: begin
                    case (byte_number)
                        3'd2: title_byte = 8'b00100000;
                        default: title_byte = 8'd0;
                    endcase
                end
                default: title_byte = 8'd0;
            endcase
        end
    endfunction

    wire [7:0] title_x_coarse, title_y_coarse;
    wire [5:0] title_column;
    wire [7:0] title_bits;
    assign title_x_coarse = x_group - 8'd44;
    assign title_y_coarse = y_group - 8'd38;
    assign title_column = title_x_coarse[6:1];
    assign title_bits = title_byte(title_y_coarse[4:1], title_column[5:3]);
    wire title_pixel;
    assign title_pixel =
        (x_group >= 8'd44) && (x_group < 8'd152) &&
        (y_group >= 8'd38) && (y_group < 8'd56) &&
        title_bits[3'd7 - title_column[2:0]];

    // Return one ASCII character at a time, without packed string vectors.
    function [7:0] message_char;
        input [1:0] line_number;
        input [4:0] index;
        begin
            message_char = 8'h20;
            case (line_number)
                2'd0: begin // CHIP DESIGN SPRINT
                    case (index)
                        5'd0: message_char = 8'h43; // C
                        5'd1: message_char = 8'h48; // H
                        5'd2: message_char = 8'h49; // I
                        5'd3: message_char = 8'h50; // P
                        5'd5: message_char = 8'h44; // D
                        5'd6: message_char = 8'h45; // E
                        5'd7: message_char = 8'h53; // S
                        5'd8: message_char = 8'h49; // I
                        5'd9: message_char = 8'h47; // G
                        5'd10: message_char = 8'h4e; // N
                        5'd12: message_char = 8'h53; // S
                        5'd13: message_char = 8'h50; // P
                        5'd14: message_char = 8'h52; // R
                        5'd15: message_char = 8'h49; // I
                        5'd16: message_char = 8'h4e; // N
                        5'd17: message_char = 8'h54; // T
                        default: message_char = 8'h20;
                    endcase
                end
                2'd1: begin // 16-18 OCTOBER
                    case (index)
                        5'd0: message_char = 8'h31; // 1
                        5'd1: message_char = 8'h36; // 6
                        5'd2: message_char = 8'h2d; // -
                        5'd3: message_char = 8'h31; // 1
                        5'd4: message_char = 8'h38; // 8
                        5'd6: message_char = 8'h4f; // O
                        5'd7: message_char = 8'h43; // C
                        5'd8: message_char = 8'h54; // T
                        5'd9: message_char = 8'h4f; // O
                        5'd10: message_char = 8'h42; // B
                        5'd11: message_char = 8'h45; // E
                        5'd12: message_char = 8'h52; // R
                        default: message_char = 8'h20;
                    endcase
                end
                2'd2: begin // RIGA TECHNICAL UNIVERSITY
                    case (index)
                        5'd0: message_char = 8'h52; // R
                        5'd1: message_char = 8'h49; // I
                        5'd2: message_char = 8'h47; // G
                        5'd3: message_char = 8'h41; // A
                        5'd5: message_char = 8'h54; // T
                        5'd6: message_char = 8'h45; // E
                        5'd7: message_char = 8'h43; // C
                        5'd8: message_char = 8'h48; // H
                        5'd9: message_char = 8'h4e; // N
                        5'd10: message_char = 8'h49; // I
                        5'd11: message_char = 8'h43; // C
                        5'd12: message_char = 8'h41; // A
                        5'd13: message_char = 8'h4c; // L
                        5'd15: message_char = 8'h55; // U
                        5'd16: message_char = 8'h4e; // N
                        5'd17: message_char = 8'h49; // I
                        5'd18: message_char = 8'h56; // V
                        5'd19: message_char = 8'h45; // E
                        5'd20: message_char = 8'h52; // R
                        5'd21: message_char = 8'h53; // S
                        5'd22: message_char = 8'h49; // I
                        5'd23: message_char = 8'h54; // T
                        5'd24: message_char = 8'h59; // Y
                        default: message_char = 8'h20;
                    endcase
                end
                default: message_char = 8'h20;
            endcase
        end
    endfunction

    // A 5x7 font, selected by character and row. Every lookup result is 5 bits.
    function [4:0] font_row;
        input [7:0] character;
        input [2:0] row_number;
        begin
            font_row = 5'd0;
            case (character)
                8'd49: begin // 1
                    case (row_number)
                        3'd0: font_row = 5'b00100;
                        3'd1: font_row = 5'b01100;
                        3'd2: font_row = 5'b00100;
                        3'd3: font_row = 5'b00100;
                        3'd4: font_row = 5'b00100;
                        3'd5: font_row = 5'b00100;
                        3'd6: font_row = 5'b01110;
                        default: font_row = 5'd0;
                    endcase
                end
                8'd54: begin // 6
                    case (row_number)
                        3'd0: font_row = 5'b00110;
                        3'd1: font_row = 5'b01000;
                        3'd2: font_row = 5'b10000;
                        3'd3: font_row = 5'b11110;
                        3'd4: font_row = 5'b10001;
                        3'd5: font_row = 5'b10001;
                        3'd6: font_row = 5'b01110;
                        default: font_row = 5'd0;
                    endcase
                end
                8'd56: begin // 8
                    case (row_number)
                        3'd0: font_row = 5'b01110;
                        3'd1: font_row = 5'b10001;
                        3'd2: font_row = 5'b10001;
                        3'd3: font_row = 5'b01110;
                        3'd4: font_row = 5'b10001;
                        3'd5: font_row = 5'b10001;
                        3'd6: font_row = 5'b01110;
                        default: font_row = 5'd0;
                    endcase
                end
                8'd32: font_row = 5'd0; // space
                8'd45: begin // -
                    case (row_number)
                        3'd3: font_row = 5'b11111;
                        default: font_row = 5'd0;
                    endcase
                end
                8'd65: begin // A
                    case (row_number)
                        3'd0: font_row = 5'b01110;
                        3'd1: font_row = 5'b10001;
                        3'd2: font_row = 5'b10001;
                        3'd3: font_row = 5'b11111;
                        3'd4: font_row = 5'b10001;
                        3'd5: font_row = 5'b10001;
                        3'd6: font_row = 5'b10001;
                        default: font_row = 5'd0;
                    endcase
                end
                8'd66: begin // B
                    case (row_number)
                        3'd0: font_row = 5'b11110;
                        3'd1: font_row = 5'b10001;
                        3'd2: font_row = 5'b10001;
                        3'd3: font_row = 5'b11110;
                        3'd4: font_row = 5'b10001;
                        3'd5: font_row = 5'b10001;
                        3'd6: font_row = 5'b11110;
                        default: font_row = 5'd0;
                    endcase
                end
                8'd67: begin // C
                    case (row_number)
                        3'd0: font_row = 5'b01110;
                        3'd1: font_row = 5'b10001;
                        3'd2: font_row = 5'b10000;
                        3'd3: font_row = 5'b10000;
                        3'd4: font_row = 5'b10000;
                        3'd5: font_row = 5'b10001;
                        3'd6: font_row = 5'b01110;
                        default: font_row = 5'd0;
                    endcase
                end
                8'd68: begin // D
                    case (row_number)
                        3'd0: font_row = 5'b11110;
                        3'd1: font_row = 5'b10001;
                        3'd2: font_row = 5'b10001;
                        3'd3: font_row = 5'b10001;
                        3'd4: font_row = 5'b10001;
                        3'd5: font_row = 5'b10001;
                        3'd6: font_row = 5'b11110;
                        default: font_row = 5'd0;
                    endcase
                end
                8'd69: begin // E
                    case (row_number)
                        3'd0: font_row = 5'b11111;
                        3'd1: font_row = 5'b10000;
                        3'd2: font_row = 5'b10000;
                        3'd3: font_row = 5'b11110;
                        3'd4: font_row = 5'b10000;
                        3'd5: font_row = 5'b10000;
                        3'd6: font_row = 5'b11111;
                        default: font_row = 5'd0;
                    endcase
                end
                8'd71: begin // G
                    case (row_number)
                        3'd0: font_row = 5'b01110;
                        3'd1: font_row = 5'b10001;
                        3'd2: font_row = 5'b10000;
                        3'd3: font_row = 5'b10111;
                        3'd4: font_row = 5'b10001;
                        3'd5: font_row = 5'b10001;
                        3'd6: font_row = 5'b01110;
                        default: font_row = 5'd0;
                    endcase
                end
                8'd72: begin // H
                    case (row_number)
                        3'd0: font_row = 5'b10001;
                        3'd1: font_row = 5'b10001;
                        3'd2: font_row = 5'b10001;
                        3'd3: font_row = 5'b11111;
                        3'd4: font_row = 5'b10001;
                        3'd5: font_row = 5'b10001;
                        3'd6: font_row = 5'b10001;
                        default: font_row = 5'd0;
                    endcase
                end
                8'd73: begin // I
                    case (row_number)
                        3'd0: font_row = 5'b01110;
                        3'd1: font_row = 5'b00100;
                        3'd2: font_row = 5'b00100;
                        3'd3: font_row = 5'b00100;
                        3'd4: font_row = 5'b00100;
                        3'd5: font_row = 5'b00100;
                        3'd6: font_row = 5'b01110;
                        default: font_row = 5'd0;
                    endcase
                end
                8'd76: begin // L
                    case (row_number)
                        3'd0: font_row = 5'b10000;
                        3'd1: font_row = 5'b10000;
                        3'd2: font_row = 5'b10000;
                        3'd3: font_row = 5'b10000;
                        3'd4: font_row = 5'b10000;
                        3'd5: font_row = 5'b10000;
                        3'd6: font_row = 5'b11111;
                        default: font_row = 5'd0;
                    endcase
                end
                8'd78: begin // N
                    case (row_number)
                        3'd0: font_row = 5'b10001;
                        3'd1: font_row = 5'b11001;
                        3'd2: font_row = 5'b11001;
                        3'd3: font_row = 5'b10101;
                        3'd4: font_row = 5'b10011;
                        3'd5: font_row = 5'b10011;
                        3'd6: font_row = 5'b10001;
                        default: font_row = 5'd0;
                    endcase
                end
                8'd79: begin // O
                    case (row_number)
                        3'd0: font_row = 5'b01110;
                        3'd1: font_row = 5'b10001;
                        3'd2: font_row = 5'b10001;
                        3'd3: font_row = 5'b10001;
                        3'd4: font_row = 5'b10001;
                        3'd5: font_row = 5'b10001;
                        3'd6: font_row = 5'b01110;
                        default: font_row = 5'd0;
                    endcase
                end
                8'd80: begin // P
                    case (row_number)
                        3'd0: font_row = 5'b11110;
                        3'd1: font_row = 5'b10001;
                        3'd2: font_row = 5'b10001;
                        3'd3: font_row = 5'b11110;
                        3'd4: font_row = 5'b10000;
                        3'd5: font_row = 5'b10000;
                        3'd6: font_row = 5'b10000;
                        default: font_row = 5'd0;
                    endcase
                end
                8'd82: begin // R
                    case (row_number)
                        3'd0: font_row = 5'b11110;
                        3'd1: font_row = 5'b10001;
                        3'd2: font_row = 5'b10001;
                        3'd3: font_row = 5'b11110;
                        3'd4: font_row = 5'b10100;
                        3'd5: font_row = 5'b10010;
                        3'd6: font_row = 5'b10001;
                        default: font_row = 5'd0;
                    endcase
                end
                8'd83: begin // S
                    case (row_number)
                        3'd0: font_row = 5'b01111;
                        3'd1: font_row = 5'b10000;
                        3'd2: font_row = 5'b10000;
                        3'd3: font_row = 5'b01110;
                        3'd4: font_row = 5'b00001;
                        3'd5: font_row = 5'b00001;
                        3'd6: font_row = 5'b11110;
                        default: font_row = 5'd0;
                    endcase
                end
                8'd84: begin // T
                    case (row_number)
                        3'd0: font_row = 5'b11111;
                        3'd1: font_row = 5'b00100;
                        3'd2: font_row = 5'b00100;
                        3'd3: font_row = 5'b00100;
                        3'd4: font_row = 5'b00100;
                        3'd5: font_row = 5'b00100;
                        3'd6: font_row = 5'b00100;
                        default: font_row = 5'd0;
                    endcase
                end
                8'd85: begin // U
                    case (row_number)
                        3'd0: font_row = 5'b10001;
                        3'd1: font_row = 5'b10001;
                        3'd2: font_row = 5'b10001;
                        3'd3: font_row = 5'b10001;
                        3'd4: font_row = 5'b10001;
                        3'd5: font_row = 5'b10001;
                        3'd6: font_row = 5'b01110;
                        default: font_row = 5'd0;
                    endcase
                end
                8'd86: begin // V
                    case (row_number)
                        3'd0: font_row = 5'b10001;
                        3'd1: font_row = 5'b10001;
                        3'd2: font_row = 5'b10001;
                        3'd3: font_row = 5'b10001;
                        3'd4: font_row = 5'b10001;
                        3'd5: font_row = 5'b01010;
                        3'd6: font_row = 5'b00100;
                        default: font_row = 5'd0;
                    endcase
                end
                8'd89: begin // Y
                    case (row_number)
                        3'd0: font_row = 5'b10001;
                        3'd1: font_row = 5'b10001;
                        3'd2: font_row = 5'b01010;
                        3'd3: font_row = 5'b00100;
                        3'd4: font_row = 5'b00100;
                        3'd5: font_row = 5'b00100;
                        3'd6: font_row = 5'b00100;
                        default: font_row = 5'd0;
                    endcase
                end
                default: font_row = 5'd0;
            endcase
        end
    endfunction

    // Character cells are still 16x16 physical pixels, with 2x2 font bits.
    // Byte offsets hold groups of four pixels. Phase bit 1 retains the finer
    // two-pixel font positions, so the text has the original resolution.
    reg text_region;
    reg [1:0] text_line;
    reg [7:0] text_x_coarse, text_y_coarse;
    always @* begin
        text_region = 1'b0;
        text_line = 2'd0;
        text_x_coarse = 8'd0;
        text_y_coarse = 8'd0;
        if ((y_group >= 8'd66) && (y_group < 8'd70) &&
            (x_group >= 8'd44) && (x_group < 8'd116)) begin
            text_region = 1'b1;
            text_line = 2'd0;
            text_x_coarse = x_group - 8'd44;
            text_y_coarse = y_group - 8'd66;
        end else if ((y_group >= 8'd88) && (y_group < 8'd92) &&
                     (x_group >= 8'd54) && (x_group < 8'd106)) begin
            text_region = 1'b1;
            text_line = 2'd1;
            text_x_coarse = x_group - 8'd54;
            text_y_coarse = y_group - 8'd88;
        end else if ((y_group >= 8'd98) && (y_group < 8'd102) &&
                     (x_group >= 8'd30) && (x_group < 8'd130)) begin
            text_region = 1'b1;
            text_line = 2'd2;
            text_x_coarse = x_group - 8'd30;
            text_y_coarse = y_group - 8'd98;
        end
    end
    wire [7:0] text_character;
    wire [4:0] text_row;
    wire [2:0] text_column, text_row_number;
    wire text_pixel;
    assign text_column = {text_x_coarse[1:0], x_phase[1]};
    assign text_row_number = {text_y_coarse[1:0], y_phase[1]};
    assign text_character = message_char(text_line, text_x_coarse[6:2]);
    assign text_row = font_row(text_character, text_row_number);
    assign text_pixel = text_region && (text_column < 3'd5) &&
                        text_row[3'd4 - text_column];

    // ---------------- Slide 2: organisers ----------------
    wire [1:0] organisers_red, organisers_green, organisers_blue;
    lccc_organisers_renderer organisers_renderer (
        .x_group (x_group),
        .y_group (y_group),
        .x_phase (x_phase),
        .y_phase (y_phase),
        .red     (organisers_red),
        .green   (organisers_green),
        .blue    (organisers_blue)
    );

    // ---------------- Slide 3: powered by ----------------
    wire [1:0] sponsors_red, sponsors_green, sponsors_blue;
    lccc_sponsors_renderer sponsors_renderer (
        .x_group (x_group),
        .y_group (y_group),
        .x_phase (x_phase),
        .y_phase (y_phase),
        .red     (sponsors_red),
        .green   (sponsors_green),
        .blue    (sponsors_blue)
    );

    // ---------------- Slide 4: supported by ----------------
    wire [1:0] supporters_red, supporters_green, supporters_blue;
    lccc_supporters_renderer supporters_renderer (
        .x_group (x_group),
        .y_group (y_group),
        .x_phase (x_phase),
        .y_phase (y_phase),
        .red     (supporters_red),
        .green   (supporters_green),
        .blue    (supporters_blue)
    );

    // ---------------- RGB compositor ----------------
    reg [1:0] red, green, blue;
    always @* begin
        // Black in all blanking intervals.
        red = 2'd0;
        green = 2'd0;
        blue = 2'd0;
        if (display_on) begin
            if (slide_select == 3'd0) begin
                blue = 2'd1;
                if (logo_pixel) begin
                    if (glow_low) begin
                        red=2'd1; green=2'd1; blue=2'd2;
                    end else if (glow_mid) begin
                        red=2'd2; green=2'd2; blue=2'd3;
                    end else begin
                        red=2'd3; green=2'd3; blue=2'd3;
                    end
                end
                if (accent_pixel) begin
                    if (glow_low) begin
                        red=2'd1; green=2'd0; blue=2'd2;
                    end else if (glow_mid) begin
                        red=2'd2; green=2'd0; blue=2'd3;
                    end else begin
                        red=2'd3; green=2'd1; blue=2'd3;
                    end
                end
            end else if (slide_select == 3'd1) begin
                // Pale cyan background and a white title panel.
                red=2'd2; green=2'd3; blue=2'd3;
                if (circuit_pixel || shadow_pixel) begin
                    red=2'd1; green=2'd2; blue=2'd3;
                end
                if (panel_pixel) begin
                    red=2'd3; green=2'd3; blue=2'd3;
                end
                if (chip_pixel || text_pixel) begin
                    red=2'd0; green=2'd0; blue=2'd0;
                end
                if (title_pixel) begin
                    if (x_group < 8'd92) begin
                        red=2'd0; green=2'd2; blue=2'd3; // "chip"
                    end else begin
                        red=2'd0; green=2'd0; blue=2'd0; // "athon"
                    end
                end
            end else if (slide_select == 3'd2) begin
                red = organisers_red;
                green = organisers_green;
                blue = organisers_blue;
            end else if (slide_select == 3'd3) begin
                red = sponsors_red;
                green = sponsors_green;
                blue = sponsors_blue;
            end else if (slide_select == 3'd4) begin
                red = supporters_red;
                green = supporters_green;
                blue = supporters_blue;
            end
        end
    end

    // TinyVGA PMOD output pin order.
    assign uo_out = {hsync, blue[0], green[0], red[0],
                    vsync, blue[1], green[1], red[1]};
    assign uio_out = 8'h00;
    assign uio_oe = 8'h00;
    wire _unused;
    assign _unused = ena & (&ui_in) & (&uio_in) & 1'b0;
endmodule

`default_nettype none

// Procedural pixel art for the supplied five organiser marks.
// x_group/y_group count four-pixel groups; phases remain separate.
// Every declared vector, function result and sized literal is <= 8 bits.
// Generated by design/generate_organisers.py; no external image or font ROM.
module lccc_organisers_renderer (
    input wire [7:0] x_group,
    input wire [7:0] y_group,
    input wire [1:0] x_phase,
    input wire [1:0] y_phase,
    output reg [1:0] red,
    output reg [1:0] green,
    output reg [1:0] blue
);

    function [7:0] heading_mask;
        input [7:0] row;
        input [4:0] chunk;
        begin
            heading_mask = 8'h00;
            case (row)
                8'd0: begin
                    case (chunk)
                        5'd3: heading_mask = 8'h02;
                        default: heading_mask = 8'h00;
                    endcase
                end
                8'd1: begin
                    case (chunk)
                        5'd1: heading_mask = 8'h07;
                        5'd2: heading_mask = 8'h80;
                        default: heading_mask = 8'h00;
                    endcase
                end
                8'd2: begin
                    case (chunk)
                        5'd0: heading_mask = 8'h72;
                        5'd1: heading_mask = 8'hc8;
                        5'd2: heading_mask = 8'h9c;
                        5'd3: heading_mask = 8'hb2;
                        5'd4: heading_mask = 8'h79;
                        5'd5: heading_mask = 8'hcb;
                        5'd6: heading_mask = 8'h1e;
                        default: heading_mask = 8'h00;
                    endcase
                end
                8'd3: begin
                    case (chunk)
                        5'd0: heading_mask = 8'h8b;
                        5'd1: heading_mask = 8'h28;
                        5'd2: heading_mask = 8'h82;
                        5'd3: heading_mask = 8'hca;
                        5'd4: heading_mask = 8'h82;
                        5'd5: heading_mask = 8'h2c;
                        5'd6: heading_mask = 8'ha0;
                        default: heading_mask = 8'h00;
                    endcase
                end
                8'd4: begin
                    case (chunk)
                        5'd0: heading_mask = 8'h8a;
                        5'd1: heading_mask = 8'h07;
                        5'd2: heading_mask = 8'h9e;
                        5'd3: heading_mask = 8'h8a;
                        5'd4: heading_mask = 8'h73;
                        5'd5: heading_mask = 8'he8;
                        5'd6: heading_mask = 8'h1c;
                        default: heading_mask = 8'h00;
                    endcase
                end
                8'd5: begin
                    case (chunk)
                        5'd0: heading_mask = 8'h8a;
                        5'd2: heading_mask = 8'ha2;
                        5'd3: heading_mask = 8'h8a;
                        5'd4: heading_mask = 8'h0a;
                        5'd5: heading_mask = 8'h08;
                        5'd6: heading_mask = 8'h02;
                        default: heading_mask = 8'h00;
                    endcase
                end
                8'd6: begin
                    case (chunk)
                        5'd0: heading_mask = 8'h72;
                        5'd1: heading_mask = 8'h07;
                        5'd2: heading_mask = 8'h1e;
                        5'd3: heading_mask = 8'h8a;
                        5'd4: heading_mask = 8'hf1;
                        5'd5: heading_mask = 8'hc8;
                        5'd6: heading_mask = 8'h3c;
                        default: heading_mask = 8'h00;
                    endcase
                end
                default: heading_mask = 8'h00;
            endcase
        end
    endfunction

    function [7:0] rtu_mask;
        input [7:0] row;
        input [4:0] chunk;
        begin
            rtu_mask = 8'h00;
            case (row)
                8'd0: begin
                    case (chunk)
                        5'd5: rtu_mask = 8'h1f;
                        default: rtu_mask = 8'h00;
                    endcase
                end
                8'd1: begin
                    case (chunk)
                        5'd5: rtu_mask = 8'h1e;
                        default: rtu_mask = 8'h00;
                    endcase
                end
                8'd2: begin
                    case (chunk)
                        5'd0: rtu_mask = 8'hf7;
                        5'd1: rtu_mask = 8'h80;
                        5'd2: rtu_mask = 8'h7f;
                        5'd3: rtu_mask = 8'hff;
                        5'd4: rtu_mask = 8'h78;
                        5'd5: rtu_mask = 8'h1c;
                        default: rtu_mask = 8'h00;
                    endcase
                end
                8'd3: begin
                    case (chunk)
                        5'd0: rtu_mask = 8'hf3;
                        5'd1: rtu_mask = 8'hc0;
                        5'd2: rtu_mask = 8'h7f;
                        5'd3: rtu_mask = 8'hff;
                        5'd4: rtu_mask = 8'h78;
                        5'd5: rtu_mask = 8'h19;
                        default: rtu_mask = 8'h00;
                    endcase
                end
                8'd4: begin
                    case (chunk)
                        5'd0: rtu_mask = 8'hf1;
                        5'd1: rtu_mask = 8'he0;
                        5'd2: rtu_mask = 8'h7f;
                        5'd3: rtu_mask = 8'hff;
                        5'd4: rtu_mask = 8'h78;
                        5'd5: rtu_mask = 8'h13;
                        default: rtu_mask = 8'h00;
                    endcase
                end
                8'd5: begin
                    case (chunk)
                        5'd0: rtu_mask = 8'hf0;
                        5'd1: rtu_mask = 8'hf0;
                        5'd2: rtu_mask = 8'h7f;
                        5'd3: rtu_mask = 8'hff;
                        5'd4: rtu_mask = 8'h78;
                        5'd5: rtu_mask = 8'h07;
                        default: rtu_mask = 8'h00;
                    endcase
                end
                8'd6: begin
                    case (chunk)
                        5'd0: rtu_mask = 8'hf0;
                        5'd1: rtu_mask = 8'h78;
                        5'd2: rtu_mask = 8'h01;
                        5'd3: rtu_mask = 8'hf0;
                        5'd4: rtu_mask = 8'h78;
                        5'd5: rtu_mask = 8'h0f;
                        default: rtu_mask = 8'h00;
                    endcase
                end
                8'd7, 8'd9: begin
                    case (chunk)
                        5'd0: rtu_mask = 8'hf0;
                        5'd1: rtu_mask = 8'h3c;
                        5'd2: rtu_mask = 8'h01;
                        5'd3: rtu_mask = 8'hf0;
                        5'd4: rtu_mask = 8'h78;
                        5'd5: rtu_mask = 8'h1f;
                        default: rtu_mask = 8'h00;
                    endcase
                end
                8'd8: begin
                    case (chunk)
                        5'd0: rtu_mask = 8'hf0;
                        5'd1: rtu_mask = 8'h1e;
                        5'd2: rtu_mask = 8'h01;
                        5'd3: rtu_mask = 8'hf0;
                        5'd4: rtu_mask = 8'h78;
                        5'd5: rtu_mask = 8'h1f;
                        default: rtu_mask = 8'h00;
                    endcase
                end
                8'd10: begin
                    case (chunk)
                        5'd0: rtu_mask = 8'hf0;
                        5'd1: rtu_mask = 8'h78;
                        5'd2: rtu_mask = 8'h01;
                        5'd3: rtu_mask = 8'hf0;
                        5'd4: rtu_mask = 8'h78;
                        5'd5: rtu_mask = 8'h1f;
                        default: rtu_mask = 8'h00;
                    endcase
                end
                8'd11: begin
                    case (chunk)
                        5'd0: rtu_mask = 8'hf0;
                        5'd1: rtu_mask = 8'hf0;
                        5'd2: rtu_mask = 8'h01;
                        5'd3: rtu_mask = 8'hf0;
                        5'd4: rtu_mask = 8'h78;
                        5'd5: rtu_mask = 8'h1f;
                        default: rtu_mask = 8'h00;
                    endcase
                end
                8'd12: begin
                    case (chunk)
                        5'd0: rtu_mask = 8'hf1;
                        5'd1: rtu_mask = 8'he0;
                        5'd2: rtu_mask = 8'h01;
                        5'd3: rtu_mask = 8'hf0;
                        5'd4: rtu_mask = 8'h78;
                        5'd5: rtu_mask = 8'h1f;
                        default: rtu_mask = 8'h00;
                    endcase
                end
                8'd13: begin
                    case (chunk)
                        5'd0: rtu_mask = 8'hf3;
                        5'd1: rtu_mask = 8'hc0;
                        5'd2: rtu_mask = 8'h01;
                        5'd3: rtu_mask = 8'hf0;
                        5'd4: rtu_mask = 8'h7f;
                        5'd5: rtu_mask = 8'hff;
                        default: rtu_mask = 8'h00;
                    endcase
                end
                8'd14: begin
                    case (chunk)
                        5'd0: rtu_mask = 8'hf1;
                        5'd1: rtu_mask = 8'he0;
                        5'd2: rtu_mask = 8'h01;
                        5'd3: rtu_mask = 8'hf0;
                        5'd4: rtu_mask = 8'h7f;
                        5'd5: rtu_mask = 8'hff;
                        default: rtu_mask = 8'h00;
                    endcase
                end
                8'd15: begin
                    case (chunk)
                        5'd0: rtu_mask = 8'hf0;
                        5'd1: rtu_mask = 8'hf0;
                        5'd2: rtu_mask = 8'h01;
                        5'd3: rtu_mask = 8'he0;
                        5'd4: rtu_mask = 8'h3f;
                        5'd5: rtu_mask = 8'hfe;
                        default: rtu_mask = 8'h00;
                    endcase
                end
                8'd16: begin
                    case (chunk)
                        5'd0: rtu_mask = 8'hf0;
                        5'd1: rtu_mask = 8'h78;
                        5'd2: rtu_mask = 8'h01;
                        5'd3: rtu_mask = 8'hc0;
                        5'd4: rtu_mask = 8'h1f;
                        5'd5: rtu_mask = 8'hf8;
                        default: rtu_mask = 8'h00;
                    endcase
                end
                8'd17: begin
                    case (chunk)
                        5'd0: rtu_mask = 8'hf0;
                        5'd1: rtu_mask = 8'h3c;
                        5'd2: rtu_mask = 8'h01;
                        5'd3: rtu_mask = 8'h80;
                        5'd4: rtu_mask = 8'h0f;
                        5'd5: rtu_mask = 8'hf0;
                        default: rtu_mask = 8'h00;
                    endcase
                end
                default: rtu_mask = 8'h00;
            endcase
        end
    endfunction

    function [7:0] rtu_subtitle_mask;
        input [7:0] row;
        input [4:0] chunk;
        begin
            rtu_subtitle_mask = 8'h00;
            case (row)
                8'd0: begin
                    case (chunk)
                        5'd0: rtu_subtitle_mask = 8'ha2;
                        5'd1: rtu_subtitle_mask = 8'h89;
                        5'd2: rtu_subtitle_mask = 8'hc8;
                        5'd3: rtu_subtitle_mask = 8'h9c;
                        5'd4: rtu_subtitle_mask = 8'hfb;
                        5'd5: rtu_subtitle_mask = 8'h9c;
                        5'd6: rtu_subtitle_mask = 8'h89;
                        5'd7: rtu_subtitle_mask = 8'he0;
                        default: rtu_subtitle_mask = 8'h00;
                    endcase
                end
                8'd1: begin
                    case (chunk)
                        5'd0: rtu_subtitle_mask = 8'h32;
                        5'd1: rtu_subtitle_mask = 8'hca;
                        5'd2: rtu_subtitle_mask = 8'h28;
                        5'd3: rtu_subtitle_mask = 8'ha2;
                        5'd4: rtu_subtitle_mask = 8'h21;
                        5'd5: rtu_subtitle_mask = 8'h22;
                        5'd6: rtu_subtitle_mask = 8'hca;
                        default: rtu_subtitle_mask = 8'h00;
                    endcase
                end
                8'd2: begin
                    case (chunk)
                        5'd0: rtu_subtitle_mask = 8'hb2;
                        5'd1: rtu_subtitle_mask = 8'hca;
                        5'd2: rtu_subtitle_mask = 8'h28;
                        5'd3: rtu_subtitle_mask = 8'ha2;
                        5'd4: rtu_subtitle_mask = 8'h21;
                        5'd5: rtu_subtitle_mask = 8'h22;
                        5'd6: rtu_subtitle_mask = 8'hca;
                        default: rtu_subtitle_mask = 8'h00;
                    endcase
                end
                8'd3: begin
                    case (chunk)
                        5'd0: rtu_subtitle_mask = 8'haa;
                        5'd1: rtu_subtitle_mask = 8'haa;
                        5'd2: rtu_subtitle_mask = 8'h28;
                        5'd3: rtu_subtitle_mask = 8'hbe;
                        5'd4: rtu_subtitle_mask = 8'h21;
                        5'd5: rtu_subtitle_mask = 8'h22;
                        5'd6: rtu_subtitle_mask = 8'ha9;
                        5'd7: rtu_subtitle_mask = 8'hc0;
                        default: rtu_subtitle_mask = 8'h00;
                    endcase
                end
                8'd4: begin
                    case (chunk)
                        5'd0: rtu_subtitle_mask = 8'ha6;
                        5'd1: rtu_subtitle_mask = 8'h9a;
                        5'd2: rtu_subtitle_mask = 8'h28;
                        5'd3: rtu_subtitle_mask = 8'ha2;
                        5'd4: rtu_subtitle_mask = 8'h21;
                        5'd5: rtu_subtitle_mask = 8'h22;
                        5'd6: rtu_subtitle_mask = 8'h98;
                        5'd7: rtu_subtitle_mask = 8'h20;
                        default: rtu_subtitle_mask = 8'h00;
                    endcase
                end
                8'd5: begin
                    case (chunk)
                        5'd0: rtu_subtitle_mask = 8'ha6;
                        5'd1: rtu_subtitle_mask = 8'h9a;
                        5'd2: rtu_subtitle_mask = 8'h25;
                        5'd3: rtu_subtitle_mask = 8'h22;
                        5'd4: rtu_subtitle_mask = 8'h21;
                        5'd5: rtu_subtitle_mask = 8'h22;
                        5'd6: rtu_subtitle_mask = 8'h98;
                        5'd7: rtu_subtitle_mask = 8'h20;
                        default: rtu_subtitle_mask = 8'h00;
                    endcase
                end
                8'd6: begin
                    case (chunk)
                        5'd0: rtu_subtitle_mask = 8'ha2;
                        5'd1: rtu_subtitle_mask = 8'h89;
                        5'd2: rtu_subtitle_mask = 8'hc2;
                        5'd3: rtu_subtitle_mask = 8'h22;
                        5'd4: rtu_subtitle_mask = 8'h23;
                        5'd5: rtu_subtitle_mask = 8'h9c;
                        5'd6: rtu_subtitle_mask = 8'h8b;
                        5'd7: rtu_subtitle_mask = 8'hc0;
                        default: rtu_subtitle_mask = 8'h00;
                    endcase
                end
                default: rtu_subtitle_mask = 8'h00;
            endcase
        end
    endfunction

    function [7:0] unilab_mask;
        input [7:0] row;
        input [4:0] chunk;
        begin
            unilab_mask = 8'h00;
            case (row)
                8'd0, 8'd3: begin
                    case (chunk)
                        5'd0: unilab_mask = 8'hf0;
                        5'd3: unilab_mask = 8'h03;
                        5'd4: unilab_mask = 8'h80;
                        5'd6: unilab_mask = 8'h38;
                        default: unilab_mask = 8'h00;
                    endcase
                end
                8'd1, 8'd2: begin
                    case (chunk)
                        5'd0: unilab_mask = 8'hf0;
                        5'd3: unilab_mask = 8'h73;
                        5'd4: unilab_mask = 8'h80;
                        5'd6: unilab_mask = 8'h38;
                        default: unilab_mask = 8'h00;
                    endcase
                end
                8'd4: begin
                    case (chunk)
                        5'd0: unilab_mask = 8'hf0;
                        5'd2: unilab_mask = 8'h70;
                        5'd3: unilab_mask = 8'h03;
                        5'd4: unilab_mask = 8'h80;
                        5'd6: unilab_mask = 8'h38;
                        default: unilab_mask = 8'h00;
                    endcase
                end
                8'd5: begin
                    case (chunk)
                        5'd0: unilab_mask = 8'hf0;
                        5'd1: unilab_mask = 8'h03;
                        5'd2: unilab_mask = 8'hfe;
                        5'd3: unilab_mask = 8'h73;
                        5'd4: unilab_mask = 8'h80;
                        5'd5: unilab_mask = 8'hff;
                        5'd6: unilab_mask = 8'h3e;
                        default: unilab_mask = 8'h00;
                    endcase
                end
                8'd6: begin
                    case (chunk)
                        5'd0: unilab_mask = 8'hf0;
                        5'd1: unilab_mask = 8'hf3;
                        5'd2: unilab_mask = 8'hfe;
                        5'd3: unilab_mask = 8'h73;
                        5'd4: unilab_mask = 8'h81;
                        5'd5: unilab_mask = 8'hff;
                        5'd6: unilab_mask = 8'h3f;
                        default: unilab_mask = 8'h00;
                    endcase
                end
                8'd7: begin
                    case (chunk)
                        5'd0: unilab_mask = 8'hf0;
                        5'd1: unilab_mask = 8'hf3;
                        5'd2: unilab_mask = 8'h8e;
                        5'd3: unilab_mask = 8'h73;
                        5'd4: unilab_mask = 8'h81;
                        5'd5: unilab_mask = 8'hff;
                        5'd6: unilab_mask = 8'h3f;
                        5'd7: unilab_mask = 8'h80;
                        default: unilab_mask = 8'h00;
                    endcase
                end
                8'd8, 8'd9: begin
                    case (chunk)
                        5'd0: unilab_mask = 8'hf0;
                        5'd1: unilab_mask = 8'hf3;
                        5'd2: unilab_mask = 8'h8e;
                        5'd3: unilab_mask = 8'h73;
                        5'd4: unilab_mask = 8'h81;
                        5'd5: unilab_mask = 8'hcf;
                        5'd6: unilab_mask = 8'h39;
                        5'd7: unilab_mask = 8'h80;
                        default: unilab_mask = 8'h00;
                    endcase
                end
                8'd10: begin
                    case (chunk)
                        5'd0: unilab_mask = 8'h7f;
                        5'd1: unilab_mask = 8'he3;
                        5'd2: unilab_mask = 8'h8e;
                        5'd3: unilab_mask = 8'h73;
                        5'd4: unilab_mask = 8'h81;
                        5'd5: unilab_mask = 8'hcf;
                        5'd6: unilab_mask = 8'h39;
                        5'd7: unilab_mask = 8'h80;
                        default: unilab_mask = 8'h00;
                    endcase
                end
                8'd11: begin
                    case (chunk)
                        5'd0: unilab_mask = 8'h7f;
                        5'd1: unilab_mask = 8'he3;
                        5'd2: unilab_mask = 8'h8e;
                        5'd3: unilab_mask = 8'h73;
                        5'd4: unilab_mask = 8'hfd;
                        5'd5: unilab_mask = 8'hff;
                        5'd6: unilab_mask = 8'h3f;
                        5'd7: unilab_mask = 8'h80;
                        default: unilab_mask = 8'h00;
                    endcase
                end
                8'd12: begin
                    case (chunk)
                        5'd0: unilab_mask = 8'h1f;
                        5'd1: unilab_mask = 8'hc3;
                        5'd2: unilab_mask = 8'h8e;
                        5'd3: unilab_mask = 8'h73;
                        5'd4: unilab_mask = 8'hfd;
                        5'd5: unilab_mask = 8'hff;
                        5'd6: unilab_mask = 8'h3f;
                        default: unilab_mask = 8'h00;
                    endcase
                end
                8'd13: begin
                    case (chunk)
                        5'd0: unilab_mask = 8'h0f;
                        5'd1: unilab_mask = 8'h03;
                        5'd2: unilab_mask = 8'h8e;
                        5'd3: unilab_mask = 8'h73;
                        5'd4: unilab_mask = 8'hfc;
                        5'd5: unilab_mask = 8'hff;
                        5'd6: unilab_mask = 8'h3e;
                        default: unilab_mask = 8'h00;
                    endcase
                end
                default: unilab_mask = 8'h00;
            endcase
        end
    endfunction

    function [7:0] unilab_accent_mask;
        input [7:0] row;
        input [4:0] chunk;
        begin
            unilab_accent_mask = 8'h00;
            case (row)
                8'd0, 8'd1, 8'd2: begin
                    case (chunk)
                        5'd1: unilab_accent_mask = 8'he0;
                        default: unilab_accent_mask = 8'h00;
                    endcase
                end
                8'd3: begin
                    case (chunk)
                        5'd1: unilab_accent_mask = 8'h20;
                        default: unilab_accent_mask = 8'h00;
                    endcase
                end
                default: unilab_accent_mask = 8'h00;
            endcase
        end
    endfunction

    function [7:0] vulkos_mask;
        input [7:0] row;
        input [4:0] chunk;
        begin
            vulkos_mask = 8'h00;
            case (row)
                8'd0: begin
                    case (chunk)
                        5'd0: vulkos_mask = 8'he0;
                        5'd1: vulkos_mask = 8'hec;
                        5'd2: vulkos_mask = 8'h19;
                        5'd3: vulkos_mask = 8'h80;
                        5'd4: vulkos_mask = 8'h61;
                        5'd5: vulkos_mask = 8'hcf;
                        5'd6: vulkos_mask = 8'hf0;
                        5'd7: vulkos_mask = 8'hfe;
                        default: vulkos_mask = 8'h00;
                    endcase
                end
                8'd1: begin
                    case (chunk)
                        5'd0: vulkos_mask = 8'he0;
                        5'd1: vulkos_mask = 8'hec;
                        5'd2: vulkos_mask = 8'h19;
                        5'd3: vulkos_mask = 8'h80;
                        5'd4: vulkos_mask = 8'h63;
                        5'd5: vulkos_mask = 8'h93;
                        5'd6: vulkos_mask = 8'hf9;
                        5'd7: vulkos_mask = 8'hff;
                        default: vulkos_mask = 8'h00;
                    endcase
                end
                8'd2: begin
                    case (chunk)
                        5'd0: vulkos_mask = 8'h71;
                        5'd1: vulkos_mask = 8'hcc;
                        5'd2: vulkos_mask = 8'h19;
                        5'd3: vulkos_mask = 8'h80;
                        5'd4: vulkos_mask = 8'h67;
                        5'd5: vulkos_mask = 8'h10;
                        5'd6: vulkos_mask = 8'hfb;
                        default: vulkos_mask = 8'h00;
                    endcase
                end
                8'd3: begin
                    case (chunk)
                        5'd0: vulkos_mask = 8'h71;
                        5'd1: vulkos_mask = 8'hcc;
                        5'd2: vulkos_mask = 8'h19;
                        5'd3: vulkos_mask = 8'h80;
                        5'd4: vulkos_mask = 8'h6e;
                        5'd5: vulkos_mask = 8'h18;
                        5'd6: vulkos_mask = 8'h3b;
                        default: vulkos_mask = 8'h00;
                    endcase
                end
                8'd4: begin
                    case (chunk)
                        5'd0: vulkos_mask = 8'h3b;
                        5'd1: vulkos_mask = 8'h8c;
                        5'd2: vulkos_mask = 8'h19;
                        5'd3: vulkos_mask = 8'h80;
                        5'd4: vulkos_mask = 8'h7c;
                        5'd5: vulkos_mask = 8'h19;
                        5'd6: vulkos_mask = 8'hb9;
                        5'd7: vulkos_mask = 8'hfc;
                        default: vulkos_mask = 8'h00;
                    endcase
                end
                8'd5: begin
                    case (chunk)
                        5'd0: vulkos_mask = 8'h3b;
                        5'd1: vulkos_mask = 8'h8c;
                        5'd2: vulkos_mask = 8'h19;
                        5'd3: vulkos_mask = 8'h80;
                        5'd4: vulkos_mask = 8'h7e;
                        5'd5: vulkos_mask = 8'h1d;
                        5'd6: vulkos_mask = 8'h98;
                        5'd7: vulkos_mask = 8'hfe;
                        default: vulkos_mask = 8'h00;
                    endcase
                end
                8'd6: begin
                    case (chunk)
                        5'd0: vulkos_mask = 8'h1f;
                        5'd1: vulkos_mask = 8'h0e;
                        5'd2: vulkos_mask = 8'h19;
                        5'd3: vulkos_mask = 8'h80;
                        5'd4: vulkos_mask = 8'h7f;
                        5'd5: vulkos_mask = 8'h1c;
                        5'd6: vulkos_mask = 8'h18;
                        5'd7: vulkos_mask = 8'h03;
                        default: vulkos_mask = 8'h00;
                    endcase
                end
                8'd7: begin
                    case (chunk)
                        5'd0: vulkos_mask = 8'h1f;
                        5'd1: vulkos_mask = 8'h07;
                        5'd2: vulkos_mask = 8'hf9;
                        5'd3: vulkos_mask = 8'h80;
                        5'd4: vulkos_mask = 8'h6f;
                        5'd5: vulkos_mask = 8'h9f;
                        5'd6: vulkos_mask = 8'h08;
                        5'd7: vulkos_mask = 8'h03;
                        default: vulkos_mask = 8'h00;
                    endcase
                end
                8'd8: begin
                    case (chunk)
                        5'd0: vulkos_mask = 8'h0e;
                        5'd1: vulkos_mask = 8'h07;
                        5'd2: vulkos_mask = 8'hf1;
                        5'd3: vulkos_mask = 8'hfe;
                        5'd4: vulkos_mask = 8'h63;
                        5'd5: vulkos_mask = 8'hdf;
                        5'd6: vulkos_mask = 8'hcb;
                        5'd7: vulkos_mask = 8'hfe;
                        default: vulkos_mask = 8'h00;
                    endcase
                end
                8'd9: begin
                    case (chunk)
                        5'd0: vulkos_mask = 8'h0e;
                        5'd1: vulkos_mask = 8'h03;
                        5'd2: vulkos_mask = 8'hf1;
                        5'd3: vulkos_mask = 8'hfe;
                        5'd4: vulkos_mask = 8'h61;
                        5'd5: vulkos_mask = 8'hef;
                        5'd6: vulkos_mask = 8'hf1;
                        5'd7: vulkos_mask = 8'hfc;
                        default: vulkos_mask = 8'h00;
                    endcase
                end
                default: vulkos_mask = 8'h00;
            endcase
        end
    endfunction

    function [7:0] cdg_blue_mask;
        input [7:0] row;
        input [4:0] chunk;
        begin
            cdg_blue_mask = 8'h00;
            case (row)
                8'd1: begin
                    case (chunk)
                        5'd0: cdg_blue_mask = 8'h1f;
                        5'd1: cdg_blue_mask = 8'hf8;
                        default: cdg_blue_mask = 8'h00;
                    endcase
                end
                8'd2: begin
                    case (chunk)
                        5'd0: cdg_blue_mask = 8'h20;
                        5'd1: cdg_blue_mask = 8'h04;
                        default: cdg_blue_mask = 8'h00;
                    endcase
                end
                8'd3: begin
                    case (chunk)
                        5'd0: cdg_blue_mask = 8'h40;
                        5'd1: cdg_blue_mask = 8'h02;
                        default: cdg_blue_mask = 8'h00;
                    endcase
                end
                8'd4: begin
                    case (chunk)
                        5'd0: cdg_blue_mask = 8'h4f;
                        5'd1: cdg_blue_mask = 8'hf2;
                        default: cdg_blue_mask = 8'h00;
                    endcase
                end
                8'd5, 8'd6, 8'd7, 8'd8, 8'd9: begin
                    case (chunk)
                        5'd0: cdg_blue_mask = 8'h50;
                        5'd1: cdg_blue_mask = 8'h0a;
                        default: cdg_blue_mask = 8'h00;
                    endcase
                end
                8'd10, 8'd11, 8'd12, 8'd13, 8'd14: begin
                    case (chunk)
                        5'd0: cdg_blue_mask = 8'h50;
                        5'd1: cdg_blue_mask = 8'h02;
                        default: cdg_blue_mask = 8'h00;
                    endcase
                end
                8'd15: begin
                    case (chunk)
                        5'd0: cdg_blue_mask = 8'h4f;
                        5'd1: cdg_blue_mask = 8'he2;
                        default: cdg_blue_mask = 8'h00;
                    endcase
                end
                8'd16: begin
                    case (chunk)
                        5'd0: cdg_blue_mask = 8'h20;
                        5'd1: cdg_blue_mask = 8'h12;
                        default: cdg_blue_mask = 8'h00;
                    endcase
                end
                8'd17: begin
                    case (chunk)
                        5'd0: cdg_blue_mask = 8'h1f;
                        5'd1: cdg_blue_mask = 8'hea;
                        default: cdg_blue_mask = 8'h00;
                    endcase
                end
                8'd18: begin
                    case (chunk)
                        5'd1: cdg_blue_mask = 8'h06;
                        default: cdg_blue_mask = 8'h00;
                    endcase
                end
                8'd19: begin
                    case (chunk)
                        5'd1: cdg_blue_mask = 8'h02;
                        default: cdg_blue_mask = 8'h00;
                    endcase
                end
                default: cdg_blue_mask = 8'h00;
            endcase
        end
    endfunction

    function [7:0] cdg_cyan_mask;
        input [7:0] row;
        input [4:0] chunk;
        begin
            cdg_cyan_mask = 8'h00;
            case (row)
                8'd0, 8'd2: begin
                    case (chunk)
                        5'd0: cdg_cyan_mask = 8'h01;
                        default: cdg_cyan_mask = 8'h00;
                    endcase
                end
                8'd1: begin
                    case (chunk)
                        5'd0: cdg_cyan_mask = 8'h03;
                        5'd1: cdg_cyan_mask = 8'h80;
                        default: cdg_cyan_mask = 8'h00;
                    endcase
                end
                8'd7, 8'd11: begin
                    case (chunk)
                        5'd0: cdg_cyan_mask = 8'h03;
                        5'd1: cdg_cyan_mask = 8'he0;
                        default: cdg_cyan_mask = 8'h00;
                    endcase
                end
                8'd8, 8'd10: begin
                    case (chunk)
                        5'd0: cdg_cyan_mask = 8'h13;
                        5'd1: cdg_cyan_mask = 8'he8;
                        default: cdg_cyan_mask = 8'h00;
                    endcase
                end
                8'd9: begin
                    case (chunk)
                        5'd0: cdg_cyan_mask = 8'h3b;
                        5'd1: cdg_cyan_mask = 8'hfc;
                        default: cdg_cyan_mask = 8'h00;
                    endcase
                end
                default: cdg_cyan_mask = 8'h00;
            endcase
        end
    endfunction

    function [7:0] cdg_chip_mask;
        input [7:0] row;
        input [4:0] chunk;
        begin
            cdg_chip_mask = 8'h00;
            case (row)
                8'd0: begin
                    case (chunk)
                        5'd0: cdg_chip_mask = 8'h7a;
                        5'd1: cdg_chip_mask = 8'h2e;
                        5'd2: cdg_chip_mask = 8'hf0;
                        default: cdg_chip_mask = 8'h00;
                    endcase
                end
                8'd1, 8'd2: begin
                    case (chunk)
                        5'd0: cdg_chip_mask = 8'h82;
                        5'd1: cdg_chip_mask = 8'h24;
                        5'd2: cdg_chip_mask = 8'h88;
                        default: cdg_chip_mask = 8'h00;
                    endcase
                end
                8'd3: begin
                    case (chunk)
                        5'd0: cdg_chip_mask = 8'h83;
                        5'd1: cdg_chip_mask = 8'he4;
                        5'd2: cdg_chip_mask = 8'hf0;
                        default: cdg_chip_mask = 8'h00;
                    endcase
                end
                8'd4, 8'd5: begin
                    case (chunk)
                        5'd0: cdg_chip_mask = 8'h82;
                        5'd1: cdg_chip_mask = 8'h24;
                        5'd2: cdg_chip_mask = 8'h80;
                        default: cdg_chip_mask = 8'h00;
                    endcase
                end
                8'd6: begin
                    case (chunk)
                        5'd0: cdg_chip_mask = 8'h7a;
                        5'd1: cdg_chip_mask = 8'h2e;
                        5'd2: cdg_chip_mask = 8'h80;
                        default: cdg_chip_mask = 8'h00;
                    endcase
                end
                default: cdg_chip_mask = 8'h00;
            endcase
        end
    endfunction

    function [7:0] cdg_design_mask;
        input [7:0] row;
        input [4:0] chunk;
        begin
            cdg_design_mask = 8'h00;
            case (row)
                8'd0: begin
                    case (chunk)
                        5'd0: cdg_design_mask = 8'hf3;
                        5'd1: cdg_design_mask = 8'he7;
                        5'd2: cdg_design_mask = 8'hb9;
                        5'd3: cdg_design_mask = 8'he8;
                        5'd4: cdg_design_mask = 8'h80;
                        default: cdg_design_mask = 8'h00;
                    endcase
                end
                8'd1, 8'd2: begin
                    case (chunk)
                        5'd0: cdg_design_mask = 8'h8a;
                        5'd1: cdg_design_mask = 8'h08;
                        5'd2: cdg_design_mask = 8'h12;
                        5'd3: cdg_design_mask = 8'h0c;
                        5'd4: cdg_design_mask = 8'h80;
                        default: cdg_design_mask = 8'h00;
                    endcase
                end
                8'd3: begin
                    case (chunk)
                        5'd0: cdg_design_mask = 8'h8b;
                        5'd1: cdg_design_mask = 8'hc7;
                        5'd2: cdg_design_mask = 8'h12;
                        5'd3: cdg_design_mask = 8'hea;
                        5'd4: cdg_design_mask = 8'h80;
                        default: cdg_design_mask = 8'h00;
                    endcase
                end
                8'd4, 8'd5: begin
                    case (chunk)
                        5'd0: cdg_design_mask = 8'h8a;
                        5'd2: cdg_design_mask = 8'h92;
                        5'd3: cdg_design_mask = 8'h29;
                        5'd4: cdg_design_mask = 8'h80;
                        default: cdg_design_mask = 8'h00;
                    endcase
                end
                8'd6: begin
                    case (chunk)
                        5'd0: cdg_design_mask = 8'hf3;
                        5'd1: cdg_design_mask = 8'hef;
                        5'd2: cdg_design_mask = 8'h39;
                        5'd3: cdg_design_mask = 8'he8;
                        5'd4: cdg_design_mask = 8'h80;
                        default: cdg_design_mask = 8'h00;
                    endcase
                end
                default: cdg_design_mask = 8'h00;
            endcase
        end
    endfunction

    function [7:0] cdg_germany_mask;
        input [7:0] row;
        input [4:0] chunk;
        begin
            cdg_germany_mask = 8'h00;
            case (row)
                8'd0: begin
                    case (chunk)
                        5'd0: cdg_germany_mask = 8'h7b;
                        5'd1: cdg_germany_mask = 8'hef;
                        5'd2: cdg_germany_mask = 8'h22;
                        5'd3: cdg_germany_mask = 8'h72;
                        5'd4: cdg_germany_mask = 8'h28;
                        5'd5: cdg_germany_mask = 8'h80;
                        default: cdg_germany_mask = 8'h00;
                    endcase
                end
                8'd1: begin
                    case (chunk)
                        5'd0: cdg_germany_mask = 8'h82;
                        5'd1: cdg_germany_mask = 8'h08;
                        5'd2: cdg_germany_mask = 8'hb6;
                        5'd3: cdg_germany_mask = 8'h8b;
                        5'd4: cdg_germany_mask = 8'h28;
                        5'd5: cdg_germany_mask = 8'h80;
                        default: cdg_germany_mask = 8'h00;
                    endcase
                end
                8'd2: begin
                    case (chunk)
                        5'd0: cdg_germany_mask = 8'h82;
                        5'd1: cdg_germany_mask = 8'h08;
                        5'd2: cdg_germany_mask = 8'haa;
                        5'd3: cdg_germany_mask = 8'h8b;
                        5'd4: cdg_germany_mask = 8'h25;
                        default: cdg_germany_mask = 8'h00;
                    endcase
                end
                8'd3: begin
                    case (chunk)
                        5'd0: cdg_germany_mask = 8'hbb;
                        5'd1: cdg_germany_mask = 8'hcf;
                        5'd2: cdg_germany_mask = 8'h2a;
                        5'd3: cdg_germany_mask = 8'hfa;
                        5'd4: cdg_germany_mask = 8'ha2;
                        default: cdg_germany_mask = 8'h00;
                    endcase
                end
                8'd4: begin
                    case (chunk)
                        5'd0: cdg_germany_mask = 8'h8a;
                        5'd1: cdg_germany_mask = 8'h0a;
                        5'd2: cdg_germany_mask = 8'h22;
                        5'd3: cdg_germany_mask = 8'h8a;
                        5'd4: cdg_germany_mask = 8'h62;
                        default: cdg_germany_mask = 8'h00;
                    endcase
                end
                8'd5: begin
                    case (chunk)
                        5'd0: cdg_germany_mask = 8'h8a;
                        5'd1: cdg_germany_mask = 8'h09;
                        5'd2: cdg_germany_mask = 8'h22;
                        5'd3: cdg_germany_mask = 8'h8a;
                        5'd4: cdg_germany_mask = 8'h62;
                        default: cdg_germany_mask = 8'h00;
                    endcase
                end
                8'd6: begin
                    case (chunk)
                        5'd0: cdg_germany_mask = 8'h7b;
                        5'd1: cdg_germany_mask = 8'he8;
                        5'd2: cdg_germany_mask = 8'ha2;
                        5'd3: cdg_germany_mask = 8'h8a;
                        5'd4: cdg_germany_mask = 8'h22;
                        default: cdg_germany_mask = 8'h00;
                    endcase
                end
                default: cdg_germany_mask = 8'h00;
            endcase
        end
    endfunction

    function [7:0] tt_dark_mask;
        input [7:0] row;
        input [4:0] chunk;
        begin
            tt_dark_mask = 8'h00;
            case (row)
                8'd2: begin
                    case (chunk)
                        5'd1: tt_dark_mask = 8'h7e;
                        default: tt_dark_mask = 8'h00;
                    endcase
                end
                8'd3: begin
                    case (chunk)
                        5'd0: tt_dark_mask = 8'h01;
                        5'd1: tt_dark_mask = 8'hff;
                        5'd2: tt_dark_mask = 8'h80;
                        default: tt_dark_mask = 8'h00;
                    endcase
                end
                8'd4, 8'd19: begin
                    case (chunk)
                        5'd0: tt_dark_mask = 8'h03;
                        5'd1: tt_dark_mask = 8'h81;
                        5'd2: tt_dark_mask = 8'hc0;
                        default: tt_dark_mask = 8'h00;
                    endcase
                end
                8'd5: begin
                    case (chunk)
                        5'd0: tt_dark_mask = 8'h06;
                        5'd2: tt_dark_mask = 8'h60;
                        default: tt_dark_mask = 8'h00;
                    endcase
                end
                8'd6: begin
                    case (chunk)
                        5'd0: tt_dark_mask = 8'h0c;
                        5'd2: tt_dark_mask = 8'h30;
                        default: tt_dark_mask = 8'h00;
                    endcase
                end
                8'd7, 8'd8: begin
                    case (chunk)
                        5'd0: tt_dark_mask = 8'h1f;
                        5'd1: tt_dark_mask = 8'hfc;
                        5'd2: tt_dark_mask = 8'h18;
                        default: tt_dark_mask = 8'h00;
                    endcase
                end
                8'd9: begin
                    case (chunk)
                        5'd0: tt_dark_mask = 8'h37;
                        5'd1: tt_dark_mask = 8'hfc;
                        5'd2: tt_dark_mask = 8'h0c;
                        default: tt_dark_mask = 8'h00;
                    endcase
                end
                8'd10, 8'd11: begin
                    case (chunk)
                        5'd0: tt_dark_mask = 8'h30;
                        5'd1: tt_dark_mask = 8'he0;
                        5'd2: tt_dark_mask = 8'h0c;
                        default: tt_dark_mask = 8'h00;
                    endcase
                end
                8'd12, 8'd13, 8'd14: begin
                    case (chunk)
                        5'd0: tt_dark_mask = 8'h30;
                        5'd1: tt_dark_mask = 8'hef;
                        5'd2: tt_dark_mask = 8'hfc;
                        default: tt_dark_mask = 8'h00;
                    endcase
                end
                8'd15, 8'd16: begin
                    case (chunk)
                        5'd0: tt_dark_mask = 8'h18;
                        5'd1: tt_dark_mask = 8'he1;
                        5'd2: tt_dark_mask = 8'hd8;
                        default: tt_dark_mask = 8'h00;
                    endcase
                end
                8'd17: begin
                    case (chunk)
                        5'd0: tt_dark_mask = 8'h0c;
                        5'd1: tt_dark_mask = 8'he1;
                        5'd2: tt_dark_mask = 8'hf0;
                        default: tt_dark_mask = 8'h00;
                    endcase
                end
                8'd18: begin
                    case (chunk)
                        5'd0: tt_dark_mask = 8'h06;
                        5'd1: tt_dark_mask = 8'h01;
                        5'd2: tt_dark_mask = 8'he0;
                        default: tt_dark_mask = 8'h00;
                    endcase
                end
                8'd20: begin
                    case (chunk)
                        5'd0: tt_dark_mask = 8'h01;
                        5'd1: tt_dark_mask = 8'hff;
                        5'd2: tt_dark_mask = 8'hc0;
                        default: tt_dark_mask = 8'h00;
                    endcase
                end
                8'd21: begin
                    case (chunk)
                        5'd1: tt_dark_mask = 8'h7f;
                        5'd2: tt_dark_mask = 8'hc0;
                        default: tt_dark_mask = 8'h00;
                    endcase
                end
                default: tt_dark_mask = 8'h00;
            endcase
        end
    endfunction

    function [7:0] tt_white_mask;
        input [7:0] row;
        input [4:0] chunk;
        begin
            tt_white_mask = 8'h00;
            case (row)
                8'd3: begin
                    case (chunk)
                        5'd1: tt_white_mask = 8'h7e;
                        default: tt_white_mask = 8'h00;
                    endcase
                end
                8'd4: begin
                    case (chunk)
                        5'd0: tt_white_mask = 8'h01;
                        5'd1: tt_white_mask = 8'h81;
                        5'd2: tt_white_mask = 8'h80;
                        default: tt_white_mask = 8'h00;
                    endcase
                end
                8'd5: begin
                    case (chunk)
                        5'd0: tt_white_mask = 8'h02;
                        5'd2: tt_white_mask = 8'h40;
                        default: tt_white_mask = 8'h00;
                    endcase
                end
                8'd6: begin
                    case (chunk)
                        5'd0: tt_white_mask = 8'h0f;
                        5'd1: tt_white_mask = 8'hf8;
                        5'd2: tt_white_mask = 8'h20;
                        default: tt_white_mask = 8'h00;
                    endcase
                end
                8'd7, 8'd8: begin
                    case (chunk)
                        5'd0: tt_white_mask = 8'h0f;
                        5'd1: tt_white_mask = 8'hf8;
                        5'd2: tt_white_mask = 8'h10;
                        default: tt_white_mask = 8'h00;
                    endcase
                end
                8'd9, 8'd10: begin
                    case (chunk)
                        5'd0: tt_white_mask = 8'h11;
                        5'd1: tt_white_mask = 8'hc0;
                        5'd2: tt_white_mask = 8'h08;
                        default: tt_white_mask = 8'h00;
                    endcase
                end
                8'd11, 8'd12, 8'd13: begin
                    case (chunk)
                        5'd0: tt_white_mask = 8'h11;
                        5'd1: tt_white_mask = 8'hdf;
                        5'd2: tt_white_mask = 8'hf8;
                        default: tt_white_mask = 8'h00;
                    endcase
                end
                8'd14: begin
                    case (chunk)
                        5'd0: tt_white_mask = 8'h11;
                        5'd1: tt_white_mask = 8'hc3;
                        5'd2: tt_white_mask = 8'h88;
                        default: tt_white_mask = 8'h00;
                    endcase
                end
                8'd15, 8'd16: begin
                    case (chunk)
                        5'd0: tt_white_mask = 8'h09;
                        5'd1: tt_white_mask = 8'hc3;
                        5'd2: tt_white_mask = 8'h90;
                        default: tt_white_mask = 8'h00;
                    endcase
                end
                8'd17: begin
                    case (chunk)
                        5'd0: tt_white_mask = 8'h04;
                        5'd1: tt_white_mask = 8'h03;
                        5'd2: tt_white_mask = 8'ha0;
                        default: tt_white_mask = 8'h00;
                    endcase
                end
                8'd18: begin
                    case (chunk)
                        5'd0: tt_white_mask = 8'h02;
                        5'd1: tt_white_mask = 8'h03;
                        5'd2: tt_white_mask = 8'hc0;
                        default: tt_white_mask = 8'h00;
                    endcase
                end
                8'd19: begin
                    case (chunk)
                        5'd0: tt_white_mask = 8'h01;
                        5'd1: tt_white_mask = 8'h83;
                        5'd2: tt_white_mask = 8'h80;
                        default: tt_white_mask = 8'h00;
                    endcase
                end
                8'd20: begin
                    case (chunk)
                        5'd1: tt_white_mask = 8'h7f;
                        5'd2: tt_white_mask = 8'h80;
                        default: tt_white_mask = 8'h00;
                    endcase
                end
                default: tt_white_mask = 8'h00;
            endcase
        end
    endfunction

    function [7:0] tt_pink_mask;
        input [7:0] row;
        input [4:0] chunk;
        begin
            tt_pink_mask = 8'h00;
            case (row)
                8'd6: begin
                    case (chunk)
                        5'd1: tt_pink_mask = 8'h38;
                        default: tt_pink_mask = 8'h00;
                    endcase
                end
                8'd10, 8'd11, 8'd12: begin
                    case (chunk)
                        5'd0: tt_pink_mask = 8'h10;
                        default: tt_pink_mask = 8'h00;
                    endcase
                end
                8'd18, 8'd19, 8'd20: begin
                    case (chunk)
                        5'd1: tt_pink_mask = 8'h02;
                        default: tt_pink_mask = 8'h00;
                    endcase
                end
                default: tt_pink_mask = 8'h00;
            endcase
        end
    endfunction

    function [7:0] tt_cyan_mask;
        input [7:0] row;
        input [4:0] chunk;
        begin
            tt_cyan_mask = 8'h00;
            case (row)
                8'd4: begin
                    case (chunk)
                        5'd2: tt_cyan_mask = 8'h60;
                        default: tt_cyan_mask = 8'h00;
                    endcase
                end
                8'd9, 8'd10, 8'd12, 8'd13, 8'd14, 8'd15: begin
                    case (chunk)
                        5'd0: tt_cyan_mask = 8'h01;
                        default: tt_cyan_mask = 8'h00;
                    endcase
                end
                8'd11: begin
                    case (chunk)
                        5'd0: tt_cyan_mask = 8'h01;
                        5'd1: tt_cyan_mask = 8'h0f;
                        5'd2: tt_cyan_mask = 8'hc0;
                        default: tt_cyan_mask = 8'h00;
                    endcase
                end
                default: tt_cyan_mask = 8'h00;
            endcase
        end
    endfunction

    wire [7:0] heading_gx;
    wire [7:0] heading_gy;
    wire [7:0] heading_x;
    wire [7:0] heading_y;
    wire [7:0] heading_byte;
    wire heading_pixel;
    assign heading_gx = x_group - 8'd52;
    assign heading_gy = y_group - 8'd12;
    assign heading_x = heading_gx;
    assign heading_y = heading_gy;
    assign heading_byte = heading_mask(heading_y, heading_x[7:3]);
    assign heading_pixel =
        (x_group >= 8'd52) && (x_group < 8'd107) &&
        (y_group >= 8'd12) && (y_group < 8'd19) &&
        (heading_x < 8'd55) && (heading_y < 8'd7) &&
        heading_byte[3'd7 - heading_x[2:0]];

    wire [7:0] rtu_gx;
    wire [7:0] rtu_gy;
    wire [7:0] rtu_x;
    wire [7:0] rtu_y;
    wire [7:0] rtu_byte;
    wire rtu_pixel;
    assign rtu_gx = x_group - 8'd22;
    assign rtu_gy = y_group - 8'd37;
    assign rtu_x = rtu_gx;
    assign rtu_y = rtu_gy;
    assign rtu_byte = rtu_mask(rtu_y, rtu_x[7:3]);
    assign rtu_pixel =
        (x_group >= 8'd22) && (x_group < 8'd70) &&
        (y_group >= 8'd37) && (y_group < 8'd55) &&
        (rtu_x < 8'd48) && (rtu_y < 8'd18) &&
        rtu_byte[3'd7 - rtu_x[2:0]];

    wire [7:0] rtu_subtitle_gx;
    wire [7:0] rtu_subtitle_gy;
    wire [7:0] rtu_subtitle_x;
    wire [7:0] rtu_subtitle_y;
    wire [7:0] rtu_subtitle_byte;
    wire rtu_subtitle_pixel;
    assign rtu_subtitle_gx = x_group - 8'd31;
    assign rtu_subtitle_gy = y_group - 8'd58;
    assign rtu_subtitle_x = {rtu_subtitle_gx[6:0], x_phase[1]};
    assign rtu_subtitle_y = {rtu_subtitle_gy[6:0], y_phase[1]};
    assign rtu_subtitle_byte = rtu_subtitle_mask(rtu_subtitle_y, rtu_subtitle_x[7:3]);
    assign rtu_subtitle_pixel =
        (x_group >= 8'd31) && (x_group < 8'd61) &&
        (y_group >= 8'd58) && (y_group < 8'd62) &&
        (rtu_subtitle_x < 8'd59) && (rtu_subtitle_y < 8'd7) &&
        rtu_subtitle_byte[3'd7 - rtu_subtitle_x[2:0]];

    wire [7:0] unilab_gx;
    wire [7:0] unilab_gy;
    wire [7:0] unilab_x;
    wire [7:0] unilab_y;
    wire [7:0] unilab_byte;
    wire unilab_pixel;
    assign unilab_gx = x_group - 8'd88;
    assign unilab_gy = y_group - 8'd40;
    assign unilab_x = unilab_gx;
    assign unilab_y = unilab_gy;
    assign unilab_byte = unilab_mask(unilab_y, unilab_x[7:3]);
    assign unilab_pixel =
        (x_group >= 8'd88) && (x_group < 8'd145) &&
        (y_group >= 8'd40) && (y_group < 8'd54) &&
        (unilab_x < 8'd57) && (unilab_y < 8'd14) &&
        unilab_byte[3'd7 - unilab_x[2:0]];

    wire [7:0] unilab_accent_gx;
    wire [7:0] unilab_accent_gy;
    wire [7:0] unilab_accent_x;
    wire [7:0] unilab_accent_y;
    wire [7:0] unilab_accent_byte;
    wire unilab_accent_pixel;
    assign unilab_accent_gx = x_group - 8'd88;
    assign unilab_accent_gy = y_group - 8'd40;
    assign unilab_accent_x = unilab_accent_gx;
    assign unilab_accent_y = unilab_accent_gy;
    assign unilab_accent_byte = unilab_accent_mask(unilab_accent_y, unilab_accent_x[7:3]);
    assign unilab_accent_pixel =
        (x_group >= 8'd88) && (x_group < 8'd145) &&
        (y_group >= 8'd40) && (y_group < 8'd54) &&
        (unilab_accent_x < 8'd57) && (unilab_accent_y < 8'd14) &&
        unilab_accent_byte[3'd7 - unilab_accent_x[2:0]];

    wire [7:0] vulkos_gx;
    wire [7:0] vulkos_gy;
    wire [7:0] vulkos_x;
    wire [7:0] vulkos_y;
    wire [7:0] vulkos_byte;
    wire vulkos_pixel;
    assign vulkos_gx = x_group - 8'd42;
    assign vulkos_gy = y_group - 8'd86;
    assign vulkos_x = vulkos_gx;
    assign vulkos_y = vulkos_gy;
    assign vulkos_byte = vulkos_mask(vulkos_y, vulkos_x[7:3]);
    assign vulkos_pixel =
        (x_group >= 8'd42) && (x_group < 8'd106) &&
        (y_group >= 8'd86) && (y_group < 8'd96) &&
        (vulkos_x < 8'd64) && (vulkos_y < 8'd10) &&
        vulkos_byte[3'd7 - vulkos_x[2:0]];

    wire [7:0] cdg_blue_gx;
    wire [7:0] cdg_blue_gy;
    wire [7:0] cdg_blue_x;
    wire [7:0] cdg_blue_y;
    wire [7:0] cdg_blue_byte;
    wire cdg_blue_pixel;
    assign cdg_blue_gx = x_group - 8'd110;
    assign cdg_blue_gy = y_group - 8'd79;
    assign cdg_blue_x = cdg_blue_gx;
    assign cdg_blue_y = cdg_blue_gy;
    assign cdg_blue_byte = cdg_blue_mask(cdg_blue_y, cdg_blue_x[7:3]);
    assign cdg_blue_pixel =
        (x_group >= 8'd110) && (x_group < 8'd126) &&
        (y_group >= 8'd79) && (y_group < 8'd99) &&
        (cdg_blue_x < 8'd16) && (cdg_blue_y < 8'd20) &&
        cdg_blue_byte[3'd7 - cdg_blue_x[2:0]];

    wire [7:0] cdg_cyan_gx;
    wire [7:0] cdg_cyan_gy;
    wire [7:0] cdg_cyan_x;
    wire [7:0] cdg_cyan_y;
    wire [7:0] cdg_cyan_byte;
    wire cdg_cyan_pixel;
    assign cdg_cyan_gx = x_group - 8'd110;
    assign cdg_cyan_gy = y_group - 8'd79;
    assign cdg_cyan_x = cdg_cyan_gx;
    assign cdg_cyan_y = cdg_cyan_gy;
    assign cdg_cyan_byte = cdg_cyan_mask(cdg_cyan_y, cdg_cyan_x[7:3]);
    assign cdg_cyan_pixel =
        (x_group >= 8'd110) && (x_group < 8'd126) &&
        (y_group >= 8'd79) && (y_group < 8'd99) &&
        (cdg_cyan_x < 8'd16) && (cdg_cyan_y < 8'd20) &&
        cdg_cyan_byte[3'd7 - cdg_cyan_x[2:0]];

    wire [7:0] cdg_chip_gx;
    wire [7:0] cdg_chip_gy;
    wire [7:0] cdg_chip_x;
    wire [7:0] cdg_chip_y;
    wire [7:0] cdg_chip_byte;
    wire cdg_chip_pixel;
    assign cdg_chip_gx = x_group - 8'd128;
    assign cdg_chip_gy = y_group - 8'd82;
    assign cdg_chip_x = {cdg_chip_gx[6:0], x_phase[1]};
    assign cdg_chip_y = {cdg_chip_gy[6:0], y_phase[1]};
    assign cdg_chip_byte = cdg_chip_mask(cdg_chip_y, cdg_chip_x[7:3]);
    assign cdg_chip_pixel =
        (x_group >= 8'd128) && (x_group < 8'd139) &&
        (y_group >= 8'd82) && (y_group < 8'd86) &&
        (cdg_chip_x < 8'd21) && (cdg_chip_y < 8'd7) &&
        cdg_chip_byte[3'd7 - cdg_chip_x[2:0]];

    wire [7:0] cdg_design_gx;
    wire [7:0] cdg_design_gy;
    wire [7:0] cdg_design_x;
    wire [7:0] cdg_design_y;
    wire [7:0] cdg_design_byte;
    wire cdg_design_pixel;
    assign cdg_design_gx = x_group - 8'd128;
    assign cdg_design_gy = y_group - 8'd87;
    assign cdg_design_x = {cdg_design_gx[6:0], x_phase[1]};
    assign cdg_design_y = {cdg_design_gy[6:0], y_phase[1]};
    assign cdg_design_byte = cdg_design_mask(cdg_design_y, cdg_design_x[7:3]);
    assign cdg_design_pixel =
        (x_group >= 8'd128) && (x_group < 8'd145) &&
        (y_group >= 8'd87) && (y_group < 8'd91) &&
        (cdg_design_x < 8'd33) && (cdg_design_y < 8'd7) &&
        cdg_design_byte[3'd7 - cdg_design_x[2:0]];

    wire [7:0] cdg_germany_gx;
    wire [7:0] cdg_germany_gy;
    wire [7:0] cdg_germany_x;
    wire [7:0] cdg_germany_y;
    wire [7:0] cdg_germany_byte;
    wire cdg_germany_pixel;
    assign cdg_germany_gx = x_group - 8'd128;
    assign cdg_germany_gy = y_group - 8'd92;
    assign cdg_germany_x = {cdg_germany_gx[6:0], x_phase[1]};
    assign cdg_germany_y = {cdg_germany_gy[6:0], y_phase[1]};
    assign cdg_germany_byte = cdg_germany_mask(cdg_germany_y, cdg_germany_x[7:3]);
    assign cdg_germany_pixel =
        (x_group >= 8'd128) && (x_group < 8'd149) &&
        (y_group >= 8'd92) && (y_group < 8'd96) &&
        (cdg_germany_x < 8'd41) && (cdg_germany_y < 8'd7) &&
        cdg_germany_byte[3'd7 - cdg_germany_x[2:0]];

    wire [7:0] tt_dark_gx;
    wire [7:0] tt_dark_gy;
    wire [7:0] tt_dark_x;
    wire [7:0] tt_dark_y;
    wire [7:0] tt_dark_byte;
    wire tt_dark_pixel;
    assign tt_dark_gx = x_group - 8'd10;
    assign tt_dark_gy = y_group - 8'd78;
    assign tt_dark_x = tt_dark_gx;
    assign tt_dark_y = tt_dark_gy;
    assign tt_dark_byte = tt_dark_mask(tt_dark_y, tt_dark_x[7:3]);
    assign tt_dark_pixel =
        (x_group >= 8'd10) && (x_group < 8'd34) &&
        (y_group >= 8'd78) && (y_group < 8'd102) &&
        (tt_dark_x < 8'd24) && (tt_dark_y < 8'd24) &&
        tt_dark_byte[3'd7 - tt_dark_x[2:0]];

    wire [7:0] tt_white_gx;
    wire [7:0] tt_white_gy;
    wire [7:0] tt_white_x;
    wire [7:0] tt_white_y;
    wire [7:0] tt_white_byte;
    wire tt_white_pixel;
    assign tt_white_gx = x_group - 8'd10;
    assign tt_white_gy = y_group - 8'd78;
    assign tt_white_x = tt_white_gx;
    assign tt_white_y = tt_white_gy;
    assign tt_white_byte = tt_white_mask(tt_white_y, tt_white_x[7:3]);
    assign tt_white_pixel =
        (x_group >= 8'd10) && (x_group < 8'd34) &&
        (y_group >= 8'd78) && (y_group < 8'd102) &&
        (tt_white_x < 8'd24) && (tt_white_y < 8'd24) &&
        tt_white_byte[3'd7 - tt_white_x[2:0]];

    wire [7:0] tt_pink_gx;
    wire [7:0] tt_pink_gy;
    wire [7:0] tt_pink_x;
    wire [7:0] tt_pink_y;
    wire [7:0] tt_pink_byte;
    wire tt_pink_pixel;
    assign tt_pink_gx = x_group - 8'd10;
    assign tt_pink_gy = y_group - 8'd78;
    assign tt_pink_x = tt_pink_gx;
    assign tt_pink_y = tt_pink_gy;
    assign tt_pink_byte = tt_pink_mask(tt_pink_y, tt_pink_x[7:3]);
    assign tt_pink_pixel =
        (x_group >= 8'd10) && (x_group < 8'd34) &&
        (y_group >= 8'd78) && (y_group < 8'd102) &&
        (tt_pink_x < 8'd24) && (tt_pink_y < 8'd24) &&
        tt_pink_byte[3'd7 - tt_pink_x[2:0]];

    wire [7:0] tt_cyan_gx;
    wire [7:0] tt_cyan_gy;
    wire [7:0] tt_cyan_x;
    wire [7:0] tt_cyan_y;
    wire [7:0] tt_cyan_byte;
    wire tt_cyan_pixel;
    assign tt_cyan_gx = x_group - 8'd10;
    assign tt_cyan_gy = y_group - 8'd78;
    assign tt_cyan_x = tt_cyan_gx;
    assign tt_cyan_y = tt_cyan_gy;
    assign tt_cyan_byte = tt_cyan_mask(tt_cyan_y, tt_cyan_x[7:3]);
    assign tt_cyan_pixel =
        (x_group >= 8'd10) && (x_group < 8'd34) &&
        (y_group >= 8'd78) && (y_group < 8'd102) &&
        (tt_cyan_x < 8'd24) && (tt_cyan_y < 8'd24) &&
        tt_cyan_byte[3'd7 - tt_cyan_x[2:0]];

    wire [7:0] tt_x;
    wire [7:0] tt_y;
    wire [2:0] tt_band;
    wire tt_square;
    assign tt_x = x_group - 8'd10;
    assign tt_y = y_group - 8'd78;
    assign tt_band = tt_x[2:0] - tt_y[2:0];
    assign tt_square = (x_group >= 8'd10) && (x_group < 8'd34) &&
        (y_group >= 8'd78) && (y_group < 8'd102) &&
        !(((tt_x < 8'd2) || (tt_x >= 8'd22)) &&
          ((tt_y < 8'd2) || (tt_y >= 8'd22)));

    always @* begin
        red = 2'd2; green = 2'd3; blue = 2'd3;
        if (tt_square) begin
            case (tt_band)
                3'd0: begin red = 2'd0; green = 2'd0; blue = 2'd1; end
                3'd1: begin red = 2'd1; green = 2'd3; blue = 2'd3; end
                3'd2: begin red = 2'd3; green = 2'd3; blue = 2'd1; end
                3'd3: begin red = 2'd3; green = 2'd2; blue = 2'd2; end
                3'd4: begin red = 2'd3; green = 2'd2; blue = 2'd2; end
                3'd5: begin red = 2'd3; green = 2'd2; blue = 2'd2; end
                3'd6: begin red = 2'd3; green = 2'd3; blue = 2'd3; end
                3'd7: begin red = 2'd3; green = 2'd0; blue = 2'd2; end
                default: begin red = 2'd3; green = 2'd2; blue = 2'd2; end
            endcase
        end
        if (heading_pixel) begin
            red = 2'd0; green = 2'd0; blue = 2'd0;
        end
        if (rtu_pixel) begin
            red = 2'd0; green = 2'd0; blue = 2'd0;
        end
        if (rtu_subtitle_pixel) begin
            red = 2'd2; green = 2'd0; blue = 2'd2;
        end
        if (unilab_pixel) begin
            red = 2'd0; green = 2'd0; blue = 2'd0;
        end
        if (unilab_accent_pixel) begin
            red = 2'd2; green = 2'd1; blue = 2'd3;
        end
        if (vulkos_pixel) begin
            red = 2'd0; green = 2'd0; blue = 2'd0;
        end
        if (cdg_blue_pixel) begin
            red = 2'd0; green = 2'd1; blue = 2'd2;
        end
        if (cdg_cyan_pixel) begin
            red = 2'd0; green = 2'd2; blue = 2'd2;
        end
        if (cdg_chip_pixel) begin
            red = 2'd0; green = 2'd1; blue = 2'd2;
        end
        if (cdg_design_pixel) begin
            red = 2'd0; green = 2'd1; blue = 2'd2;
        end
        if (cdg_germany_pixel) begin
            red = 2'd0; green = 2'd2; blue = 2'd2;
        end
        if (tt_dark_pixel) begin
            red = 2'd0; green = 2'd0; blue = 2'd1;
        end
        if (tt_white_pixel) begin
            red = 2'd3; green = 2'd3; blue = 2'd3;
        end
        if (tt_pink_pixel) begin
            red = 2'd3; green = 2'd0; blue = 2'd2;
        end
        if (tt_cyan_pixel) begin
            red = 2'd1; green = 2'd3; blue = 2'd3;
        end
    end
endmodule

`default_nettype none

// Pixel-art sponsor marks, generated by design/generate_sponsors.py.
// Four-pixel groups and separate two-bit phases retain fine two-pixel detail.
// All declared data items and explicit Verilog constants are <= eight bits.
// This module only renders colour; the top level applies VGA blanking.
module lccc_sponsors_renderer (
    input wire [7:0] x_group,
    input wire [7:0] y_group,
    input wire [1:0] x_phase,
    input wire [1:0] y_phase,
    output reg [1:0] red,
    output reg [1:0] green,
    output reg [1:0] blue
);

    function [7:0] heading_mask;
        input [7:0] row;
        input [4:0] chunk;
        begin
            heading_mask = 8'h00;
            case (row)
                8'd0, 8'd1: begin
                    case (chunk)
                        5'd5: heading_mask = 8'h82;
                        default: heading_mask = 8'h00;
                    endcase
                end
                8'd2: begin
                    case (chunk)
                        5'd0: heading_mask = 8'hf1;
                        5'd1: heading_mask = 8'hc8;
                        5'd2: heading_mask = 8'h9c;
                        5'd3: heading_mask = 8'hb1;
                        5'd4: heading_mask = 8'hc6;
                        5'd5: heading_mask = 8'h82;
                        5'd6: heading_mask = 8'hc8;
                        5'd7: heading_mask = 8'h80;
                        default: heading_mask = 8'h00;
                    endcase
                end
                8'd3: begin
                    case (chunk)
                        5'd0: heading_mask = 8'h8a;
                        5'd1: heading_mask = 8'h28;
                        5'd2: heading_mask = 8'ha2;
                        5'd3: heading_mask = 8'hca;
                        5'd4: heading_mask = 8'h29;
                        5'd5: heading_mask = 8'h83;
                        5'd6: heading_mask = 8'h28;
                        5'd7: heading_mask = 8'h80;
                        default: heading_mask = 8'h00;
                    endcase
                end
                8'd4: begin
                    case (chunk)
                        5'd0: heading_mask = 8'h8a;
                        5'd1: heading_mask = 8'h2a;
                        5'd2: heading_mask = 8'hbe;
                        5'd3: heading_mask = 8'h83;
                        5'd4: heading_mask = 8'he8;
                        5'd5: heading_mask = 8'h82;
                        5'd6: heading_mask = 8'h28;
                        5'd7: heading_mask = 8'h80;
                        default: heading_mask = 8'h00;
                    endcase
                end
                8'd5: begin
                    case (chunk)
                        5'd0: heading_mask = 8'h8a;
                        5'd1: heading_mask = 8'h2a;
                        5'd2: heading_mask = 8'ha0;
                        5'd3: heading_mask = 8'h82;
                        5'd4: heading_mask = 8'h08;
                        5'd5: heading_mask = 8'h82;
                        5'd6: heading_mask = 8'h28;
                        5'd7: heading_mask = 8'h80;
                        default: heading_mask = 8'h00;
                    endcase
                end
                8'd6: begin
                    case (chunk)
                        5'd0: heading_mask = 8'hf1;
                        5'd1: heading_mask = 8'hc5;
                        5'd2: heading_mask = 8'h1c;
                        5'd3: heading_mask = 8'h81;
                        5'd4: heading_mask = 8'hc7;
                        5'd5: heading_mask = 8'h83;
                        5'd6: heading_mask = 8'hc7;
                        5'd7: heading_mask = 8'h80;
                        default: heading_mask = 8'h00;
                    endcase
                end
                8'd7: begin
                    case (chunk)
                        5'd0: heading_mask = 8'h80;
                        5'd7: heading_mask = 8'h80;
                        default: heading_mask = 8'h00;
                    endcase
                end
                8'd8: begin
                    case (chunk)
                        5'd0: heading_mask = 8'h80;
                        5'd6: heading_mask = 8'h07;
                        default: heading_mask = 8'h00;
                    endcase
                end
                default: heading_mask = 8'h00;
            endcase
        end
    endfunction

    function [7:0] analog_devices_mask;
        input [7:0] row;
        input [4:0] chunk;
        begin
            analog_devices_mask = 8'h00;
            case (row)
                8'd1, 8'd23, 8'd24: begin
                    case (chunk)
                        5'd0: analog_devices_mask = 8'hff;
                        5'd1: analog_devices_mask = 8'hff;
                        5'd2: analog_devices_mask = 8'hff;
                        default: analog_devices_mask = 8'h00;
                    endcase
                end
                8'd2: begin
                    case (chunk)
                        5'd0: analog_devices_mask = 8'hff;
                        5'd1: analog_devices_mask = 8'hff;
                        5'd2: analog_devices_mask = 8'hff;
                        5'd3: analog_devices_mask = 8'h03;
                        5'd4: analog_devices_mask = 8'h8c;
                        5'd5: analog_devices_mask = 8'h63;
                        5'd6: analog_devices_mask = 8'h8c;
                        5'd7: analog_devices_mask = 8'h07;
                        5'd8: analog_devices_mask = 8'hc7;
                        5'd9: analog_devices_mask = 8'he0;
                        default: analog_devices_mask = 8'h00;
                    endcase
                end
                8'd3: begin
                    case (chunk)
                        5'd0: analog_devices_mask = 8'hff;
                        5'd1: analog_devices_mask = 8'hff;
                        5'd2: analog_devices_mask = 8'hff;
                        5'd3: analog_devices_mask = 8'h07;
                        5'd4: analog_devices_mask = 8'hce;
                        5'd5: analog_devices_mask = 8'h67;
                        5'd6: analog_devices_mask = 8'hcc;
                        5'd7: analog_devices_mask = 8'h0f;
                        5'd8: analog_devices_mask = 8'hef;
                        5'd9: analog_devices_mask = 8'he0;
                        default: analog_devices_mask = 8'h00;
                    endcase
                end
                8'd4: begin
                    case (chunk)
                        5'd0: analog_devices_mask = 8'hff;
                        5'd1: analog_devices_mask = 8'hff;
                        5'd2: analog_devices_mask = 8'hff;
                        5'd3: analog_devices_mask = 8'h0c;
                        5'd4: analog_devices_mask = 8'h6e;
                        5'd5: analog_devices_mask = 8'h6c;
                        5'd6: analog_devices_mask = 8'h6c;
                        5'd7: analog_devices_mask = 8'h0c;
                        5'd8: analog_devices_mask = 8'h6c;
                        default: analog_devices_mask = 8'h00;
                    endcase
                end
                8'd5: begin
                    case (chunk)
                        5'd0: analog_devices_mask = 8'hfd;
                        5'd1: analog_devices_mask = 8'hff;
                        5'd2: analog_devices_mask = 8'hff;
                        5'd3: analog_devices_mask = 8'h0c;
                        5'd4: analog_devices_mask = 8'h6f;
                        5'd5: analog_devices_mask = 8'h6c;
                        5'd6: analog_devices_mask = 8'h6c;
                        5'd7: analog_devices_mask = 8'h0c;
                        5'd8: analog_devices_mask = 8'h6c;
                        default: analog_devices_mask = 8'h00;
                    endcase
                end
                8'd6: begin
                    case (chunk)
                        5'd0: analog_devices_mask = 8'hfc;
                        5'd1: analog_devices_mask = 8'h7f;
                        5'd2: analog_devices_mask = 8'hff;
                        5'd3: analog_devices_mask = 8'h0f;
                        5'd4: analog_devices_mask = 8'hed;
                        5'd5: analog_devices_mask = 8'hef;
                        5'd6: analog_devices_mask = 8'hec;
                        5'd7: analog_devices_mask = 8'h0c;
                        5'd8: analog_devices_mask = 8'h6d;
                        5'd9: analog_devices_mask = 8'he0;
                        default: analog_devices_mask = 8'h00;
                    endcase
                end
                8'd7: begin
                    case (chunk)
                        5'd0: analog_devices_mask = 8'hfc;
                        5'd1: analog_devices_mask = 8'h1f;
                        5'd2: analog_devices_mask = 8'hff;
                        5'd3: analog_devices_mask = 8'h0f;
                        5'd4: analog_devices_mask = 8'hec;
                        5'd5: analog_devices_mask = 8'hef;
                        5'd6: analog_devices_mask = 8'hec;
                        5'd7: analog_devices_mask = 8'h0c;
                        5'd8: analog_devices_mask = 8'h6d;
                        5'd9: analog_devices_mask = 8'he0;
                        default: analog_devices_mask = 8'h00;
                    endcase
                end
                8'd8: begin
                    case (chunk)
                        5'd0: analog_devices_mask = 8'hfc;
                        5'd1: analog_devices_mask = 8'h07;
                        5'd2: analog_devices_mask = 8'hff;
                        5'd3: analog_devices_mask = 8'h0c;
                        5'd4: analog_devices_mask = 8'h6c;
                        5'd5: analog_devices_mask = 8'hec;
                        5'd6: analog_devices_mask = 8'h6c;
                        5'd7: analog_devices_mask = 8'h0c;
                        5'd8: analog_devices_mask = 8'h6c;
                        5'd9: analog_devices_mask = 8'h60;
                        default: analog_devices_mask = 8'h00;
                    endcase
                end
                8'd9: begin
                    case (chunk)
                        5'd0: analog_devices_mask = 8'hfc;
                        5'd1: analog_devices_mask = 8'h03;
                        5'd2: analog_devices_mask = 8'hff;
                        5'd3: analog_devices_mask = 8'h0c;
                        5'd4: analog_devices_mask = 8'h6c;
                        5'd5: analog_devices_mask = 8'h6c;
                        5'd6: analog_devices_mask = 8'h6f;
                        5'd7: analog_devices_mask = 8'hef;
                        5'd8: analog_devices_mask = 8'hef;
                        5'd9: analog_devices_mask = 8'he0;
                        default: analog_devices_mask = 8'h00;
                    endcase
                end
                8'd10: begin
                    case (chunk)
                        5'd0: analog_devices_mask = 8'hfc;
                        5'd2: analog_devices_mask = 8'hff;
                        5'd3: analog_devices_mask = 8'h0c;
                        5'd4: analog_devices_mask = 8'h6c;
                        5'd5: analog_devices_mask = 8'h6c;
                        5'd6: analog_devices_mask = 8'h6f;
                        5'd7: analog_devices_mask = 8'he7;
                        5'd8: analog_devices_mask = 8'hc7;
                        5'd9: analog_devices_mask = 8'he0;
                        default: analog_devices_mask = 8'h00;
                    endcase
                end
                8'd11, 8'd13: begin
                    case (chunk)
                        5'd0: analog_devices_mask = 8'hfc;
                        5'd2: analog_devices_mask = 8'h3f;
                        default: analog_devices_mask = 8'h00;
                    endcase
                end
                8'd12: begin
                    case (chunk)
                        5'd0: analog_devices_mask = 8'hfc;
                        5'd2: analog_devices_mask = 8'h0f;
                        default: analog_devices_mask = 8'h00;
                    endcase
                end
                8'd14: begin
                    case (chunk)
                        5'd0: analog_devices_mask = 8'hfc;
                        5'd2: analog_devices_mask = 8'h7f;
                        5'd3: analog_devices_mask = 8'h0f;
                        5'd4: analog_devices_mask = 8'h8f;
                        5'd5: analog_devices_mask = 8'hec;
                        5'd6: analog_devices_mask = 8'h6c;
                        5'd7: analog_devices_mask = 8'hfd;
                        5'd8: analog_devices_mask = 8'hfc;
                        5'd9: analog_devices_mask = 8'hfc;
                        default: analog_devices_mask = 8'h00;
                    endcase
                end
                8'd15: begin
                    case (chunk)
                        5'd0: analog_devices_mask = 8'hfc;
                        5'd1: analog_devices_mask = 8'h01;
                        5'd2: analog_devices_mask = 8'hff;
                        5'd3: analog_devices_mask = 8'h0f;
                        5'd4: analog_devices_mask = 8'hcf;
                        5'd5: analog_devices_mask = 8'hec;
                        5'd6: analog_devices_mask = 8'h6d;
                        5'd7: analog_devices_mask = 8'hfd;
                        5'd8: analog_devices_mask = 8'hfd;
                        5'd9: analog_devices_mask = 8'hfc;
                        default: analog_devices_mask = 8'h00;
                    endcase
                end
                8'd16: begin
                    case (chunk)
                        5'd0: analog_devices_mask = 8'hfc;
                        5'd1: analog_devices_mask = 8'h07;
                        5'd2: analog_devices_mask = 8'hff;
                        5'd3: analog_devices_mask = 8'h0c;
                        5'd4: analog_devices_mask = 8'h6c;
                        5'd5: analog_devices_mask = 8'h0c;
                        5'd6: analog_devices_mask = 8'h6d;
                        5'd7: analog_devices_mask = 8'h81;
                        5'd8: analog_devices_mask = 8'h81;
                        5'd9: analog_devices_mask = 8'h80;
                        default: analog_devices_mask = 8'h00;
                    endcase
                end
                8'd17: begin
                    case (chunk)
                        5'd0: analog_devices_mask = 8'hfc;
                        5'd1: analog_devices_mask = 8'h0f;
                        5'd2: analog_devices_mask = 8'hff;
                        5'd3: analog_devices_mask = 8'h0c;
                        5'd4: analog_devices_mask = 8'h6c;
                        5'd5: analog_devices_mask = 8'h0c;
                        5'd6: analog_devices_mask = 8'h6d;
                        5'd7: analog_devices_mask = 8'h81;
                        5'd8: analog_devices_mask = 8'h81;
                        5'd9: analog_devices_mask = 8'h80;
                        default: analog_devices_mask = 8'h00;
                    endcase
                end
                8'd18: begin
                    case (chunk)
                        5'd0: analog_devices_mask = 8'hfc;
                        5'd1: analog_devices_mask = 8'h3f;
                        5'd2: analog_devices_mask = 8'hff;
                        5'd3: analog_devices_mask = 8'h0c;
                        5'd4: analog_devices_mask = 8'h6f;
                        5'd5: analog_devices_mask = 8'hcc;
                        5'd6: analog_devices_mask = 8'h6d;
                        5'd7: analog_devices_mask = 8'h81;
                        5'd8: analog_devices_mask = 8'hf8;
                        5'd9: analog_devices_mask = 8'hf8;
                        default: analog_devices_mask = 8'h00;
                    endcase
                end
                8'd19: begin
                    case (chunk)
                        5'd0: analog_devices_mask = 8'hfc;
                        5'd1: analog_devices_mask = 8'h7f;
                        5'd2: analog_devices_mask = 8'hff;
                        5'd3: analog_devices_mask = 8'h0c;
                        5'd4: analog_devices_mask = 8'h6f;
                        5'd5: analog_devices_mask = 8'hc6;
                        5'd6: analog_devices_mask = 8'hcd;
                        5'd7: analog_devices_mask = 8'h81;
                        5'd8: analog_devices_mask = 8'hf8;
                        5'd9: analog_devices_mask = 8'h0c;
                        default: analog_devices_mask = 8'h00;
                    endcase
                end
                8'd20: begin
                    case (chunk)
                        5'd0: analog_devices_mask = 8'hfd;
                        5'd1: analog_devices_mask = 8'hff;
                        5'd2: analog_devices_mask = 8'hff;
                        5'd3: analog_devices_mask = 8'h0c;
                        5'd4: analog_devices_mask = 8'h6c;
                        5'd5: analog_devices_mask = 8'h06;
                        5'd6: analog_devices_mask = 8'hcd;
                        5'd7: analog_devices_mask = 8'h81;
                        5'd8: analog_devices_mask = 8'h80;
                        5'd9: analog_devices_mask = 8'h0c;
                        default: analog_devices_mask = 8'h00;
                    endcase
                end
                8'd21: begin
                    case (chunk)
                        5'd0: analog_devices_mask = 8'hff;
                        5'd1: analog_devices_mask = 8'hff;
                        5'd2: analog_devices_mask = 8'hff;
                        5'd3: analog_devices_mask = 8'h0f;
                        5'd4: analog_devices_mask = 8'hcf;
                        5'd5: analog_devices_mask = 8'he3;
                        5'd6: analog_devices_mask = 8'h8d;
                        5'd7: analog_devices_mask = 8'hfd;
                        5'd8: analog_devices_mask = 8'hfd;
                        5'd9: analog_devices_mask = 8'hfc;
                        default: analog_devices_mask = 8'h00;
                    endcase
                end
                8'd22: begin
                    case (chunk)
                        5'd0: analog_devices_mask = 8'hff;
                        5'd1: analog_devices_mask = 8'hff;
                        5'd2: analog_devices_mask = 8'hff;
                        5'd3: analog_devices_mask = 8'h0f;
                        5'd4: analog_devices_mask = 8'h8f;
                        5'd5: analog_devices_mask = 8'he1;
                        5'd6: analog_devices_mask = 8'h0c;
                        5'd7: analog_devices_mask = 8'hfd;
                        5'd8: analog_devices_mask = 8'hfd;
                        5'd9: analog_devices_mask = 8'hf8;
                        default: analog_devices_mask = 8'h00;
                    endcase
                end
                default: analog_devices_mask = 8'h00;
            endcase
        end
    endfunction

    function [7:0] synopsys_mask;
        input [7:0] row;
        input [4:0] chunk;
        begin
            synopsys_mask = 8'h00;
            case (row)
                8'd0: begin
                    case (chunk)
                        5'd0: synopsys_mask = 8'h7a;
                        5'd1: synopsys_mask = 8'h28;
                        5'd2: synopsys_mask = 8'h9c;
                        5'd3: synopsys_mask = 8'hf1;
                        5'd4: synopsys_mask = 8'he8;
                        5'd5: synopsys_mask = 8'h9e;
                        default: synopsys_mask = 8'h00;
                    endcase
                end
                8'd1: begin
                    case (chunk)
                        5'd0: synopsys_mask = 8'h82;
                        5'd1: synopsys_mask = 8'h2c;
                        5'd2: synopsys_mask = 8'ha2;
                        5'd3: synopsys_mask = 8'h8a;
                        5'd4: synopsys_mask = 8'h08;
                        5'd5: synopsys_mask = 8'ha0;
                        default: synopsys_mask = 8'h00;
                    endcase
                end
                8'd2: begin
                    case (chunk)
                        5'd0: synopsys_mask = 8'h81;
                        5'd1: synopsys_mask = 8'h4a;
                        5'd2: synopsys_mask = 8'ha2;
                        5'd3: synopsys_mask = 8'h8a;
                        5'd4: synopsys_mask = 8'h05;
                        5'd5: synopsys_mask = 8'h20;
                        default: synopsys_mask = 8'h00;
                    endcase
                end
                8'd3: begin
                    case (chunk)
                        5'd0: synopsys_mask = 8'h70;
                        5'd1: synopsys_mask = 8'h89;
                        5'd2: synopsys_mask = 8'ha2;
                        5'd3: synopsys_mask = 8'hf1;
                        5'd4: synopsys_mask = 8'hc2;
                        5'd5: synopsys_mask = 8'h1c;
                        default: synopsys_mask = 8'h00;
                    endcase
                end
                8'd4, 8'd5: begin
                    case (chunk)
                        5'd0: synopsys_mask = 8'h08;
                        5'd1: synopsys_mask = 8'h88;
                        5'd2: synopsys_mask = 8'ha2;
                        5'd3: synopsys_mask = 8'h80;
                        5'd4: synopsys_mask = 8'h22;
                        5'd5: synopsys_mask = 8'h02;
                        default: synopsys_mask = 8'h00;
                    endcase
                end
                8'd6: begin
                    case (chunk)
                        5'd0: synopsys_mask = 8'hf0;
                        5'd1: synopsys_mask = 8'h88;
                        5'd2: synopsys_mask = 8'h9c;
                        5'd3: synopsys_mask = 8'h83;
                        5'd4: synopsys_mask = 8'hc2;
                        5'd5: synopsys_mask = 8'h3c;
                        default: synopsys_mask = 8'h00;
                    endcase
                end
                default: synopsys_mask = 8'h00;
            endcase
        end
    endfunction

    function [7:0] riga_mask;
        input [7:0] row;
        input [4:0] chunk;
        begin
            riga_mask = 8'h00;
            case (row)
                8'd0, 8'd1: begin
                    case (chunk)
                        5'd1: riga_mask = 8'h20;
                        default: riga_mask = 8'h00;
                    endcase
                end
                8'd2: begin
                    case (chunk)
                        5'd1: riga_mask = 8'hf8;
                        default: riga_mask = 8'h00;
                    endcase
                end
                8'd3: begin
                    case (chunk)
                        5'd0: riga_mask = 8'h08;
                        5'd1: riga_mask = 8'h21;
                        default: riga_mask = 8'h00;
                    endcase
                end
                8'd4: begin
                    case (chunk)
                        5'd0: riga_mask = 8'h14;
                        5'd1: riga_mask = 8'h20;
                        5'd2: riga_mask = 8'h80;
                        default: riga_mask = 8'h00;
                    endcase
                end
                8'd5: begin
                    case (chunk)
                        5'd0: riga_mask = 8'h28;
                        5'd1: riga_mask = 8'h21;
                        5'd2: riga_mask = 8'h40;
                        default: riga_mask = 8'h00;
                    endcase
                end
                8'd6: begin
                    case (chunk)
                        5'd0: riga_mask = 8'h54;
                        5'd1: riga_mask = 8'h02;
                        5'd2: riga_mask = 8'h20;
                        default: riga_mask = 8'h00;
                    endcase
                end
                8'd7: begin
                    case (chunk)
                        5'd0: riga_mask = 8'h8a;
                        5'd1: riga_mask = 8'h05;
                        5'd2: riga_mask = 8'h40;
                        default: riga_mask = 8'h00;
                    endcase
                end
                8'd8: begin
                    case (chunk)
                        5'd0: riga_mask = 8'h51;
                        5'd1: riga_mask = 8'h08;
                        5'd2: riga_mask = 8'ha3;
                        5'd3: riga_mask = 8'hce;
                        5'd4: riga_mask = 8'h79;
                        5'd5: riga_mask = 8'hc0;
                        default: riga_mask = 8'h00;
                    endcase
                end
                8'd9: begin
                    case (chunk)
                        5'd0: riga_mask = 8'h20;
                        5'd1: riga_mask = 8'h90;
                        5'd2: riga_mask = 8'h42;
                        5'd3: riga_mask = 8'h24;
                        5'd4: riga_mask = 8'h82;
                        5'd5: riga_mask = 8'h20;
                        default: riga_mask = 8'h00;
                    endcase
                end
                8'd10: begin
                    case (chunk)
                        5'd1: riga_mask = 8'h60;
                        5'd2: riga_mask = 8'h02;
                        5'd3: riga_mask = 8'h24;
                        5'd4: riga_mask = 8'h82;
                        5'd5: riga_mask = 8'h20;
                        default: riga_mask = 8'h00;
                    endcase
                end
                8'd11: begin
                    case (chunk)
                        5'd1: riga_mask = 8'h60;
                        5'd2: riga_mask = 8'h03;
                        5'd3: riga_mask = 8'hc4;
                        5'd4: riga_mask = 8'hbb;
                        5'd5: riga_mask = 8'he0;
                        default: riga_mask = 8'h00;
                    endcase
                end
                8'd12: begin
                    case (chunk)
                        5'd1: riga_mask = 8'h93;
                        5'd2: riga_mask = 8'h82;
                        5'd3: riga_mask = 8'h84;
                        5'd4: riga_mask = 8'h8a;
                        5'd5: riga_mask = 8'h20;
                        default: riga_mask = 8'h00;
                    endcase
                end
                8'd13: begin
                    case (chunk)
                        5'd0: riga_mask = 8'h41;
                        5'd1: riga_mask = 8'h0c;
                        5'd2: riga_mask = 8'hc2;
                        5'd3: riga_mask = 8'h44;
                        5'd4: riga_mask = 8'h8a;
                        5'd5: riga_mask = 8'h20;
                        default: riga_mask = 8'h00;
                    endcase
                end
                8'd14: begin
                    case (chunk)
                        5'd0: riga_mask = 8'h3e;
                        5'd1: riga_mask = 8'h04;
                        5'd2: riga_mask = 8'h42;
                        5'd3: riga_mask = 8'h2e;
                        5'd4: riga_mask = 8'h7a;
                        5'd5: riga_mask = 8'h20;
                        default: riga_mask = 8'h00;
                    endcase
                end
                8'd15: begin
                    case (chunk)
                        5'd0: riga_mask = 8'h26;
                        5'd1: riga_mask = 8'h04;
                        5'd2: riga_mask = 8'h40;
                        default: riga_mask = 8'h00;
                    endcase
                end
                8'd16: begin
                    case (chunk)
                        5'd0: riga_mask = 8'h2a;
                        5'd1: riga_mask = 8'h1c;
                        5'd2: riga_mask = 8'h70;
                        default: riga_mask = 8'h00;
                    endcase
                end
                8'd17: begin
                    case (chunk)
                        5'd0: riga_mask = 8'h22;
                        5'd1: riga_mask = 8'h10;
                        5'd2: riga_mask = 8'h10;
                        default: riga_mask = 8'h00;
                    endcase
                end
                8'd18: begin
                    case (chunk)
                        5'd0: riga_mask = 8'h3e;
                        5'd1: riga_mask = 8'h1b;
                        5'd2: riga_mask = 8'hb0;
                        default: riga_mask = 8'h00;
                    endcase
                end
                8'd19: begin
                    case (chunk)
                        5'd0: riga_mask = 8'h41;
                        5'd1: riga_mask = 8'h0e;
                        5'd2: riga_mask = 8'he0;
                        default: riga_mask = 8'h00;
                    endcase
                end
                default: riga_mask = 8'h00;
            endcase
        end
    endfunction

    function [7:0] saf_bg_mask;
        input [7:0] row;
        input [4:0] chunk;
        begin
            saf_bg_mask = 8'h00;
            case (row)
                8'd0, 8'd1, 8'd2, 8'd3, 8'd4, 8'd5, 8'd6, 8'd7, 8'd8, 8'd9, 8'd10, 8'd11, 8'd12, 8'd13, 8'd14, 8'd15, 8'd16, 8'd17, 8'd18, 8'd19: begin
                    case (chunk)
                        5'd0: saf_bg_mask = 8'hff;
                        5'd1: saf_bg_mask = 8'hff;
                        5'd2: saf_bg_mask = 8'hf0;
                        default: saf_bg_mask = 8'h00;
                    endcase
                end
                default: saf_bg_mask = 8'h00;
            endcase
        end
    endfunction

    function [7:0] saf_white_mask;
        input [7:0] row;
        input [4:0] chunk;
        begin
            saf_white_mask = 8'h00;
            case (row)
                8'd4: begin
                    case (chunk)
                        5'd1: saf_white_mask = 8'h60;
                        default: saf_white_mask = 8'h00;
                    endcase
                end
                8'd5: begin
                    case (chunk)
                        5'd0: saf_white_mask = 8'h2a;
                        5'd1: saf_white_mask = 8'h62;
                        5'd2: saf_white_mask = 8'ha0;
                        default: saf_white_mask = 8'h00;
                    endcase
                end
                8'd6, 8'd7: begin
                    case (chunk)
                        5'd0: saf_white_mask = 8'h2a;
                        5'd1: saf_white_mask = 8'hf2;
                        5'd2: saf_white_mask = 8'ha0;
                        default: saf_white_mask = 8'h00;
                    endcase
                end
                8'd8: begin
                    case (chunk)
                        5'd0: saf_white_mask = 8'h01;
                        5'd1: saf_white_mask = 8'h98;
                        default: saf_white_mask = 8'h00;
                    endcase
                end
                8'd9: begin
                    case (chunk)
                        5'd0: saf_white_mask = 8'h3d;
                        5'd1: saf_white_mask = 8'h9b;
                        5'd2: saf_white_mask = 8'hc0;
                        default: saf_white_mask = 8'h00;
                    endcase
                end
                8'd10: begin
                    case (chunk)
                        5'd0: saf_white_mask = 8'h31;
                        5'd1: saf_white_mask = 8'hfb;
                        5'd2: saf_white_mask = 8'hc0;
                        default: saf_white_mask = 8'h00;
                    endcase
                end
                8'd11: begin
                    case (chunk)
                        5'd0: saf_white_mask = 8'h31;
                        5'd1: saf_white_mask = 8'hfb;
                        default: saf_white_mask = 8'h00;
                    endcase
                end
                8'd12: begin
                    case (chunk)
                        5'd0: saf_white_mask = 8'h3d;
                        5'd1: saf_white_mask = 8'h9b;
                        5'd2: saf_white_mask = 8'h80;
                        default: saf_white_mask = 8'h00;
                    endcase
                end
                8'd13: begin
                    case (chunk)
                        5'd0: saf_white_mask = 8'h0d;
                        5'd1: saf_white_mask = 8'h9b;
                        5'd2: saf_white_mask = 8'h80;
                        default: saf_white_mask = 8'h00;
                    endcase
                end
                8'd14: begin
                    case (chunk)
                        5'd0: saf_white_mask = 8'h0d;
                        5'd1: saf_white_mask = 8'h9b;
                        default: saf_white_mask = 8'h00;
                    endcase
                end
                8'd15: begin
                    case (chunk)
                        5'd0: saf_white_mask = 8'h3d;
                        5'd1: saf_white_mask = 8'h9b;
                        default: saf_white_mask = 8'h00;
                    endcase
                end
                default: saf_white_mask = 8'h00;
            endcase
        end
    endfunction

    function [7:0] lmt_mask;
        input [7:0] row;
        input [4:0] chunk;
        begin
            lmt_mask = 8'h00;
            case (row)
                8'd1, 8'd2, 8'd3: begin
                    case (chunk)
                        5'd0: lmt_mask = 8'he0;
                        5'd2: lmt_mask = 8'h07;
                        default: lmt_mask = 8'h00;
                    endcase
                end
                8'd4: begin
                    case (chunk)
                        5'd0: lmt_mask = 8'he0;
                        5'd1: lmt_mask = 8'hc6;
                        5'd2: lmt_mask = 8'h07;
                        default: lmt_mask = 8'h00;
                    endcase
                end
                8'd5, 8'd6: begin
                    case (chunk)
                        5'd0: lmt_mask = 8'he7;
                        5'd1: lmt_mask = 8'hff;
                        5'd2: lmt_mask = 8'hdf;
                        5'd3: lmt_mask = 8'he0;
                        default: lmt_mask = 8'h00;
                    endcase
                end
                8'd7: begin
                    case (chunk)
                        5'd0: lmt_mask = 8'he7;
                        5'd1: lmt_mask = 8'h39;
                        5'd2: lmt_mask = 8'hdf;
                        5'd3: lmt_mask = 8'he0;
                        default: lmt_mask = 8'h00;
                    endcase
                end
                8'd8, 8'd9, 8'd10, 8'd11, 8'd12: begin
                    case (chunk)
                        5'd0: lmt_mask = 8'he7;
                        5'd1: lmt_mask = 8'h39;
                        5'd2: lmt_mask = 8'hc7;
                        default: lmt_mask = 8'h00;
                    endcase
                end
                8'd13, 8'd14: begin
                    case (chunk)
                        5'd0: lmt_mask = 8'he7;
                        5'd1: lmt_mask = 8'h39;
                        5'd2: lmt_mask = 8'hc3;
                        5'd3: lmt_mask = 8'he0;
                        default: lmt_mask = 8'h00;
                    endcase
                end
                default: lmt_mask = 8'h00;
            endcase
        end
    endfunction

    function [7:0] lmt_group_mask;
        input [7:0] row;
        input [4:0] chunk;
        begin
            lmt_group_mask = 8'h00;
            case (row)
                8'd1: begin
                    case (chunk)
                        5'd0: lmt_group_mask = 8'h78;
                        5'd3: lmt_group_mask = 8'hf0;
                        default: lmt_group_mask = 8'h00;
                    endcase
                end
                8'd2: begin
                    case (chunk)
                        5'd0: lmt_group_mask = 8'h8a;
                        5'd1: lmt_group_mask = 8'hc7;
                        5'd2: lmt_group_mask = 8'h22;
                        5'd3: lmt_group_mask = 8'h88;
                        default: lmt_group_mask = 8'h00;
                    endcase
                end
                8'd3: begin
                    case (chunk)
                        5'd0: lmt_group_mask = 8'h8b;
                        5'd1: lmt_group_mask = 8'h28;
                        5'd2: lmt_group_mask = 8'ha2;
                        5'd3: lmt_group_mask = 8'h88;
                        default: lmt_group_mask = 8'h00;
                    endcase
                end
                8'd4: begin
                    case (chunk)
                        5'd0: lmt_group_mask = 8'h7a;
                        5'd1: lmt_group_mask = 8'h08;
                        5'd2: lmt_group_mask = 8'ha2;
                        5'd3: lmt_group_mask = 8'hf0;
                        default: lmt_group_mask = 8'h00;
                    endcase
                end
                8'd5: begin
                    case (chunk)
                        5'd0: lmt_group_mask = 8'h0a;
                        5'd1: lmt_group_mask = 8'h08;
                        5'd2: lmt_group_mask = 8'ha6;
                        5'd3: lmt_group_mask = 8'h80;
                        default: lmt_group_mask = 8'h00;
                    endcase
                end
                8'd6: begin
                    case (chunk)
                        5'd0: lmt_group_mask = 8'h72;
                        5'd1: lmt_group_mask = 8'h07;
                        5'd2: lmt_group_mask = 8'h1a;
                        5'd3: lmt_group_mask = 8'h80;
                        default: lmt_group_mask = 8'h00;
                    endcase
                end
                default: lmt_group_mask = 8'h00;
            endcase
        end
    endfunction

    function [7:0] lmt_orange_mask;
        input [7:0] row;
        input [4:0] chunk;
        begin
            lmt_orange_mask = 8'h00;
            case (row)
                8'd2: begin
                    case (chunk)
                        5'd0: lmt_orange_mask = 8'h03;
                        default: lmt_orange_mask = 8'h00;
                    endcase
                end
                8'd3, 8'd4: begin
                    case (chunk)
                        5'd0: lmt_orange_mask = 8'h04;
                        5'd1: lmt_orange_mask = 8'h80;
                        default: lmt_orange_mask = 8'h00;
                    endcase
                end
                8'd5: begin
                    case (chunk)
                        5'd0: lmt_orange_mask = 8'h08;
                        5'd1: lmt_orange_mask = 8'h40;
                        default: lmt_orange_mask = 8'h00;
                    endcase
                end
                8'd6, 8'd7: begin
                    case (chunk)
                        5'd0: lmt_orange_mask = 8'h08;
                        5'd1: lmt_orange_mask = 8'h20;
                        default: lmt_orange_mask = 8'h00;
                    endcase
                end
                8'd8: begin
                    case (chunk)
                        5'd0: lmt_orange_mask = 8'h08;
                        5'd1: lmt_orange_mask = 8'h10;
                        default: lmt_orange_mask = 8'h00;
                    endcase
                end
                8'd9: begin
                    case (chunk)
                        5'd0: lmt_orange_mask = 8'h10;
                        5'd1: lmt_orange_mask = 8'h08;
                        5'd2: lmt_orange_mask = 8'h40;
                        default: lmt_orange_mask = 8'h00;
                    endcase
                end
                8'd10: begin
                    case (chunk)
                        5'd0: lmt_orange_mask = 8'h10;
                        5'd1: lmt_orange_mask = 8'h09;
                        5'd2: lmt_orange_mask = 8'ha0;
                        default: lmt_orange_mask = 8'h00;
                    endcase
                end
                8'd11: begin
                    case (chunk)
                        5'd0: lmt_orange_mask = 8'h10;
                        5'd1: lmt_orange_mask = 8'h06;
                        5'd2: lmt_orange_mask = 8'h20;
                        default: lmt_orange_mask = 8'h00;
                    endcase
                end
                8'd12: begin
                    case (chunk)
                        5'd0: lmt_orange_mask = 8'h20;
                        5'd1: lmt_orange_mask = 8'h1c;
                        5'd2: lmt_orange_mask = 8'h10;
                        default: lmt_orange_mask = 8'h00;
                    endcase
                end
                8'd13: begin
                    case (chunk)
                        5'd0: lmt_orange_mask = 8'h20;
                        5'd1: lmt_orange_mask = 8'h62;
                        5'd2: lmt_orange_mask = 8'h10;
                        default: lmt_orange_mask = 8'h00;
                    endcase
                end
                8'd14: begin
                    case (chunk)
                        5'd0: lmt_orange_mask = 8'h21;
                        5'd1: lmt_orange_mask = 8'h81;
                        5'd2: lmt_orange_mask = 8'h08;
                        default: lmt_orange_mask = 8'h00;
                    endcase
                end
                8'd15: begin
                    case (chunk)
                        5'd0: lmt_orange_mask = 8'h26;
                        5'd1: lmt_orange_mask = 8'h01;
                        5'd2: lmt_orange_mask = 8'h08;
                        default: lmt_orange_mask = 8'h00;
                    endcase
                end
                8'd16: begin
                    case (chunk)
                        5'd0: lmt_orange_mask = 8'h48;
                        5'd2: lmt_orange_mask = 8'hb0;
                        default: lmt_orange_mask = 8'h00;
                    endcase
                end
                8'd17: begin
                    case (chunk)
                        5'd0: lmt_orange_mask = 8'h70;
                        5'd1: lmt_orange_mask = 8'h01;
                        5'd2: lmt_orange_mask = 8'hc0;
                        default: lmt_orange_mask = 8'h00;
                    endcase
                end
                8'd18: begin
                    case (chunk)
                        5'd0: lmt_orange_mask = 8'h0f;
                        5'd1: lmt_orange_mask = 8'hc7;
                        default: lmt_orange_mask = 8'h00;
                    endcase
                end
                8'd19: begin
                    case (chunk)
                        5'd1: lmt_orange_mask = 8'h3c;
                        default: lmt_orange_mask = 8'h00;
                    endcase
                end
                default: lmt_orange_mask = 8'h00;
            endcase
        end
    endfunction

    function [7:0] lmt_red_mask;
        input [7:0] row;
        input [4:0] chunk;
        begin
            lmt_red_mask = 8'h00;
            case (row)
                8'd1: begin
                    case (chunk)
                        5'd2: lmt_red_mask = 8'hc0;
                        default: lmt_red_mask = 8'h00;
                    endcase
                end
                8'd2: begin
                    case (chunk)
                        5'd1: lmt_red_mask = 8'h03;
                        5'd2: lmt_red_mask = 8'h30;
                        default: lmt_red_mask = 8'h00;
                    endcase
                end
                8'd3: begin
                    case (chunk)
                        5'd1: lmt_red_mask = 8'h04;
                        5'd2: lmt_red_mask = 8'h0c;
                        default: lmt_red_mask = 8'h00;
                    endcase
                end
                8'd4: begin
                    case (chunk)
                        5'd1: lmt_red_mask = 8'h04;
                        5'd2: lmt_red_mask = 8'h03;
                        default: lmt_red_mask = 8'h00;
                    endcase
                end
                8'd5: begin
                    case (chunk)
                        5'd1: lmt_red_mask = 8'h04;
                        5'd3: lmt_red_mask = 8'hc0;
                        default: lmt_red_mask = 8'h00;
                    endcase
                end
                8'd6: begin
                    case (chunk)
                        5'd1: lmt_red_mask = 8'h04;
                        5'd3: lmt_red_mask = 8'h40;
                        default: lmt_red_mask = 8'h00;
                    endcase
                end
                8'd7: begin
                    case (chunk)
                        5'd1: lmt_red_mask = 8'h04;
                        5'd2: lmt_red_mask = 8'h3f;
                        5'd3: lmt_red_mask = 8'hf0;
                        default: lmt_red_mask = 8'h00;
                    endcase
                end
                8'd8: begin
                    case (chunk)
                        5'd1: lmt_red_mask = 8'h04;
                        5'd2: lmt_red_mask = 8'h20;
                        5'd3: lmt_red_mask = 8'h30;
                        default: lmt_red_mask = 8'h00;
                    endcase
                end
                8'd9: begin
                    case (chunk)
                        5'd1: lmt_red_mask = 8'h04;
                        5'd2: lmt_red_mask = 8'h20;
                        5'd3: lmt_red_mask = 8'h28;
                        default: lmt_red_mask = 8'h00;
                    endcase
                end
                8'd10: begin
                    case (chunk)
                        5'd1: lmt_red_mask = 8'h04;
                        5'd2: lmt_red_mask = 8'h20;
                        5'd3: lmt_red_mask = 8'h48;
                        default: lmt_red_mask = 8'h00;
                    endcase
                end
                8'd11: begin
                    case (chunk)
                        5'd1: lmt_red_mask = 8'h04;
                        5'd2: lmt_red_mask = 8'h40;
                        5'd3: lmt_red_mask = 8'h84;
                        default: lmt_red_mask = 8'h00;
                    endcase
                end
                8'd12: begin
                    case (chunk)
                        5'd1: lmt_red_mask = 8'h04;
                        5'd2: lmt_red_mask = 8'h41;
                        5'd3: lmt_red_mask = 8'h04;
                        default: lmt_red_mask = 8'h00;
                    endcase
                end
                8'd13: begin
                    case (chunk)
                        5'd1: lmt_red_mask = 8'h04;
                        5'd2: lmt_red_mask = 8'h42;
                        5'd3: lmt_red_mask = 8'h02;
                        default: lmt_red_mask = 8'h00;
                    endcase
                end
                8'd14: begin
                    case (chunk)
                        5'd1: lmt_red_mask = 8'h04;
                        5'd2: lmt_red_mask = 8'h44;
                        5'd3: lmt_red_mask = 8'h02;
                        default: lmt_red_mask = 8'h00;
                    endcase
                end
                8'd15: begin
                    case (chunk)
                        5'd1: lmt_red_mask = 8'h04;
                        5'd2: lmt_red_mask = 8'h48;
                        5'd3: lmt_red_mask = 8'h02;
                        default: lmt_red_mask = 8'h00;
                    endcase
                end
                8'd16: begin
                    case (chunk)
                        5'd1: lmt_red_mask = 8'h04;
                        5'd2: lmt_red_mask = 8'h50;
                        5'd3: lmt_red_mask = 8'h02;
                        default: lmt_red_mask = 8'h00;
                    endcase
                end
                8'd17: begin
                    case (chunk)
                        5'd1: lmt_red_mask = 8'h07;
                        5'd2: lmt_red_mask = 8'he0;
                        5'd3: lmt_red_mask = 8'h04;
                        default: lmt_red_mask = 8'h00;
                    endcase
                end
                8'd18: begin
                    case (chunk)
                        5'd2: lmt_red_mask = 8'h30;
                        5'd3: lmt_red_mask = 8'h04;
                        default: lmt_red_mask = 8'h00;
                    endcase
                end
                8'd19: begin
                    case (chunk)
                        5'd2: lmt_red_mask = 8'h0c;
                        5'd3: lmt_red_mask = 8'h04;
                        default: lmt_red_mask = 8'h00;
                    endcase
                end
                8'd20: begin
                    case (chunk)
                        5'd2: lmt_red_mask = 8'h02;
                        5'd3: lmt_red_mask = 8'h04;
                        default: lmt_red_mask = 8'h00;
                    endcase
                end
                8'd21: begin
                    case (chunk)
                        5'd2: lmt_red_mask = 8'h01;
                        5'd3: lmt_red_mask = 8'h98;
                        default: lmt_red_mask = 8'h00;
                    endcase
                end
                8'd22: begin
                    case (chunk)
                        5'd3: lmt_red_mask = 8'h60;
                        default: lmt_red_mask = 8'h00;
                    endcase
                end
                default: lmt_red_mask = 8'h00;
            endcase
        end
    endfunction

    function [7:0] eraser_mask;
        input [7:0] row;
        input [4:0] chunk;
        begin
            eraser_mask = 8'h00;
            case (row)
                8'd0, 8'd1: begin
                    case (chunk)
                        5'd0: eraser_mask = 8'hff;
                        5'd1: eraser_mask = 8'hfb;
                        5'd2: eraser_mask = 8'hff;
                        5'd3: eraser_mask = 8'hef;
                        5'd4: eraser_mask = 8'hff;
                        5'd5: eraser_mask = 8'hbf;
                        5'd6: eraser_mask = 8'hfe;
                        5'd7: eraser_mask = 8'hff;
                        5'd8: eraser_mask = 8'hfb;
                        5'd9: eraser_mask = 8'hff;
                        5'd10: eraser_mask = 8'he0;
                        default: eraser_mask = 8'h00;
                    endcase
                end
                8'd2, 8'd3: begin
                    case (chunk)
                        5'd0: eraser_mask = 8'hc0;
                        5'd1: eraser_mask = 8'h1b;
                        5'd4: eraser_mask = 8'h01;
                        5'd5: eraser_mask = 8'hb0;
                        5'd7: eraser_mask = 8'hc0;
                        5'd8: eraser_mask = 8'h1b;
                        default: eraser_mask = 8'h00;
                    endcase
                end
                8'd4, 8'd5, 8'd8, 8'd9: begin
                    case (chunk)
                        5'd0: eraser_mask = 8'hff;
                        5'd1: eraser_mask = 8'hfb;
                        5'd3: eraser_mask = 8'h0f;
                        5'd4: eraser_mask = 8'hff;
                        5'd5: eraser_mask = 8'hbf;
                        5'd6: eraser_mask = 8'hfe;
                        5'd7: eraser_mask = 8'hff;
                        5'd8: eraser_mask = 8'hfb;
                        default: eraser_mask = 8'h00;
                    endcase
                end
                8'd6, 8'd7: begin
                    case (chunk)
                        5'd0: eraser_mask = 8'hc0;
                        5'd1: eraser_mask = 8'h03;
                        5'd3: eraser_mask = 8'h0c;
                        5'd4: eraser_mask = 8'h01;
                        5'd5: eraser_mask = 8'h80;
                        5'd6: eraser_mask = 8'h06;
                        5'd7: eraser_mask = 8'hc0;
                        5'd8: eraser_mask = 8'h03;
                        default: eraser_mask = 8'h00;
                    endcase
                end
                default: eraser_mask = 8'h00;
            endcase
        end
    endfunction

    function [7:0] riviera_navy_mask;
        input [7:0] row;
        input [4:0] chunk;
        begin
            riviera_navy_mask = 8'h00;
            case (row)
                8'd0: begin
                    case (chunk)
                        5'd1: riviera_navy_mask = 8'h08;
                        default: riviera_navy_mask = 8'h00;
                    endcase
                end
                8'd1, 8'd2: begin
                    case (chunk)
                        5'd1: riviera_navy_mask = 8'h18;
                        default: riviera_navy_mask = 8'h00;
                    endcase
                end
                8'd3, 8'd4: begin
                    case (chunk)
                        5'd1: riviera_navy_mask = 8'h38;
                        default: riviera_navy_mask = 8'h00;
                    endcase
                end
                8'd5, 8'd6: begin
                    case (chunk)
                        5'd1: riviera_navy_mask = 8'h78;
                        default: riviera_navy_mask = 8'h00;
                    endcase
                end
                8'd7, 8'd8: begin
                    case (chunk)
                        5'd1: riviera_navy_mask = 8'hf8;
                        default: riviera_navy_mask = 8'h00;
                    endcase
                end
                8'd9, 8'd10: begin
                    case (chunk)
                        5'd0: riviera_navy_mask = 8'h01;
                        5'd1: riviera_navy_mask = 8'hf8;
                        default: riviera_navy_mask = 8'h00;
                    endcase
                end
                8'd11: begin
                    case (chunk)
                        5'd0: riviera_navy_mask = 8'h03;
                        5'd1: riviera_navy_mask = 8'hf8;
                        default: riviera_navy_mask = 8'h00;
                    endcase
                end
                8'd12, 8'd13: begin
                    case (chunk)
                        5'd0: riviera_navy_mask = 8'h07;
                        5'd1: riviera_navy_mask = 8'hf8;
                        default: riviera_navy_mask = 8'h00;
                    endcase
                end
                8'd14, 8'd15: begin
                    case (chunk)
                        5'd0: riviera_navy_mask = 8'h0f;
                        5'd1: riviera_navy_mask = 8'hf8;
                        default: riviera_navy_mask = 8'h00;
                    endcase
                end
                8'd16, 8'd17: begin
                    case (chunk)
                        5'd0: riviera_navy_mask = 8'h1f;
                        5'd1: riviera_navy_mask = 8'hf8;
                        default: riviera_navy_mask = 8'h00;
                    endcase
                end
                8'd18: begin
                    case (chunk)
                        5'd0: riviera_navy_mask = 8'h3f;
                        5'd1: riviera_navy_mask = 8'hf8;
                        default: riviera_navy_mask = 8'h00;
                    endcase
                end
                8'd19: begin
                    case (chunk)
                        5'd0: riviera_navy_mask = 8'h3f;
                        5'd1: riviera_navy_mask = 8'hc0;
                        default: riviera_navy_mask = 8'h00;
                    endcase
                end
                8'd20: begin
                    case (chunk)
                        5'd0: riviera_navy_mask = 8'h7e;
                        default: riviera_navy_mask = 8'h00;
                    endcase
                end
                8'd21: begin
                    case (chunk)
                        5'd0: riviera_navy_mask = 8'h70;
                        default: riviera_navy_mask = 8'h00;
                    endcase
                end
                8'd22: begin
                    case (chunk)
                        5'd0: riviera_navy_mask = 8'h80;
                        default: riviera_navy_mask = 8'h00;
                    endcase
                end
                default: riviera_navy_mask = 8'h00;
            endcase
        end
    endfunction

    function [7:0] riviera_light_mask;
        input [7:0] row;
        input [4:0] chunk;
        begin
            riviera_light_mask = 8'h00;
            case (row)
                8'd0, 8'd1: begin
                    case (chunk)
                        5'd1: riviera_light_mask = 8'h08;
                        default: riviera_light_mask = 8'h00;
                    endcase
                end
                8'd2, 8'd3: begin
                    case (chunk)
                        5'd1: riviera_light_mask = 8'h0c;
                        default: riviera_light_mask = 8'h00;
                    endcase
                end
                8'd4, 8'd5: begin
                    case (chunk)
                        5'd1: riviera_light_mask = 8'h0e;
                        default: riviera_light_mask = 8'h00;
                    endcase
                end
                8'd6, 8'd7: begin
                    case (chunk)
                        5'd1: riviera_light_mask = 8'h0f;
                        default: riviera_light_mask = 8'h00;
                    endcase
                end
                8'd8, 8'd9: begin
                    case (chunk)
                        5'd1: riviera_light_mask = 8'h0f;
                        5'd2: riviera_light_mask = 8'h80;
                        default: riviera_light_mask = 8'h00;
                    endcase
                end
                8'd10, 8'd11: begin
                    case (chunk)
                        5'd1: riviera_light_mask = 8'h0f;
                        5'd2: riviera_light_mask = 8'hc0;
                        default: riviera_light_mask = 8'h00;
                    endcase
                end
                8'd12, 8'd13: begin
                    case (chunk)
                        5'd1: riviera_light_mask = 8'h0f;
                        5'd2: riviera_light_mask = 8'he0;
                        default: riviera_light_mask = 8'h00;
                    endcase
                end
                8'd14, 8'd15: begin
                    case (chunk)
                        5'd1: riviera_light_mask = 8'h0f;
                        5'd2: riviera_light_mask = 8'hf0;
                        default: riviera_light_mask = 8'h00;
                    endcase
                end
                8'd16, 8'd17: begin
                    case (chunk)
                        5'd1: riviera_light_mask = 8'h0f;
                        5'd2: riviera_light_mask = 8'hf8;
                        default: riviera_light_mask = 8'h00;
                    endcase
                end
                8'd18: begin
                    case (chunk)
                        5'd1: riviera_light_mask = 8'h0f;
                        5'd2: riviera_light_mask = 8'hfc;
                        default: riviera_light_mask = 8'h00;
                    endcase
                end
                8'd19: begin
                    case (chunk)
                        5'd1: riviera_light_mask = 8'h01;
                        5'd2: riviera_light_mask = 8'hfc;
                        default: riviera_light_mask = 8'h00;
                    endcase
                end
                8'd20: begin
                    case (chunk)
                        5'd2: riviera_light_mask = 8'h3e;
                        default: riviera_light_mask = 8'h00;
                    endcase
                end
                8'd21: begin
                    case (chunk)
                        5'd2: riviera_light_mask = 8'h0e;
                        default: riviera_light_mask = 8'h00;
                    endcase
                end
                8'd22: begin
                    case (chunk)
                        5'd2: riviera_light_mask = 8'h01;
                        default: riviera_light_mask = 8'h00;
                    endcase
                end
                default: riviera_light_mask = 8'h00;
            endcase
        end
    endfunction

    function [7:0] riviera_dark_mask;
        input [7:0] row;
        input [4:0] chunk;
        begin
            riviera_dark_mask = 8'h00;
            case (row)
                8'd18, 8'd31: begin
                    case (chunk)
                        5'd1: riviera_dark_mask = 8'h08;
                        default: riviera_dark_mask = 8'h00;
                    endcase
                end
                8'd19, 8'd29: begin
                    case (chunk)
                        5'd1: riviera_dark_mask = 8'h78;
                        default: riviera_dark_mask = 8'h00;
                    endcase
                end
                8'd20: begin
                    case (chunk)
                        5'd0: riviera_dark_mask = 8'h03;
                        5'd1: riviera_dark_mask = 8'hf8;
                        default: riviera_dark_mask = 8'h00;
                    endcase
                end
                8'd21, 8'd24: begin
                    case (chunk)
                        5'd0: riviera_dark_mask = 8'h1f;
                        5'd1: riviera_dark_mask = 8'hf8;
                        default: riviera_dark_mask = 8'h00;
                    endcase
                end
                8'd22: begin
                    case (chunk)
                        5'd0: riviera_dark_mask = 8'hff;
                        5'd1: riviera_dark_mask = 8'hf8;
                        default: riviera_dark_mask = 8'h00;
                    endcase
                end
                8'd23: begin
                    case (chunk)
                        5'd0: riviera_dark_mask = 8'h7f;
                        5'd1: riviera_dark_mask = 8'hf8;
                        default: riviera_dark_mask = 8'h00;
                    endcase
                end
                8'd25: begin
                    case (chunk)
                        5'd0: riviera_dark_mask = 8'h0f;
                        5'd1: riviera_dark_mask = 8'hf8;
                        default: riviera_dark_mask = 8'h00;
                    endcase
                end
                8'd26: begin
                    case (chunk)
                        5'd0: riviera_dark_mask = 8'h07;
                        5'd1: riviera_dark_mask = 8'hf8;
                        default: riviera_dark_mask = 8'h00;
                    endcase
                end
                8'd27: begin
                    case (chunk)
                        5'd0: riviera_dark_mask = 8'h01;
                        5'd1: riviera_dark_mask = 8'hf8;
                        default: riviera_dark_mask = 8'h00;
                    endcase
                end
                8'd28: begin
                    case (chunk)
                        5'd1: riviera_dark_mask = 8'hf8;
                        default: riviera_dark_mask = 8'h00;
                    endcase
                end
                8'd30: begin
                    case (chunk)
                        5'd1: riviera_dark_mask = 8'h18;
                        default: riviera_dark_mask = 8'h00;
                    endcase
                end
                default: riviera_dark_mask = 8'h00;
            endcase
        end
    endfunction

    function [7:0] riviera_mid_mask;
        input [7:0] row;
        input [4:0] chunk;
        begin
            riviera_mid_mask = 8'h00;
            case (row)
                8'd18, 8'd31: begin
                    case (chunk)
                        5'd1: riviera_mid_mask = 8'h08;
                        default: riviera_mid_mask = 8'h00;
                    endcase
                end
                8'd19: begin
                    case (chunk)
                        5'd1: riviera_mid_mask = 8'h0f;
                        default: riviera_mid_mask = 8'h00;
                    endcase
                end
                8'd20, 8'd27: begin
                    case (chunk)
                        5'd1: riviera_mid_mask = 8'h0f;
                        5'd2: riviera_mid_mask = 8'hc0;
                        default: riviera_mid_mask = 8'h00;
                    endcase
                end
                8'd21: begin
                    case (chunk)
                        5'd1: riviera_mid_mask = 8'h0f;
                        5'd2: riviera_mid_mask = 8'hf8;
                        default: riviera_mid_mask = 8'h00;
                    endcase
                end
                8'd22: begin
                    case (chunk)
                        5'd1: riviera_mid_mask = 8'h0f;
                        5'd2: riviera_mid_mask = 8'hff;
                        default: riviera_mid_mask = 8'h00;
                    endcase
                end
                8'd23: begin
                    case (chunk)
                        5'd1: riviera_mid_mask = 8'h0f;
                        5'd2: riviera_mid_mask = 8'hfe;
                        default: riviera_mid_mask = 8'h00;
                    endcase
                end
                8'd24: begin
                    case (chunk)
                        5'd1: riviera_mid_mask = 8'h0f;
                        5'd2: riviera_mid_mask = 8'hfc;
                        default: riviera_mid_mask = 8'h00;
                    endcase
                end
                8'd25: begin
                    case (chunk)
                        5'd1: riviera_mid_mask = 8'h0f;
                        5'd2: riviera_mid_mask = 8'hf0;
                        default: riviera_mid_mask = 8'h00;
                    endcase
                end
                8'd26: begin
                    case (chunk)
                        5'd1: riviera_mid_mask = 8'h0f;
                        5'd2: riviera_mid_mask = 8'he0;
                        default: riviera_mid_mask = 8'h00;
                    endcase
                end
                8'd28: begin
                    case (chunk)
                        5'd1: riviera_mid_mask = 8'h0f;
                        5'd2: riviera_mid_mask = 8'h80;
                        default: riviera_mid_mask = 8'h00;
                    endcase
                end
                8'd29: begin
                    case (chunk)
                        5'd1: riviera_mid_mask = 8'h0e;
                        default: riviera_mid_mask = 8'h00;
                    endcase
                end
                8'd30: begin
                    case (chunk)
                        5'd1: riviera_mid_mask = 8'h0c;
                        default: riviera_mid_mask = 8'h00;
                    endcase
                end
                default: riviera_mid_mask = 8'h00;
            endcase
        end
    endfunction

    function [7:0] riviera_wordmark_mask;
        input [7:0] row;
        input [4:0] chunk;
        begin
            riviera_wordmark_mask = 8'h00;
            case (row)
                8'd0: begin
                    case (chunk)
                        5'd0: riviera_wordmark_mask = 8'hf3;
                        5'd1: riviera_wordmark_mask = 8'ha2;
                        5'd2: riviera_wordmark_mask = 8'hef;
                        5'd3: riviera_wordmark_mask = 8'hbc;
                        5'd4: riviera_wordmark_mask = 8'h70;
                        5'd5: riviera_wordmark_mask = 8'h1e;
                        5'd6: riviera_wordmark_mask = 8'h9e;
                        default: riviera_wordmark_mask = 8'h00;
                    endcase
                end
                8'd1: begin
                    case (chunk)
                        5'd0: riviera_wordmark_mask = 8'h89;
                        5'd1: riviera_wordmark_mask = 8'h22;
                        5'd2: riviera_wordmark_mask = 8'h48;
                        5'd3: riviera_wordmark_mask = 8'h22;
                        5'd4: riviera_wordmark_mask = 8'h88;
                        5'd5: riviera_wordmark_mask = 8'h20;
                        5'd6: riviera_wordmark_mask = 8'h20;
                        default: riviera_wordmark_mask = 8'h00;
                    endcase
                end
                8'd2: begin
                    case (chunk)
                        5'd0: riviera_wordmark_mask = 8'h89;
                        5'd1: riviera_wordmark_mask = 8'h22;
                        5'd2: riviera_wordmark_mask = 8'h48;
                        5'd3: riviera_wordmark_mask = 8'h22;
                        5'd4: riviera_wordmark_mask = 8'h88;
                        5'd5: riviera_wordmark_mask = 8'h20;
                        5'd6: riviera_wordmark_mask = 8'ha0;
                        default: riviera_wordmark_mask = 8'h00;
                    endcase
                end
                8'd3: begin
                    case (chunk)
                        5'd0: riviera_wordmark_mask = 8'hf1;
                        5'd1: riviera_wordmark_mask = 8'h22;
                        5'd2: riviera_wordmark_mask = 8'h4f;
                        5'd3: riviera_wordmark_mask = 8'h3c;
                        5'd4: riviera_wordmark_mask = 8'hf8;
                        5'd5: riviera_wordmark_mask = 8'h1c;
                        5'd6: riviera_wordmark_mask = 8'ha0;
                        default: riviera_wordmark_mask = 8'h00;
                    endcase
                end
                8'd4: begin
                    case (chunk)
                        5'd0: riviera_wordmark_mask = 8'ha1;
                        5'd1: riviera_wordmark_mask = 8'h22;
                        5'd2: riviera_wordmark_mask = 8'h48;
                        5'd3: riviera_wordmark_mask = 8'h28;
                        5'd4: riviera_wordmark_mask = 8'h88;
                        5'd5: riviera_wordmark_mask = 8'h02;
                        5'd6: riviera_wordmark_mask = 8'ha0;
                        default: riviera_wordmark_mask = 8'h00;
                    endcase
                end
                8'd5: begin
                    case (chunk)
                        5'd0: riviera_wordmark_mask = 8'h91;
                        5'd1: riviera_wordmark_mask = 8'h14;
                        5'd2: riviera_wordmark_mask = 8'h48;
                        5'd3: riviera_wordmark_mask = 8'h24;
                        5'd4: riviera_wordmark_mask = 8'h88;
                        5'd5: riviera_wordmark_mask = 8'h02;
                        5'd6: riviera_wordmark_mask = 8'ha0;
                        default: riviera_wordmark_mask = 8'h00;
                    endcase
                end
                8'd6: begin
                    case (chunk)
                        5'd0: riviera_wordmark_mask = 8'h8b;
                        5'd1: riviera_wordmark_mask = 8'h88;
                        5'd2: riviera_wordmark_mask = 8'hef;
                        5'd3: riviera_wordmark_mask = 8'ha2;
                        5'd4: riviera_wordmark_mask = 8'h88;
                        5'd5: riviera_wordmark_mask = 8'h3c;
                        5'd6: riviera_wordmark_mask = 8'h9e;
                        default: riviera_wordmark_mask = 8'h00;
                    endcase
                end
                default: riviera_wordmark_mask = 8'h00;
            endcase
        end
    endfunction

    function [7:0] almiko_icon_mask;
        input [7:0] row;
        input [4:0] chunk;
        begin
            almiko_icon_mask = 8'h00;
            case (row)
                8'd0, 8'd1, 8'd2, 8'd5, 8'd8, 8'd9: begin
                    case (chunk)
                        5'd0: almiko_icon_mask = 8'hed;
                        5'd1: almiko_icon_mask = 8'hc0;
                        default: almiko_icon_mask = 8'h00;
                    endcase
                end
                8'd3: begin
                    case (chunk)
                        5'd0: almiko_icon_mask = 8'h12;
                        default: almiko_icon_mask = 8'h00;
                    endcase
                end
                8'd4: begin
                    case (chunk)
                        5'd0: almiko_icon_mask = 8'hfd;
                        5'd1: almiko_icon_mask = 8'hc0;
                        default: almiko_icon_mask = 8'h00;
                    endcase
                end
                8'd6: begin
                    case (chunk)
                        5'd0: almiko_icon_mask = 8'h16;
                        default: almiko_icon_mask = 8'h00;
                    endcase
                end
                8'd7: begin
                    case (chunk)
                        5'd0: almiko_icon_mask = 8'hef;
                        5'd1: almiko_icon_mask = 8'hc0;
                        default: almiko_icon_mask = 8'h00;
                    endcase
                end
                default: almiko_icon_mask = 8'h00;
            endcase
        end
    endfunction

    function [7:0] almiko_wordmark_mask;
        input [7:0] row;
        input [4:0] chunk;
        begin
            almiko_wordmark_mask = 8'h00;
            case (row)
                8'd0: begin
                    case (chunk)
                        5'd0: almiko_wordmark_mask = 8'h72;
                        5'd1: almiko_wordmark_mask = 8'h08;
                        5'd2: almiko_wordmark_mask = 8'hba;
                        5'd3: almiko_wordmark_mask = 8'h27;
                        default: almiko_wordmark_mask = 8'h00;
                    endcase
                end
                8'd1: begin
                    case (chunk)
                        5'd0: almiko_wordmark_mask = 8'h8a;
                        5'd1: almiko_wordmark_mask = 8'h0d;
                        5'd2: almiko_wordmark_mask = 8'h92;
                        5'd3: almiko_wordmark_mask = 8'h48;
                        5'd4: almiko_wordmark_mask = 8'h80;
                        default: almiko_wordmark_mask = 8'h00;
                    endcase
                end
                8'd2: begin
                    case (chunk)
                        5'd0: almiko_wordmark_mask = 8'h8a;
                        5'd1: almiko_wordmark_mask = 8'h0a;
                        5'd2: almiko_wordmark_mask = 8'h92;
                        5'd3: almiko_wordmark_mask = 8'h88;
                        5'd4: almiko_wordmark_mask = 8'h80;
                        default: almiko_wordmark_mask = 8'h00;
                    endcase
                end
                8'd3: begin
                    case (chunk)
                        5'd0: almiko_wordmark_mask = 8'hfa;
                        5'd1: almiko_wordmark_mask = 8'h0a;
                        5'd2: almiko_wordmark_mask = 8'h93;
                        5'd3: almiko_wordmark_mask = 8'h08;
                        5'd4: almiko_wordmark_mask = 8'h80;
                        default: almiko_wordmark_mask = 8'h00;
                    endcase
                end
                8'd4: begin
                    case (chunk)
                        5'd0: almiko_wordmark_mask = 8'h8a;
                        5'd1: almiko_wordmark_mask = 8'h08;
                        5'd2: almiko_wordmark_mask = 8'h92;
                        5'd3: almiko_wordmark_mask = 8'h88;
                        5'd4: almiko_wordmark_mask = 8'h80;
                        default: almiko_wordmark_mask = 8'h00;
                    endcase
                end
                8'd5: begin
                    case (chunk)
                        5'd0: almiko_wordmark_mask = 8'h8a;
                        5'd1: almiko_wordmark_mask = 8'h08;
                        5'd2: almiko_wordmark_mask = 8'h92;
                        5'd3: almiko_wordmark_mask = 8'h48;
                        5'd4: almiko_wordmark_mask = 8'h80;
                        default: almiko_wordmark_mask = 8'h00;
                    endcase
                end
                8'd6: begin
                    case (chunk)
                        5'd0: almiko_wordmark_mask = 8'h8b;
                        5'd1: almiko_wordmark_mask = 8'he8;
                        5'd2: almiko_wordmark_mask = 8'hba;
                        5'd3: almiko_wordmark_mask = 8'h27;
                        default: almiko_wordmark_mask = 8'h00;
                    endcase
                end
                default: almiko_wordmark_mask = 8'h00;
            endcase
        end
    endfunction

    function [7:0] almiko_subtitle_mask;
        input [7:0] row;
        input [4:0] chunk;
        begin
            almiko_subtitle_mask = 8'h00;
            case (row)
                8'd0: begin
                    case (chunk)
                        5'd0: almiko_subtitle_mask = 8'hf1;
                        5'd1: almiko_subtitle_mask = 8'hef;
                        5'd2: almiko_subtitle_mask = 8'h01;
                        5'd3: almiko_subtitle_mask = 8'he7;
                        5'd4: almiko_subtitle_mask = 8'h20;
                        5'd5: almiko_subtitle_mask = 8'h8b;
                        5'd6: almiko_subtitle_mask = 8'hee;
                        5'd7: almiko_subtitle_mask = 8'h72;
                        5'd8: almiko_subtitle_mask = 8'h27;
                        5'd9: almiko_subtitle_mask = 8'h80;
                        default: almiko_subtitle_mask = 8'h00;
                    endcase
                end
                8'd1: begin
                    case (chunk)
                        5'd0: almiko_subtitle_mask = 8'h8a;
                        5'd1: almiko_subtitle_mask = 8'h08;
                        5'd2: almiko_subtitle_mask = 8'h82;
                        5'd3: almiko_subtitle_mask = 8'h08;
                        5'd4: almiko_subtitle_mask = 8'ha0;
                        5'd5: almiko_subtitle_mask = 8'h88;
                        5'd6: almiko_subtitle_mask = 8'h84;
                        5'd7: almiko_subtitle_mask = 8'h8b;
                        5'd8: almiko_subtitle_mask = 8'h28;
                        default: almiko_subtitle_mask = 8'h00;
                    endcase
                end
                8'd2: begin
                    case (chunk)
                        5'd0: almiko_subtitle_mask = 8'h8a;
                        5'd1: almiko_subtitle_mask = 8'h08;
                        5'd2: almiko_subtitle_mask = 8'h82;
                        5'd3: almiko_subtitle_mask = 8'h08;
                        5'd4: almiko_subtitle_mask = 8'ha0;
                        5'd5: almiko_subtitle_mask = 8'h88;
                        5'd6: almiko_subtitle_mask = 8'h84;
                        5'd7: almiko_subtitle_mask = 8'h8a;
                        5'd8: almiko_subtitle_mask = 8'ha8;
                        default: almiko_subtitle_mask = 8'h00;
                    endcase
                end
                8'd3: begin
                    case (chunk)
                        5'd0: almiko_subtitle_mask = 8'hf2;
                        5'd1: almiko_subtitle_mask = 8'h0f;
                        5'd2: almiko_subtitle_mask = 8'h01;
                        5'd3: almiko_subtitle_mask = 8'hc8;
                        5'd4: almiko_subtitle_mask = 8'ha0;
                        5'd5: almiko_subtitle_mask = 8'h88;
                        5'd6: almiko_subtitle_mask = 8'h84;
                        5'd7: almiko_subtitle_mask = 8'h8a;
                        5'd8: almiko_subtitle_mask = 8'h67;
                        default: almiko_subtitle_mask = 8'h00;
                    endcase
                end
                8'd4, 8'd5: begin
                    case (chunk)
                        5'd0: almiko_subtitle_mask = 8'h82;
                        5'd1: almiko_subtitle_mask = 8'h08;
                        5'd2: almiko_subtitle_mask = 8'h80;
                        5'd3: almiko_subtitle_mask = 8'h28;
                        5'd4: almiko_subtitle_mask = 8'ha0;
                        5'd5: almiko_subtitle_mask = 8'h88;
                        5'd6: almiko_subtitle_mask = 8'h84;
                        5'd7: almiko_subtitle_mask = 8'h8a;
                        5'd8: almiko_subtitle_mask = 8'h20;
                        5'd9: almiko_subtitle_mask = 8'h80;
                        default: almiko_subtitle_mask = 8'h00;
                    endcase
                end
                8'd6: begin
                    case (chunk)
                        5'd0: almiko_subtitle_mask = 8'h81;
                        5'd1: almiko_subtitle_mask = 8'hef;
                        5'd2: almiko_subtitle_mask = 8'h03;
                        5'd3: almiko_subtitle_mask = 8'hc7;
                        5'd4: almiko_subtitle_mask = 8'h3e;
                        5'd5: almiko_subtitle_mask = 8'h70;
                        5'd6: almiko_subtitle_mask = 8'h8e;
                        5'd7: almiko_subtitle_mask = 8'h72;
                        5'd8: almiko_subtitle_mask = 8'h2f;
                        default: almiko_subtitle_mask = 8'h00;
                    endcase
                end
                default: almiko_subtitle_mask = 8'h00;
            endcase
        end
    endfunction

    function [7:0] letera_mask;
        input [7:0] row;
        input [4:0] chunk;
        begin
            letera_mask = 8'h00;
            case (row)
                8'd0: begin
                    case (chunk)
                        5'd0: letera_mask = 8'he0;
                        5'd1: letera_mask = 8'hfe;
                        5'd2: letera_mask = 8'hfe;
                        5'd3: letera_mask = 8'hfe;
                        5'd4: letera_mask = 8'hf8;
                        5'd5: letera_mask = 8'h10;
                        default: letera_mask = 8'h00;
                    endcase
                end
                8'd1: begin
                    case (chunk)
                        5'd0: letera_mask = 8'h40;
                        5'd1: letera_mask = 8'h42;
                        5'd2: letera_mask = 8'h92;
                        5'd3: letera_mask = 8'h42;
                        5'd4: letera_mask = 8'h44;
                        5'd5: letera_mask = 8'h10;
                        default: letera_mask = 8'h00;
                    endcase
                end
                8'd2: begin
                    case (chunk)
                        5'd0: letera_mask = 8'h40;
                        5'd1: letera_mask = 8'h48;
                        5'd2: letera_mask = 8'h10;
                        5'd3: letera_mask = 8'h48;
                        5'd4: letera_mask = 8'h44;
                        5'd5: letera_mask = 8'h28;
                        default: letera_mask = 8'h00;
                    endcase
                end
                8'd3: begin
                    case (chunk)
                        5'd0: letera_mask = 8'h40;
                        5'd1: letera_mask = 8'h78;
                        5'd2: letera_mask = 8'h10;
                        5'd3: letera_mask = 8'h78;
                        5'd4: letera_mask = 8'h44;
                        5'd5: letera_mask = 8'h28;
                        default: letera_mask = 8'h00;
                    endcase
                end
                8'd4: begin
                    case (chunk)
                        5'd0: letera_mask = 8'h40;
                        5'd1: letera_mask = 8'h48;
                        5'd2: letera_mask = 8'h10;
                        5'd3: letera_mask = 8'h48;
                        5'd4: letera_mask = 8'h78;
                        5'd5: letera_mask = 8'h44;
                        default: letera_mask = 8'h00;
                    endcase
                end
                8'd5: begin
                    case (chunk)
                        5'd0: letera_mask = 8'h40;
                        5'd1: letera_mask = 8'h40;
                        5'd2: letera_mask = 8'h10;
                        5'd3: letera_mask = 8'h40;
                        5'd4: letera_mask = 8'h50;
                        5'd5: letera_mask = 8'h7c;
                        default: letera_mask = 8'h00;
                    endcase
                end
                8'd6: begin
                    case (chunk)
                        5'd0: letera_mask = 8'h40;
                        5'd1: letera_mask = 8'h40;
                        5'd2: letera_mask = 8'h10;
                        5'd3: letera_mask = 8'h40;
                        5'd4: letera_mask = 8'h48;
                        5'd5: letera_mask = 8'h44;
                        default: letera_mask = 8'h00;
                    endcase
                end
                8'd7: begin
                    case (chunk)
                        5'd0: letera_mask = 8'h42;
                        5'd1: letera_mask = 8'h42;
                        5'd2: letera_mask = 8'h10;
                        5'd3: letera_mask = 8'h42;
                        5'd4: letera_mask = 8'h44;
                        5'd5: letera_mask = 8'h82;
                        default: letera_mask = 8'h00;
                    endcase
                end
                8'd8: begin
                    case (chunk)
                        5'd0: letera_mask = 8'hfe;
                        5'd1: letera_mask = 8'hfe;
                        5'd2: letera_mask = 8'h38;
                        5'd3: letera_mask = 8'hfe;
                        5'd4: letera_mask = 8'he6;
                        5'd5: letera_mask = 8'hc6;
                        default: letera_mask = 8'h00;
                    endcase
                end
                default: letera_mask = 8'h00;
            endcase
        end
    endfunction

    function [7:0] letera_dot_mask;
        input [7:0] row;
        input [4:0] chunk;
        begin
            letera_dot_mask = 8'h00;
            case (row)
                8'd0: begin
                    case (chunk)
                        5'd0: letera_dot_mask = 8'h80;
                        default: letera_dot_mask = 8'h00;
                    endcase
                end
                default: letera_dot_mask = 8'h00;
            endcase
        end
    endfunction

    wire [7:0] heading_gx;
    wire [7:0] heading_gy;
    wire [7:0] heading_x;
    wire [7:0] heading_y;
    wire [7:0] heading_byte;
    wire heading_pixel;
    assign heading_gx = x_group - 8'd52;
    assign heading_gy = y_group - 8'd11;
    assign heading_x = heading_gx;
    assign heading_y = heading_gy;
    assign heading_byte = heading_mask(heading_y, heading_x[7:3]);
    assign heading_pixel =
        (x_group >= 8'd52) && (x_group < 8'd109) &&
        (y_group >= 8'd11) && (y_group < 8'd20) &&
        (heading_x < 8'd57) && (heading_y < 8'd9) &&
        heading_byte[3'd7 - heading_x[2:0]];

    wire [7:0] analog_devices_gx;
    wire [7:0] analog_devices_gy;
    wire [7:0] analog_devices_x;
    wire [7:0] analog_devices_y;
    wire [7:0] analog_devices_byte;
    wire analog_devices_pixel;
    assign analog_devices_gx = x_group - 8'd8;
    assign analog_devices_gy = y_group - 8'd35;
    assign analog_devices_x = {analog_devices_gx[6:0], x_phase[1]};
    assign analog_devices_y = {analog_devices_gy[6:0], y_phase[1]};
    assign analog_devices_byte = analog_devices_mask(analog_devices_y, analog_devices_x[7:3]);
    assign analog_devices_pixel =
        (x_group >= 8'd8) && (x_group < 8'd47) &&
        (y_group >= 8'd35) && (y_group < 8'd48) &&
        (analog_devices_x < 8'd78) && (analog_devices_y < 8'd26) &&
        analog_devices_byte[3'd7 - analog_devices_x[2:0]];

    wire [7:0] synopsys_gx;
    wire [7:0] synopsys_gy;
    wire [7:0] synopsys_x;
    wire [7:0] synopsys_y;
    wire [7:0] synopsys_byte;
    wire synopsys_pixel;
    assign synopsys_gx = x_group - 8'd57;
    assign synopsys_gy = y_group - 8'd38;
    assign synopsys_x = synopsys_gx;
    assign synopsys_y = synopsys_gy;
    assign synopsys_byte = synopsys_mask(synopsys_y, synopsys_x[7:3]);
    assign synopsys_pixel =
        (x_group >= 8'd57) && (x_group < 8'd104) &&
        (y_group >= 8'd38) && (y_group < 8'd45) &&
        (synopsys_x < 8'd47) && (synopsys_y < 8'd7) &&
        synopsys_byte[3'd7 - synopsys_x[2:0]];

    wire [7:0] riga_gx;
    wire [7:0] riga_gy;
    wire [7:0] riga_x;
    wire [7:0] riga_y;
    wire [7:0] riga_byte;
    wire riga_pixel;
    assign riga_gx = x_group - 8'd110;
    assign riga_gy = y_group - 8'd32;
    assign riga_x = riga_gx;
    assign riga_y = riga_gy;
    assign riga_byte = riga_mask(riga_y, riga_x[7:3]);
    assign riga_pixel =
        (x_group >= 8'd110) && (x_group < 8'd154) &&
        (y_group >= 8'd32) && (y_group < 8'd52) &&
        (riga_x < 8'd44) && (riga_y < 8'd20) &&
        riga_byte[3'd7 - riga_x[2:0]];

    wire [7:0] saf_bg_gx;
    wire [7:0] saf_bg_gy;
    wire [7:0] saf_bg_x;
    wire [7:0] saf_bg_y;
    wire [7:0] saf_bg_byte;
    wire saf_bg_pixel;
    assign saf_bg_gx = x_group - 8'd18;
    assign saf_bg_gy = y_group - 8'd60;
    assign saf_bg_x = saf_bg_gx;
    assign saf_bg_y = saf_bg_gy;
    assign saf_bg_byte = saf_bg_mask(saf_bg_y, saf_bg_x[7:3]);
    assign saf_bg_pixel =
        (x_group >= 8'd18) && (x_group < 8'd38) &&
        (y_group >= 8'd60) && (y_group < 8'd80) &&
        (saf_bg_x < 8'd20) && (saf_bg_y < 8'd20) &&
        saf_bg_byte[3'd7 - saf_bg_x[2:0]];

    wire [7:0] saf_white_gx;
    wire [7:0] saf_white_gy;
    wire [7:0] saf_white_x;
    wire [7:0] saf_white_y;
    wire [7:0] saf_white_byte;
    wire saf_white_pixel;
    assign saf_white_gx = x_group - 8'd18;
    assign saf_white_gy = y_group - 8'd60;
    assign saf_white_x = saf_white_gx;
    assign saf_white_y = saf_white_gy;
    assign saf_white_byte = saf_white_mask(saf_white_y, saf_white_x[7:3]);
    assign saf_white_pixel =
        (x_group >= 8'd18) && (x_group < 8'd38) &&
        (y_group >= 8'd60) && (y_group < 8'd80) &&
        (saf_white_x < 8'd20) && (saf_white_y < 8'd20) &&
        saf_white_byte[3'd7 - saf_white_x[2:0]];

    wire [7:0] lmt_gx;
    wire [7:0] lmt_gy;
    wire [7:0] lmt_x;
    wire [7:0] lmt_y;
    wire [7:0] lmt_byte;
    wire lmt_pixel;
    assign lmt_gx = x_group - 8'd61;
    assign lmt_gy = y_group - 8'd61;
    assign lmt_x = lmt_gx;
    assign lmt_y = lmt_gy;
    assign lmt_byte = lmt_mask(lmt_y, lmt_x[7:3]);
    assign lmt_pixel =
        (x_group >= 8'd61) && (x_group < 8'd88) &&
        (y_group >= 8'd61) && (y_group < 8'd76) &&
        (lmt_x < 8'd27) && (lmt_y < 8'd15) &&
        lmt_byte[3'd7 - lmt_x[2:0]];

    wire [7:0] lmt_group_gx;
    wire [7:0] lmt_group_gy;
    wire [7:0] lmt_group_x;
    wire [7:0] lmt_group_y;
    wire [7:0] lmt_group_byte;
    wire lmt_group_pixel;
    assign lmt_group_gx = x_group - 8'd62;
    assign lmt_group_gy = y_group - 8'd77;
    assign lmt_group_x = {lmt_group_gx[6:0], x_phase[1]};
    assign lmt_group_y = {lmt_group_gy[6:0], y_phase[1]};
    assign lmt_group_byte = lmt_group_mask(lmt_group_y, lmt_group_x[7:3]);
    assign lmt_group_pixel =
        (x_group >= 8'd62) && (x_group < 8'd77) &&
        (y_group >= 8'd77) && (y_group < 8'd81) &&
        (lmt_group_x < 8'd29) && (lmt_group_y < 8'd7) &&
        lmt_group_byte[3'd7 - lmt_group_x[2:0]];

    wire [7:0] lmt_orange_gx;
    wire [7:0] lmt_orange_gy;
    wire [7:0] lmt_orange_x;
    wire [7:0] lmt_orange_y;
    wire [7:0] lmt_orange_byte;
    wire lmt_orange_pixel;
    assign lmt_orange_gx = x_group - 8'd88;
    assign lmt_orange_gy = y_group - 8'd59;
    assign lmt_orange_x = {lmt_orange_gx[6:0], x_phase[1]};
    assign lmt_orange_y = {lmt_orange_gy[6:0], y_phase[1]};
    assign lmt_orange_byte = lmt_orange_mask(lmt_orange_y, lmt_orange_x[7:3]);
    assign lmt_orange_pixel =
        (x_group >= 8'd88) && (x_group < 8'd104) &&
        (y_group >= 8'd59) && (y_group < 8'd72) &&
        (lmt_orange_x < 8'd32) && (lmt_orange_y < 8'd25) &&
        lmt_orange_byte[3'd7 - lmt_orange_x[2:0]];

    wire [7:0] lmt_red_gx;
    wire [7:0] lmt_red_gy;
    wire [7:0] lmt_red_x;
    wire [7:0] lmt_red_y;
    wire [7:0] lmt_red_byte;
    wire lmt_red_pixel;
    assign lmt_red_gx = x_group - 8'd88;
    assign lmt_red_gy = y_group - 8'd59;
    assign lmt_red_x = {lmt_red_gx[6:0], x_phase[1]};
    assign lmt_red_y = {lmt_red_gy[6:0], y_phase[1]};
    assign lmt_red_byte = lmt_red_mask(lmt_red_y, lmt_red_x[7:3]);
    assign lmt_red_pixel =
        (x_group >= 8'd88) && (x_group < 8'd104) &&
        (y_group >= 8'd59) && (y_group < 8'd72) &&
        (lmt_red_x < 8'd32) && (lmt_red_y < 8'd25) &&
        lmt_red_byte[3'd7 - lmt_red_x[2:0]];

    wire [7:0] eraser_gx;
    wire [7:0] eraser_gy;
    wire [7:0] eraser_x;
    wire [7:0] eraser_y;
    wire [7:0] eraser_byte;
    wire eraser_pixel;
    assign eraser_gx = x_group - 8'd111;
    assign eraser_gy = y_group - 8'd67;
    assign eraser_x = {eraser_gx[6:0], x_phase[1]};
    assign eraser_y = {eraser_gy[6:0], y_phase[1]};
    assign eraser_byte = eraser_mask(eraser_y, eraser_x[7:3]);
    assign eraser_pixel =
        (x_group >= 8'd111) && (x_group < 8'd153) &&
        (y_group >= 8'd67) && (y_group < 8'd72) &&
        (eraser_x < 8'd83) && (eraser_y < 8'd10) &&
        eraser_byte[3'd7 - eraser_x[2:0]];

    wire [7:0] riviera_navy_gx;
    wire [7:0] riviera_navy_gy;
    wire [7:0] riviera_navy_x;
    wire [7:0] riviera_navy_y;
    wire [7:0] riviera_navy_byte;
    wire riviera_navy_pixel;
    assign riviera_navy_gx = x_group - 8'd7;
    assign riviera_navy_gy = y_group - 8'd91;
    assign riviera_navy_x = {riviera_navy_gx[6:0], x_phase[1]};
    assign riviera_navy_y = {riviera_navy_gy[6:0], y_phase[1]};
    assign riviera_navy_byte = riviera_navy_mask(riviera_navy_y, riviera_navy_x[7:3]);
    assign riviera_navy_pixel =
        (x_group >= 8'd7) && (x_group < 8'd19) &&
        (y_group >= 8'd91) && (y_group < 8'd107) &&
        (riviera_navy_x < 8'd24) && (riviera_navy_y < 8'd32) &&
        riviera_navy_byte[3'd7 - riviera_navy_x[2:0]];

    wire [7:0] riviera_light_gx;
    wire [7:0] riviera_light_gy;
    wire [7:0] riviera_light_x;
    wire [7:0] riviera_light_y;
    wire [7:0] riviera_light_byte;
    wire riviera_light_pixel;
    assign riviera_light_gx = x_group - 8'd7;
    assign riviera_light_gy = y_group - 8'd91;
    assign riviera_light_x = {riviera_light_gx[6:0], x_phase[1]};
    assign riviera_light_y = {riviera_light_gy[6:0], y_phase[1]};
    assign riviera_light_byte = riviera_light_mask(riviera_light_y, riviera_light_x[7:3]);
    assign riviera_light_pixel =
        (x_group >= 8'd7) && (x_group < 8'd19) &&
        (y_group >= 8'd91) && (y_group < 8'd107) &&
        (riviera_light_x < 8'd24) && (riviera_light_y < 8'd32) &&
        riviera_light_byte[3'd7 - riviera_light_x[2:0]];

    wire [7:0] riviera_dark_gx;
    wire [7:0] riviera_dark_gy;
    wire [7:0] riviera_dark_x;
    wire [7:0] riviera_dark_y;
    wire [7:0] riviera_dark_byte;
    wire riviera_dark_pixel;
    assign riviera_dark_gx = x_group - 8'd7;
    assign riviera_dark_gy = y_group - 8'd91;
    assign riviera_dark_x = {riviera_dark_gx[6:0], x_phase[1]};
    assign riviera_dark_y = {riviera_dark_gy[6:0], y_phase[1]};
    assign riviera_dark_byte = riviera_dark_mask(riviera_dark_y, riviera_dark_x[7:3]);
    assign riviera_dark_pixel =
        (x_group >= 8'd7) && (x_group < 8'd19) &&
        (y_group >= 8'd91) && (y_group < 8'd107) &&
        (riviera_dark_x < 8'd24) && (riviera_dark_y < 8'd32) &&
        riviera_dark_byte[3'd7 - riviera_dark_x[2:0]];

    wire [7:0] riviera_mid_gx;
    wire [7:0] riviera_mid_gy;
    wire [7:0] riviera_mid_x;
    wire [7:0] riviera_mid_y;
    wire [7:0] riviera_mid_byte;
    wire riviera_mid_pixel;
    assign riviera_mid_gx = x_group - 8'd7;
    assign riviera_mid_gy = y_group - 8'd91;
    assign riviera_mid_x = {riviera_mid_gx[6:0], x_phase[1]};
    assign riviera_mid_y = {riviera_mid_gy[6:0], y_phase[1]};
    assign riviera_mid_byte = riviera_mid_mask(riviera_mid_y, riviera_mid_x[7:3]);
    assign riviera_mid_pixel =
        (x_group >= 8'd7) && (x_group < 8'd19) &&
        (y_group >= 8'd91) && (y_group < 8'd107) &&
        (riviera_mid_x < 8'd24) && (riviera_mid_y < 8'd32) &&
        riviera_mid_byte[3'd7 - riviera_mid_x[2:0]];

    wire [7:0] riviera_wordmark_gx;
    wire [7:0] riviera_wordmark_gy;
    wire [7:0] riviera_wordmark_x;
    wire [7:0] riviera_wordmark_y;
    wire [7:0] riviera_wordmark_byte;
    wire riviera_wordmark_pixel;
    assign riviera_wordmark_gx = x_group - 8'd21;
    assign riviera_wordmark_gy = y_group - 8'd96;
    assign riviera_wordmark_x = {riviera_wordmark_gx[6:0], x_phase[1]};
    assign riviera_wordmark_y = {riviera_wordmark_gy[6:0], y_phase[1]};
    assign riviera_wordmark_byte = riviera_wordmark_mask(riviera_wordmark_y, riviera_wordmark_x[7:3]);
    assign riviera_wordmark_pixel =
        (x_group >= 8'd21) && (x_group < 8'd49) &&
        (y_group >= 8'd96) && (y_group < 8'd100) &&
        (riviera_wordmark_x < 8'd55) && (riviera_wordmark_y < 8'd7) &&
        riviera_wordmark_byte[3'd7 - riviera_wordmark_x[2:0]];

    wire [7:0] almiko_icon_gx;
    wire [7:0] almiko_icon_gy;
    wire [7:0] almiko_icon_x;
    wire [7:0] almiko_icon_y;
    wire [7:0] almiko_icon_byte;
    wire almiko_icon_pixel;
    assign almiko_icon_gx = x_group - 8'd55;
    assign almiko_icon_gy = y_group - 8'd94;
    assign almiko_icon_x = almiko_icon_gx;
    assign almiko_icon_y = almiko_icon_gy;
    assign almiko_icon_byte = almiko_icon_mask(almiko_icon_y, almiko_icon_x[7:3]);
    assign almiko_icon_pixel =
        (x_group >= 8'd55) && (x_group < 8'd65) &&
        (y_group >= 8'd94) && (y_group < 8'd104) &&
        (almiko_icon_x < 8'd10) && (almiko_icon_y < 8'd10) &&
        almiko_icon_byte[3'd7 - almiko_icon_x[2:0]];

    wire [7:0] almiko_wordmark_gx;
    wire [7:0] almiko_wordmark_gy;
    wire [7:0] almiko_wordmark_x;
    wire [7:0] almiko_wordmark_y;
    wire [7:0] almiko_wordmark_byte;
    wire almiko_wordmark_pixel;
    assign almiko_wordmark_gx = x_group - 8'd68;
    assign almiko_wordmark_gy = y_group - 8'd93;
    assign almiko_wordmark_x = almiko_wordmark_gx;
    assign almiko_wordmark_y = almiko_wordmark_gy;
    assign almiko_wordmark_byte = almiko_wordmark_mask(almiko_wordmark_y, almiko_wordmark_x[7:3]);
    assign almiko_wordmark_pixel =
        (x_group >= 8'd68) && (x_group < 8'd101) &&
        (y_group >= 8'd93) && (y_group < 8'd100) &&
        (almiko_wordmark_x < 8'd33) && (almiko_wordmark_y < 8'd7) &&
        almiko_wordmark_byte[3'd7 - almiko_wordmark_x[2:0]];

    wire [7:0] almiko_subtitle_gx;
    wire [7:0] almiko_subtitle_gy;
    wire [7:0] almiko_subtitle_x;
    wire [7:0] almiko_subtitle_y;
    wire [7:0] almiko_subtitle_byte;
    wire almiko_subtitle_pixel;
    assign almiko_subtitle_gx = x_group - 8'd66;
    assign almiko_subtitle_gy = y_group - 8'd102;
    assign almiko_subtitle_x = {almiko_subtitle_gx[6:0], x_phase[1]};
    assign almiko_subtitle_y = {almiko_subtitle_gy[6:0], y_phase[1]};
    assign almiko_subtitle_byte = almiko_subtitle_mask(almiko_subtitle_y, almiko_subtitle_x[7:3]);
    assign almiko_subtitle_pixel =
        (x_group >= 8'd66) && (x_group < 8'd103) &&
        (y_group >= 8'd102) && (y_group < 8'd106) &&
        (almiko_subtitle_x < 8'd73) && (almiko_subtitle_y < 8'd7) &&
        almiko_subtitle_byte[3'd7 - almiko_subtitle_x[2:0]];

    wire [7:0] letera_gx;
    wire [7:0] letera_gy;
    wire [7:0] letera_x;
    wire [7:0] letera_y;
    wire [7:0] letera_byte;
    wire letera_pixel;
    assign letera_gx = x_group - 8'd108;
    assign letera_gy = y_group - 8'd95;
    assign letera_x = letera_gx;
    assign letera_y = letera_gy;
    assign letera_byte = letera_mask(letera_y, letera_x[7:3]);
    assign letera_pixel =
        (x_group >= 8'd108) && (x_group < 8'd155) &&
        (y_group >= 8'd95) && (y_group < 8'd104) &&
        (letera_x < 8'd47) && (letera_y < 8'd9) &&
        letera_byte[3'd7 - letera_x[2:0]];

    wire [7:0] letera_dot_gx;
    wire [7:0] letera_dot_gy;
    wire [7:0] letera_dot_x;
    wire [7:0] letera_dot_y;
    wire [7:0] letera_dot_byte;
    wire letera_dot_pixel;
    assign letera_dot_gx = x_group - 8'd155;
    assign letera_dot_gy = y_group - 8'd103;
    assign letera_dot_x = letera_dot_gx;
    assign letera_dot_y = letera_dot_gy;
    assign letera_dot_byte = letera_dot_mask(letera_dot_y, letera_dot_x[7:3]);
    assign letera_dot_pixel =
        (x_group >= 8'd155) && (x_group < 8'd156) &&
        (y_group >= 8'd103) && (y_group < 8'd104) &&
        (letera_dot_x < 8'd1) && (letera_dot_y < 8'd1) &&
        letera_dot_byte[3'd7 - letera_dot_x[2:0]];

    always @* begin
        red = 2'd3; green = 2'd3; blue = 2'd3;
        if (heading_pixel) begin
            red = 2'd0; green = 2'd0; blue = 2'd0;
        end
        if (analog_devices_pixel) begin
            red = 2'd0; green = 2'd1; blue = 2'd2;
        end
        if (synopsys_pixel) begin
            red = 2'd1; green = 2'd0; blue = 2'd2;
        end
        if (riga_pixel) begin
            red = 2'd0; green = 2'd0; blue = 2'd0;
        end
        if (saf_bg_pixel) begin
            red = 2'd3; green = 2'd0; blue = 2'd0;
        end
        if (saf_white_pixel) begin
            red = 2'd3; green = 2'd3; blue = 2'd3;
        end
        if (lmt_pixel) begin
            red = 2'd0; green = 2'd0; blue = 2'd0;
        end
        if (lmt_group_pixel) begin
            red = 2'd0; green = 2'd0; blue = 2'd0;
        end
        if (lmt_orange_pixel) begin
            red = 2'd3; green = 2'd1; blue = 2'd0;
        end
        if (lmt_red_pixel) begin
            red = 2'd3; green = 2'd0; blue = 2'd0;
        end
        if (eraser_pixel) begin
            red = 2'd0; green = 2'd0; blue = 2'd1;
        end
        if (riviera_navy_pixel) begin
            red = 2'd0; green = 2'd0; blue = 2'd1;
        end
        if (riviera_light_pixel) begin
            red = 2'd2; green = 2'd3; blue = 2'd2;
        end
        if (riviera_dark_pixel) begin
            red = 2'd0; green = 2'd1; blue = 2'd1;
        end
        if (riviera_mid_pixel) begin
            red = 2'd1; green = 2'd2; blue = 2'd1;
        end
        if (riviera_wordmark_pixel) begin
            red = 2'd0; green = 2'd0; blue = 2'd1;
        end
        if (almiko_icon_pixel) begin
            red = 2'd2; green = 2'd2; blue = 2'd0;
        end
        if (almiko_wordmark_pixel) begin
            red = 2'd0; green = 2'd1; blue = 2'd0;
        end
        if (almiko_subtitle_pixel) begin
            red = 2'd2; green = 2'd2; blue = 2'd0;
        end
        if (letera_pixel) begin
            red = 2'd3; green = 2'd0; blue = 2'd0;
        end
        if (letera_dot_pixel) begin
            red = 2'd3; green = 2'd0; blue = 2'd0;
        end
    end
endmodule

`default_nettype none

// Pixel-art supporter marks generated by design/generate_supporters.py.
// Four-pixel groups and separate two-bit phases retain two-pixel detail.
// All declared data items and explicit Verilog constants are <= eight bits.
// This combinational module renders colour; the top level applies blanking.
module lccc_supporters_renderer (
    input wire [7:0] x_group,
    input wire [7:0] y_group,
    input wire [1:0] x_phase,
    input wire [1:0] y_phase,
    output reg [1:0] red,
    output reg [1:0] green,
    output reg [1:0] blue
);

    function [7:0] heading_mask;
        input [7:0] row;
        input [4:0] chunk;
        begin
            heading_mask = 8'h00;
            case (row)
                8'd0, 8'd1: begin
                    case (chunk)
                        5'd4: heading_mask = 8'h04;
                        5'd6: heading_mask = 8'h20;
                        5'd7: heading_mask = 8'h80;
                        default: heading_mask = 8'h00;
                    endcase
                end
                8'd2: begin
                    case (chunk)
                        5'd0: heading_mask = 8'h7a;
                        5'd1: heading_mask = 8'h2f;
                        5'd2: heading_mask = 8'h3c;
                        5'd3: heading_mask = 8'h72;
                        5'd4: heading_mask = 8'hce;
                        5'd5: heading_mask = 8'h71;
                        5'd6: heading_mask = 8'ha0;
                        5'd7: heading_mask = 8'hb2;
                        5'd8: heading_mask = 8'h20;
                        default: heading_mask = 8'h00;
                    endcase
                end
                8'd3: begin
                    case (chunk)
                        5'd0: heading_mask = 8'h82;
                        5'd1: heading_mask = 8'h28;
                        5'd2: heading_mask = 8'ha2;
                        5'd3: heading_mask = 8'h8b;
                        5'd4: heading_mask = 8'h24;
                        5'd5: heading_mask = 8'h8a;
                        5'd6: heading_mask = 8'h60;
                        5'd7: heading_mask = 8'hca;
                        5'd8: heading_mask = 8'h20;
                        default: heading_mask = 8'h00;
                    endcase
                end
                8'd4: begin
                    case (chunk)
                        5'd0: heading_mask = 8'h72;
                        5'd1: heading_mask = 8'h28;
                        5'd2: heading_mask = 8'ha2;
                        5'd3: heading_mask = 8'h8a;
                        5'd4: heading_mask = 8'h04;
                        5'd5: heading_mask = 8'hfa;
                        5'd6: heading_mask = 8'h20;
                        5'd7: heading_mask = 8'h8a;
                        5'd8: heading_mask = 8'h20;
                        default: heading_mask = 8'h00;
                    endcase
                end
                8'd5: begin
                    case (chunk)
                        5'd0: heading_mask = 8'h0a;
                        5'd1: heading_mask = 8'h68;
                        5'd2: heading_mask = 8'ha2;
                        5'd3: heading_mask = 8'h8a;
                        5'd4: heading_mask = 8'h04;
                        5'd5: heading_mask = 8'h82;
                        5'd6: heading_mask = 8'h20;
                        5'd7: heading_mask = 8'h8a;
                        5'd8: heading_mask = 8'h20;
                        default: heading_mask = 8'h00;
                    endcase
                end
                8'd6: begin
                    case (chunk)
                        5'd0: heading_mask = 8'hf1;
                        5'd1: heading_mask = 8'haf;
                        5'd2: heading_mask = 8'h3c;
                        5'd3: heading_mask = 8'h72;
                        5'd4: heading_mask = 8'h02;
                        5'd5: heading_mask = 8'h71;
                        5'd6: heading_mask = 8'he0;
                        5'd7: heading_mask = 8'hf1;
                        5'd8: heading_mask = 8'he0;
                        default: heading_mask = 8'h00;
                    endcase
                end
                8'd7: begin
                    case (chunk)
                        5'd1: heading_mask = 8'h08;
                        5'd2: heading_mask = 8'h20;
                        5'd8: heading_mask = 8'h20;
                        default: heading_mask = 8'h00;
                    endcase
                end
                8'd8: begin
                    case (chunk)
                        5'd1: heading_mask = 8'h08;
                        5'd2: heading_mask = 8'h20;
                        5'd7: heading_mask = 8'h01;
                        5'd8: heading_mask = 8'hc0;
                        default: heading_mask = 8'h00;
                    endcase
                end
                default: heading_mask = 8'h00;
            endcase
        end
    endfunction

    function [7:0] semi_green_mask;
        input [7:0] row;
        input [4:0] chunk;
        begin
            semi_green_mask = 8'h00;
            case (row)
                8'd0: begin
                    case (chunk)
                        5'd2: semi_green_mask = 8'h04;
                        default: semi_green_mask = 8'h00;
                    endcase
                end
                8'd1: begin
                    case (chunk)
                        5'd2: semi_green_mask = 8'h3f;
                        5'd3: semi_green_mask = 8'hc0;
                        default: semi_green_mask = 8'h00;
                    endcase
                end
                8'd2: begin
                    case (chunk)
                        5'd1: semi_green_mask = 8'h01;
                        5'd2: semi_green_mask = 8'hff;
                        5'd3: semi_green_mask = 8'hc0;
                        default: semi_green_mask = 8'h00;
                    endcase
                end
                8'd3: begin
                    case (chunk)
                        5'd1: semi_green_mask = 8'h07;
                        5'd2: semi_green_mask = 8'hff;
                        5'd3: semi_green_mask = 8'hc0;
                        default: semi_green_mask = 8'h00;
                    endcase
                end
                8'd4: begin
                    case (chunk)
                        5'd1: semi_green_mask = 8'h0f;
                        5'd2: semi_green_mask = 8'hff;
                        5'd3: semi_green_mask = 8'hc0;
                        default: semi_green_mask = 8'h00;
                    endcase
                end
                8'd5: begin
                    case (chunk)
                        5'd1: semi_green_mask = 8'h3f;
                        5'd2: semi_green_mask = 8'hff;
                        5'd3: semi_green_mask = 8'h80;
                        default: semi_green_mask = 8'h00;
                    endcase
                end
                8'd6: begin
                    case (chunk)
                        5'd1: semi_green_mask = 8'h7f;
                        5'd2: semi_green_mask = 8'hfe;
                        default: semi_green_mask = 8'h00;
                    endcase
                end
                8'd7: begin
                    case (chunk)
                        5'd0: semi_green_mask = 8'h01;
                        5'd1: semi_green_mask = 8'hff;
                        5'd2: semi_green_mask = 8'hfc;
                        default: semi_green_mask = 8'h00;
                    endcase
                end
                8'd8: begin
                    case (chunk)
                        5'd0: semi_green_mask = 8'h03;
                        5'd1: semi_green_mask = 8'hff;
                        5'd2: semi_green_mask = 8'hc0;
                        default: semi_green_mask = 8'h00;
                    endcase
                end
                8'd9: begin
                    case (chunk)
                        5'd0: semi_green_mask = 8'h07;
                        5'd1: semi_green_mask = 8'hfc;
                        default: semi_green_mask = 8'h00;
                    endcase
                end
                8'd10: begin
                    case (chunk)
                        5'd0: semi_green_mask = 8'h0f;
                        5'd1: semi_green_mask = 8'hf0;
                        default: semi_green_mask = 8'h00;
                    endcase
                end
                8'd11: begin
                    case (chunk)
                        5'd0: semi_green_mask = 8'h1f;
                        5'd1: semi_green_mask = 8'hc0;
                        default: semi_green_mask = 8'h00;
                    endcase
                end
                8'd12: begin
                    case (chunk)
                        5'd0: semi_green_mask = 8'h3f;
                        5'd1: semi_green_mask = 8'h80;
                        default: semi_green_mask = 8'h00;
                    endcase
                end
                8'd13: begin
                    case (chunk)
                        5'd0: semi_green_mask = 8'h3e;
                        default: semi_green_mask = 8'h00;
                    endcase
                end
                8'd14: begin
                    case (chunk)
                        5'd0: semi_green_mask = 8'h7c;
                        default: semi_green_mask = 8'h00;
                    endcase
                end
                8'd15: begin
                    case (chunk)
                        5'd0: semi_green_mask = 8'h78;
                        default: semi_green_mask = 8'h00;
                    endcase
                end
                8'd16: begin
                    case (chunk)
                        5'd0: semi_green_mask = 8'h60;
                        default: semi_green_mask = 8'h00;
                    endcase
                end
                8'd17: begin
                    case (chunk)
                        5'd0: semi_green_mask = 8'hc0;
                        default: semi_green_mask = 8'h00;
                    endcase
                end
                8'd18: begin
                    case (chunk)
                        5'd0: semi_green_mask = 8'h80;
                        default: semi_green_mask = 8'h00;
                    endcase
                end
                default: semi_green_mask = 8'h00;
            endcase
        end
    endfunction

    function [7:0] semi_black_mask;
        input [7:0] row;
        input [4:0] chunk;
        begin
            semi_black_mask = 8'h00;
            case (row)
                8'd5: begin
                    case (chunk)
                        5'd2: semi_black_mask = 8'h02;
                        default: semi_black_mask = 8'h00;
                    endcase
                end
                8'd6: begin
                    case (chunk)
                        5'd2: semi_black_mask = 8'h07;
                        default: semi_black_mask = 8'h00;
                    endcase
                end
                8'd7: begin
                    case (chunk)
                        5'd2: semi_black_mask = 8'h0f;
                        5'd3: semi_black_mask = 8'hc0;
                        default: semi_black_mask = 8'h00;
                    endcase
                end
                8'd8: begin
                    case (chunk)
                        5'd2: semi_black_mask = 8'h3f;
                        5'd3: semi_black_mask = 8'hc0;
                        default: semi_black_mask = 8'h00;
                    endcase
                end
                8'd9: begin
                    case (chunk)
                        5'd2: semi_black_mask = 8'h7f;
                        5'd3: semi_black_mask = 8'hc0;
                        default: semi_black_mask = 8'h00;
                    endcase
                end
                8'd10: begin
                    case (chunk)
                        5'd2: semi_black_mask = 8'hff;
                        5'd3: semi_black_mask = 8'h80;
                        default: semi_black_mask = 8'h00;
                    endcase
                end
                8'd11: begin
                    case (chunk)
                        5'd1: semi_black_mask = 8'h01;
                        5'd2: semi_black_mask = 8'hff;
                        5'd3: semi_black_mask = 8'h80;
                        default: semi_black_mask = 8'h00;
                    endcase
                end
                8'd12: begin
                    case (chunk)
                        5'd1: semi_black_mask = 8'h07;
                        5'd2: semi_black_mask = 8'hff;
                        default: semi_black_mask = 8'h00;
                    endcase
                end
                8'd13: begin
                    case (chunk)
                        5'd1: semi_black_mask = 8'h0f;
                        5'd2: semi_black_mask = 8'hfc;
                        default: semi_black_mask = 8'h00;
                    endcase
                end
                8'd14: begin
                    case (chunk)
                        5'd1: semi_black_mask = 8'h1f;
                        5'd2: semi_black_mask = 8'hf8;
                        default: semi_black_mask = 8'h00;
                    endcase
                end
                8'd15: begin
                    case (chunk)
                        5'd1: semi_black_mask = 8'h7f;
                        5'd2: semi_black_mask = 8'he0;
                        default: semi_black_mask = 8'h00;
                    endcase
                end
                8'd16: begin
                    case (chunk)
                        5'd1: semi_black_mask = 8'hff;
                        5'd2: semi_black_mask = 8'hc0;
                        default: semi_black_mask = 8'h00;
                    endcase
                end
                8'd17: begin
                    case (chunk)
                        5'd0: semi_black_mask = 8'h03;
                        5'd1: semi_black_mask = 8'hff;
                        default: semi_black_mask = 8'h00;
                    endcase
                end
                8'd18: begin
                    case (chunk)
                        5'd0: semi_black_mask = 8'h07;
                        5'd1: semi_black_mask = 8'hf8;
                        default: semi_black_mask = 8'h00;
                    endcase
                end
                8'd19: begin
                    case (chunk)
                        5'd0: semi_black_mask = 8'h1f;
                        5'd1: semi_black_mask = 8'he0;
                        default: semi_black_mask = 8'h00;
                    endcase
                end
                default: semi_black_mask = 8'h00;
            endcase
        end
    endfunction

    function [7:0] semi_wordmark_mask;
        input [7:0] row;
        input [4:0] chunk;
        begin
            semi_wordmark_mask = 8'h00;
            case (row)
                8'd0: begin
                    case (chunk)
                        5'd2: semi_wordmark_mask = 8'h01;
                        default: semi_wordmark_mask = 8'h00;
                    endcase
                end
                8'd2: begin
                    case (chunk)
                        5'd0: semi_wordmark_mask = 8'h78;
                        5'd1: semi_wordmark_mask = 8'he3;
                        5'd2: semi_wordmark_mask = 8'h51;
                        default: semi_wordmark_mask = 8'h00;
                    endcase
                end
                8'd3: begin
                    case (chunk)
                        5'd0: semi_wordmark_mask = 8'h81;
                        5'd1: semi_wordmark_mask = 8'h12;
                        5'd2: semi_wordmark_mask = 8'ha9;
                        default: semi_wordmark_mask = 8'h00;
                    endcase
                end
                8'd4: begin
                    case (chunk)
                        5'd0: semi_wordmark_mask = 8'h71;
                        5'd1: semi_wordmark_mask = 8'hf2;
                        5'd2: semi_wordmark_mask = 8'ha9;
                        default: semi_wordmark_mask = 8'h00;
                    endcase
                end
                8'd5: begin
                    case (chunk)
                        5'd0: semi_wordmark_mask = 8'h09;
                        5'd1: semi_wordmark_mask = 8'h02;
                        5'd2: semi_wordmark_mask = 8'ha9;
                        default: semi_wordmark_mask = 8'h00;
                    endcase
                end
                8'd6: begin
                    case (chunk)
                        5'd0: semi_wordmark_mask = 8'hf0;
                        5'd1: semi_wordmark_mask = 8'he2;
                        5'd2: semi_wordmark_mask = 8'ha9;
                        default: semi_wordmark_mask = 8'h00;
                    endcase
                end
                default: semi_wordmark_mask = 8'h00;
            endcase
        end
    endfunction

    function [7:0] lccc_navy_mask;
        input [7:0] row;
        input [4:0] chunk;
        begin
            lccc_navy_mask = 8'h00;
            case (row)
                8'd3, 8'd4, 8'd5, 8'd6, 8'd7: begin
                    case (chunk)
                        5'd0: lccc_navy_mask = 8'hfe;
                        5'd1: lccc_navy_mask = 8'h7f;
                        5'd2: lccc_navy_mask = 8'h80;
                        default: lccc_navy_mask = 8'h00;
                    endcase
                end
                8'd8, 8'd9, 8'd10, 8'd11, 8'd12, 8'd13, 8'd17, 8'd18, 8'd19: begin
                    case (chunk)
                        5'd0: lccc_navy_mask = 8'hfe;
                        5'd2: lccc_navy_mask = 8'hfc;
                        default: lccc_navy_mask = 8'h00;
                    endcase
                end
                8'd14, 8'd15, 8'd16: begin
                    case (chunk)
                        5'd0: lccc_navy_mask = 8'hfe;
                        5'd1: lccc_navy_mask = 8'h7f;
                        5'd2: lccc_navy_mask = 8'hfc;
                        default: lccc_navy_mask = 8'h00;
                    endcase
                end
                8'd20, 8'd21, 8'd22, 8'd23, 8'd24, 8'd25: begin
                    case (chunk)
                        5'd0: lccc_navy_mask = 8'hff;
                        5'd1: lccc_navy_mask = 8'hbf;
                        5'd2: lccc_navy_mask = 8'hfc;
                        default: lccc_navy_mask = 8'h00;
                    endcase
                end
                default: lccc_navy_mask = 8'h00;
            endcase
        end
    endfunction

    function [7:0] lccc_accent_mask;
        input [7:0] row;
        input [4:0] chunk;
        begin
            lccc_accent_mask = 8'h00;
            case (row)
                8'd0, 8'd1, 8'd2, 8'd3: begin
                    case (chunk)
                        5'd2: lccc_accent_mask = 8'h3c;
                        default: lccc_accent_mask = 8'h00;
                    endcase
                end
                default: lccc_accent_mask = 8'h00;
            endcase
        end
    endfunction

    function [7:0] lccc_line1_mask;
        input [7:0] row;
        input [4:0] chunk;
        begin
            lccc_line1_mask = 8'h00;
            case (row)
                8'd0: begin
                    case (chunk)
                        5'd0: lccc_line1_mask = 8'h84;
                        5'd1: lccc_line1_mask = 8'hea;
                        5'd2: lccc_line1_mask = 8'he4;
                        5'd3: lccc_line1_mask = 8'h90;
                        5'd4: lccc_line1_mask = 8'h6a;
                        5'd5: lccc_line1_mask = 8'hec;
                        default: lccc_line1_mask = 8'h00;
                    endcase
                end
                8'd1, 8'd2: begin
                    case (chunk)
                        5'd0: lccc_line1_mask = 8'h8a;
                        5'd1: lccc_line1_mask = 8'h4a;
                        5'd2: lccc_line1_mask = 8'h4a;
                        5'd3: lccc_line1_mask = 8'hd0;
                        5'd4: lccc_line1_mask = 8'h8a;
                        5'd5: lccc_line1_mask = 8'h4a;
                        default: lccc_line1_mask = 8'h00;
                    endcase
                end
                8'd3: begin
                    case (chunk)
                        5'd0: lccc_line1_mask = 8'h8e;
                        5'd1: lccc_line1_mask = 8'h4a;
                        5'd2: lccc_line1_mask = 8'h4e;
                        5'd3: lccc_line1_mask = 8'hb0;
                        5'd4: lccc_line1_mask = 8'h8e;
                        5'd5: lccc_line1_mask = 8'h4c;
                        default: lccc_line1_mask = 8'h00;
                    endcase
                end
                8'd4: begin
                    case (chunk)
                        5'd0: lccc_line1_mask = 8'h8a;
                        5'd1: lccc_line1_mask = 8'h4a;
                        5'd2: lccc_line1_mask = 8'h4a;
                        5'd3: lccc_line1_mask = 8'hb0;
                        5'd4: lccc_line1_mask = 8'h8a;
                        5'd5: lccc_line1_mask = 8'h48;
                        default: lccc_line1_mask = 8'h00;
                    endcase
                end
                8'd5: begin
                    case (chunk)
                        5'd0: lccc_line1_mask = 8'h8a;
                        5'd1: lccc_line1_mask = 8'h4a;
                        5'd2: lccc_line1_mask = 8'h4a;
                        5'd3: lccc_line1_mask = 8'h90;
                        5'd4: lccc_line1_mask = 8'h8a;
                        5'd5: lccc_line1_mask = 8'h48;
                        default: lccc_line1_mask = 8'h00;
                    endcase
                end
                8'd6: begin
                    case (chunk)
                        5'd0: lccc_line1_mask = 8'hea;
                        5'd1: lccc_line1_mask = 8'h44;
                        5'd2: lccc_line1_mask = 8'hea;
                        5'd3: lccc_line1_mask = 8'h90;
                        5'd4: lccc_line1_mask = 8'h6a;
                        5'd5: lccc_line1_mask = 8'he8;
                        default: lccc_line1_mask = 8'h00;
                    endcase
                end
                default: lccc_line1_mask = 8'h00;
            endcase
        end
    endfunction

    function [7:0] lccc_line2_mask;
        input [7:0] row;
        input [4:0] chunk;
        begin
            lccc_line2_mask = 8'h00;
            case (row)
                8'd0: begin
                    case (chunk)
                        5'd0: lccc_line2_mask = 8'h64;
                        5'd1: lccc_line2_mask = 8'h8b;
                        5'd2: lccc_line2_mask = 8'h3b;
                        5'd3: lccc_line2_mask = 8'hba;
                        5'd4: lccc_line2_mask = 8'h4d;
                        5'd5: lccc_line2_mask = 8'hc1;
                        5'd6: lccc_line2_mask = 8'hba;
                        5'd7: lccc_line2_mask = 8'h5d;
                        5'd8: lccc_line2_mask = 8'h9c;
                        default: lccc_line2_mask = 8'h00;
                    endcase
                end
                8'd1: begin
                    case (chunk)
                        5'd0: lccc_line2_mask = 8'h8a;
                        5'd1: lccc_line2_mask = 8'hda;
                        5'd2: lccc_line2_mask = 8'ha1;
                        5'd3: lccc_line2_mask = 8'h23;
                        5'd4: lccc_line2_mask = 8'h51;
                        5'd5: lccc_line2_mask = 8'h02;
                        5'd6: lccc_line2_mask = 8'h23;
                        5'd7: lccc_line2_mask = 8'h49;
                        5'd8: lccc_line2_mask = 8'h50;
                        default: lccc_line2_mask = 8'h00;
                    endcase
                end
                8'd2: begin
                    case (chunk)
                        5'd0: lccc_line2_mask = 8'h8a;
                        5'd1: lccc_line2_mask = 8'haa;
                        5'd2: lccc_line2_mask = 8'ha1;
                        5'd3: lccc_line2_mask = 8'h23;
                        5'd4: lccc_line2_mask = 8'h51;
                        5'd5: lccc_line2_mask = 8'h02;
                        5'd6: lccc_line2_mask = 8'h23;
                        5'd7: lccc_line2_mask = 8'h49;
                        5'd8: lccc_line2_mask = 8'h50;
                        default: lccc_line2_mask = 8'h00;
                    endcase
                end
                8'd3: begin
                    case (chunk)
                        5'd0: lccc_line2_mask = 8'h8a;
                        5'd1: lccc_line2_mask = 8'hab;
                        5'd2: lccc_line2_mask = 8'h31;
                        5'd3: lccc_line2_mask = 8'h32;
                        5'd4: lccc_line2_mask = 8'hd1;
                        5'd5: lccc_line2_mask = 8'h82;
                        5'd6: lccc_line2_mask = 8'h32;
                        5'd7: lccc_line2_mask = 8'hc9;
                        5'd8: lccc_line2_mask = 8'h98;
                        default: lccc_line2_mask = 8'h00;
                    endcase
                end
                8'd4: begin
                    case (chunk)
                        5'd0: lccc_line2_mask = 8'h8a;
                        5'd1: lccc_line2_mask = 8'h8a;
                        5'd2: lccc_line2_mask = 8'h21;
                        5'd3: lccc_line2_mask = 8'h22;
                        5'd4: lccc_line2_mask = 8'hd1;
                        5'd5: lccc_line2_mask = 8'h02;
                        5'd6: lccc_line2_mask = 8'h22;
                        5'd7: lccc_line2_mask = 8'hc9;
                        5'd8: lccc_line2_mask = 8'h50;
                        default: lccc_line2_mask = 8'h00;
                    endcase
                end
                8'd5: begin
                    case (chunk)
                        5'd0: lccc_line2_mask = 8'h8a;
                        5'd1: lccc_line2_mask = 8'h8a;
                        5'd2: lccc_line2_mask = 8'h21;
                        5'd3: lccc_line2_mask = 8'h22;
                        5'd4: lccc_line2_mask = 8'h51;
                        5'd5: lccc_line2_mask = 8'h02;
                        5'd6: lccc_line2_mask = 8'h22;
                        5'd7: lccc_line2_mask = 8'h49;
                        5'd8: lccc_line2_mask = 8'h50;
                        default: lccc_line2_mask = 8'h00;
                    endcase
                end
                8'd6: begin
                    case (chunk)
                        5'd0: lccc_line2_mask = 8'h64;
                        5'd1: lccc_line2_mask = 8'h8a;
                        5'd2: lccc_line2_mask = 8'h39;
                        5'd3: lccc_line2_mask = 8'h3a;
                        5'd4: lccc_line2_mask = 8'h4d;
                        5'd5: lccc_line2_mask = 8'hc1;
                        5'd6: lccc_line2_mask = 8'hba;
                        5'd7: lccc_line2_mask = 8'h49;
                        5'd8: lccc_line2_mask = 8'h5c;
                        default: lccc_line2_mask = 8'h00;
                    endcase
                end
                default: lccc_line2_mask = 8'h00;
            endcase
        end
    endfunction

    function [7:0] go_ribbon_mask;
        input [7:0] row;
        input [4:0] chunk;
        begin
            go_ribbon_mask = 8'h00;
            case (row)
                8'd3: begin
                    case (chunk)
                        5'd8: go_ribbon_mask = 8'h10;
                        default: go_ribbon_mask = 8'h00;
                    endcase
                end
                8'd4: begin
                    case (chunk)
                        5'd8: go_ribbon_mask = 8'hf0;
                        default: go_ribbon_mask = 8'h00;
                    endcase
                end
                8'd5: begin
                    case (chunk)
                        5'd7: go_ribbon_mask = 8'h07;
                        5'd8: go_ribbon_mask = 8'hf0;
                        default: go_ribbon_mask = 8'h00;
                    endcase
                end
                8'd6: begin
                    case (chunk)
                        5'd7: go_ribbon_mask = 8'h3f;
                        5'd8: go_ribbon_mask = 8'hf0;
                        default: go_ribbon_mask = 8'h00;
                    endcase
                end
                8'd7: begin
                    case (chunk)
                        5'd6: go_ribbon_mask = 8'h01;
                        5'd7: go_ribbon_mask = 8'hff;
                        5'd8: go_ribbon_mask = 8'hf0;
                        default: go_ribbon_mask = 8'h00;
                    endcase
                end
                8'd8: begin
                    case (chunk)
                        5'd6: go_ribbon_mask = 8'h0f;
                        5'd7: go_ribbon_mask = 8'hff;
                        5'd8: go_ribbon_mask = 8'hf0;
                        default: go_ribbon_mask = 8'h00;
                    endcase
                end
                8'd9: begin
                    case (chunk)
                        5'd6: go_ribbon_mask = 8'h3f;
                        5'd7: go_ribbon_mask = 8'hff;
                        5'd8: go_ribbon_mask = 8'hf0;
                        default: go_ribbon_mask = 8'h00;
                    endcase
                end
                8'd10: begin
                    case (chunk)
                        5'd5: go_ribbon_mask = 8'h01;
                        5'd6: go_ribbon_mask = 8'hff;
                        5'd7: go_ribbon_mask = 8'hff;
                        5'd8: go_ribbon_mask = 8'hf0;
                        default: go_ribbon_mask = 8'h00;
                    endcase
                end
                8'd11: begin
                    case (chunk)
                        5'd5: go_ribbon_mask = 8'h0f;
                        5'd6: go_ribbon_mask = 8'hff;
                        5'd7: go_ribbon_mask = 8'hff;
                        5'd8: go_ribbon_mask = 8'hf0;
                        default: go_ribbon_mask = 8'h00;
                    endcase
                end
                8'd12: begin
                    case (chunk)
                        5'd5: go_ribbon_mask = 8'h7f;
                        5'd6: go_ribbon_mask = 8'hff;
                        5'd7: go_ribbon_mask = 8'hff;
                        5'd8: go_ribbon_mask = 8'hf0;
                        default: go_ribbon_mask = 8'h00;
                    endcase
                end
                8'd13: begin
                    case (chunk)
                        5'd4: go_ribbon_mask = 8'h03;
                        5'd5: go_ribbon_mask = 8'hff;
                        5'd6: go_ribbon_mask = 8'hff;
                        5'd7: go_ribbon_mask = 8'hff;
                        5'd8: go_ribbon_mask = 8'hf0;
                        default: go_ribbon_mask = 8'h00;
                    endcase
                end
                8'd14: begin
                    case (chunk)
                        5'd4: go_ribbon_mask = 8'h1f;
                        5'd5: go_ribbon_mask = 8'hff;
                        5'd6: go_ribbon_mask = 8'hff;
                        5'd7: go_ribbon_mask = 8'hff;
                        5'd8: go_ribbon_mask = 8'hf0;
                        default: go_ribbon_mask = 8'h00;
                    endcase
                end
                8'd15: begin
                    case (chunk)
                        5'd4: go_ribbon_mask = 8'hff;
                        5'd5: go_ribbon_mask = 8'hff;
                        5'd6: go_ribbon_mask = 8'hff;
                        5'd7: go_ribbon_mask = 8'hff;
                        5'd8: go_ribbon_mask = 8'hf0;
                        default: go_ribbon_mask = 8'h00;
                    endcase
                end
                8'd16: begin
                    case (chunk)
                        5'd3: go_ribbon_mask = 8'h07;
                        5'd4: go_ribbon_mask = 8'hff;
                        5'd5: go_ribbon_mask = 8'hff;
                        5'd6: go_ribbon_mask = 8'hff;
                        5'd7: go_ribbon_mask = 8'hff;
                        5'd8: go_ribbon_mask = 8'hf0;
                        default: go_ribbon_mask = 8'h00;
                    endcase
                end
                8'd17: begin
                    case (chunk)
                        5'd3: go_ribbon_mask = 8'h3f;
                        5'd4: go_ribbon_mask = 8'hff;
                        5'd5: go_ribbon_mask = 8'hff;
                        5'd6: go_ribbon_mask = 8'hff;
                        5'd7: go_ribbon_mask = 8'hff;
                        5'd8: go_ribbon_mask = 8'hf0;
                        default: go_ribbon_mask = 8'h00;
                    endcase
                end
                8'd18: begin
                    case (chunk)
                        5'd2: go_ribbon_mask = 8'h01;
                        5'd3: go_ribbon_mask = 8'hff;
                        5'd4: go_ribbon_mask = 8'hff;
                        5'd5: go_ribbon_mask = 8'hff;
                        5'd6: go_ribbon_mask = 8'hff;
                        5'd7: go_ribbon_mask = 8'hff;
                        5'd8: go_ribbon_mask = 8'hf0;
                        default: go_ribbon_mask = 8'h00;
                    endcase
                end
                8'd19: begin
                    case (chunk)
                        5'd2: go_ribbon_mask = 8'h0f;
                        5'd3: go_ribbon_mask = 8'hff;
                        5'd4: go_ribbon_mask = 8'hff;
                        5'd5: go_ribbon_mask = 8'hff;
                        5'd6: go_ribbon_mask = 8'hff;
                        5'd7: go_ribbon_mask = 8'hff;
                        5'd8: go_ribbon_mask = 8'hf0;
                        default: go_ribbon_mask = 8'h00;
                    endcase
                end
                8'd20: begin
                    case (chunk)
                        5'd2: go_ribbon_mask = 8'h7f;
                        5'd3: go_ribbon_mask = 8'hff;
                        5'd4: go_ribbon_mask = 8'hff;
                        5'd5: go_ribbon_mask = 8'hff;
                        5'd6: go_ribbon_mask = 8'hff;
                        5'd7: go_ribbon_mask = 8'hff;
                        5'd8: go_ribbon_mask = 8'hf0;
                        default: go_ribbon_mask = 8'h00;
                    endcase
                end
                8'd21: begin
                    case (chunk)
                        5'd1: go_ribbon_mask = 8'h01;
                        5'd2: go_ribbon_mask = 8'hff;
                        5'd3: go_ribbon_mask = 8'hff;
                        5'd4: go_ribbon_mask = 8'hff;
                        5'd5: go_ribbon_mask = 8'hff;
                        5'd6: go_ribbon_mask = 8'hff;
                        5'd7: go_ribbon_mask = 8'hff;
                        5'd8: go_ribbon_mask = 8'hf0;
                        default: go_ribbon_mask = 8'h00;
                    endcase
                end
                8'd22: begin
                    case (chunk)
                        5'd1: go_ribbon_mask = 8'h0f;
                        5'd2: go_ribbon_mask = 8'hff;
                        5'd3: go_ribbon_mask = 8'hff;
                        5'd4: go_ribbon_mask = 8'hff;
                        5'd5: go_ribbon_mask = 8'hff;
                        5'd6: go_ribbon_mask = 8'hff;
                        5'd7: go_ribbon_mask = 8'hff;
                        5'd8: go_ribbon_mask = 8'hf0;
                        default: go_ribbon_mask = 8'h00;
                    endcase
                end
                8'd23: begin
                    case (chunk)
                        5'd1: go_ribbon_mask = 8'h7f;
                        5'd2: go_ribbon_mask = 8'hff;
                        5'd3: go_ribbon_mask = 8'hff;
                        5'd4: go_ribbon_mask = 8'hff;
                        5'd5: go_ribbon_mask = 8'hff;
                        5'd6: go_ribbon_mask = 8'hff;
                        5'd7: go_ribbon_mask = 8'hff;
                        5'd8: go_ribbon_mask = 8'hf0;
                        default: go_ribbon_mask = 8'h00;
                    endcase
                end
                8'd24: begin
                    case (chunk)
                        5'd0: go_ribbon_mask = 8'h03;
                        5'd1: go_ribbon_mask = 8'hff;
                        5'd2: go_ribbon_mask = 8'hff;
                        5'd3: go_ribbon_mask = 8'hff;
                        5'd4: go_ribbon_mask = 8'hff;
                        5'd5: go_ribbon_mask = 8'hff;
                        5'd6: go_ribbon_mask = 8'hff;
                        5'd7: go_ribbon_mask = 8'hff;
                        5'd8: go_ribbon_mask = 8'hf0;
                        default: go_ribbon_mask = 8'h00;
                    endcase
                end
                8'd25: begin
                    case (chunk)
                        5'd0: go_ribbon_mask = 8'h1f;
                        5'd1: go_ribbon_mask = 8'hff;
                        5'd2: go_ribbon_mask = 8'hff;
                        5'd3: go_ribbon_mask = 8'hff;
                        5'd4: go_ribbon_mask = 8'hff;
                        5'd5: go_ribbon_mask = 8'hff;
                        5'd6: go_ribbon_mask = 8'hff;
                        5'd7: go_ribbon_mask = 8'hff;
                        5'd8: go_ribbon_mask = 8'hf0;
                        default: go_ribbon_mask = 8'h00;
                    endcase
                end
                8'd26, 8'd27, 8'd28, 8'd29, 8'd30, 8'd31, 8'd32: begin
                    case (chunk)
                        5'd0: go_ribbon_mask = 8'hff;
                        5'd1: go_ribbon_mask = 8'hff;
                        5'd2: go_ribbon_mask = 8'hff;
                        5'd3: go_ribbon_mask = 8'hff;
                        5'd4: go_ribbon_mask = 8'hff;
                        5'd5: go_ribbon_mask = 8'hff;
                        5'd6: go_ribbon_mask = 8'hff;
                        5'd7: go_ribbon_mask = 8'hff;
                        5'd8: go_ribbon_mask = 8'hf0;
                        default: go_ribbon_mask = 8'h00;
                    endcase
                end
                8'd33: begin
                    case (chunk)
                        5'd0: go_ribbon_mask = 8'hff;
                        5'd1: go_ribbon_mask = 8'hff;
                        5'd2: go_ribbon_mask = 8'hff;
                        5'd3: go_ribbon_mask = 8'hff;
                        5'd4: go_ribbon_mask = 8'hff;
                        5'd5: go_ribbon_mask = 8'hff;
                        5'd6: go_ribbon_mask = 8'hff;
                        5'd7: go_ribbon_mask = 8'hfe;
                        default: go_ribbon_mask = 8'h00;
                    endcase
                end
                8'd34: begin
                    case (chunk)
                        5'd0: go_ribbon_mask = 8'hff;
                        5'd1: go_ribbon_mask = 8'hff;
                        5'd2: go_ribbon_mask = 8'hff;
                        5'd3: go_ribbon_mask = 8'hff;
                        5'd4: go_ribbon_mask = 8'hff;
                        5'd5: go_ribbon_mask = 8'hff;
                        5'd6: go_ribbon_mask = 8'hff;
                        5'd7: go_ribbon_mask = 8'hc0;
                        default: go_ribbon_mask = 8'h00;
                    endcase
                end
                8'd35: begin
                    case (chunk)
                        5'd0: go_ribbon_mask = 8'hff;
                        5'd1: go_ribbon_mask = 8'hff;
                        5'd2: go_ribbon_mask = 8'hff;
                        5'd3: go_ribbon_mask = 8'hff;
                        5'd4: go_ribbon_mask = 8'hff;
                        5'd5: go_ribbon_mask = 8'hff;
                        5'd6: go_ribbon_mask = 8'hf8;
                        default: go_ribbon_mask = 8'h00;
                    endcase
                end
                8'd36: begin
                    case (chunk)
                        5'd0: go_ribbon_mask = 8'hff;
                        5'd1: go_ribbon_mask = 8'hff;
                        5'd2: go_ribbon_mask = 8'hff;
                        5'd3: go_ribbon_mask = 8'hff;
                        5'd4: go_ribbon_mask = 8'hff;
                        5'd5: go_ribbon_mask = 8'hfe;
                        default: go_ribbon_mask = 8'h00;
                    endcase
                end
                8'd37: begin
                    case (chunk)
                        5'd0: go_ribbon_mask = 8'hff;
                        5'd1: go_ribbon_mask = 8'hff;
                        5'd2: go_ribbon_mask = 8'hff;
                        5'd3: go_ribbon_mask = 8'hff;
                        5'd4: go_ribbon_mask = 8'hff;
                        5'd5: go_ribbon_mask = 8'hc0;
                        default: go_ribbon_mask = 8'h00;
                    endcase
                end
                8'd38: begin
                    case (chunk)
                        5'd0: go_ribbon_mask = 8'hff;
                        5'd1: go_ribbon_mask = 8'hff;
                        5'd2: go_ribbon_mask = 8'hff;
                        5'd3: go_ribbon_mask = 8'hff;
                        5'd4: go_ribbon_mask = 8'hf8;
                        default: go_ribbon_mask = 8'h00;
                    endcase
                end
                8'd39: begin
                    case (chunk)
                        5'd0: go_ribbon_mask = 8'hff;
                        5'd1: go_ribbon_mask = 8'hff;
                        5'd2: go_ribbon_mask = 8'hff;
                        5'd3: go_ribbon_mask = 8'hff;
                        default: go_ribbon_mask = 8'h00;
                    endcase
                end
                8'd40: begin
                    case (chunk)
                        5'd0: go_ribbon_mask = 8'hff;
                        5'd1: go_ribbon_mask = 8'hff;
                        5'd2: go_ribbon_mask = 8'hff;
                        5'd3: go_ribbon_mask = 8'he0;
                        default: go_ribbon_mask = 8'h00;
                    endcase
                end
                8'd41: begin
                    case (chunk)
                        5'd0: go_ribbon_mask = 8'hff;
                        5'd1: go_ribbon_mask = 8'hff;
                        5'd2: go_ribbon_mask = 8'hfc;
                        default: go_ribbon_mask = 8'h00;
                    endcase
                end
                8'd42: begin
                    case (chunk)
                        5'd0: go_ribbon_mask = 8'hff;
                        5'd1: go_ribbon_mask = 8'hff;
                        default: go_ribbon_mask = 8'h00;
                    endcase
                end
                8'd43: begin
                    case (chunk)
                        5'd0: go_ribbon_mask = 8'hff;
                        5'd1: go_ribbon_mask = 8'he0;
                        default: go_ribbon_mask = 8'h00;
                    endcase
                end
                8'd44: begin
                    case (chunk)
                        5'd0: go_ribbon_mask = 8'hfc;
                        default: go_ribbon_mask = 8'h00;
                    endcase
                end
                8'd45: begin
                    case (chunk)
                        5'd0: go_ribbon_mask = 8'h80;
                        default: go_ribbon_mask = 8'h00;
                    endcase
                end
                default: go_ribbon_mask = 8'h00;
            endcase
        end
    endfunction

    function [7:0] go_letters_mask;
        input [7:0] row;
        input [4:0] chunk;
        begin
            go_letters_mask = 8'h00;
            case (row)
                8'd1: begin
                    case (chunk)
                        5'd2: go_letters_mask = 8'h78;
                        5'd5: go_letters_mask = 8'h07;
                        5'd6: go_letters_mask = 8'hf8;
                        default: go_letters_mask = 8'h00;
                    endcase
                end
                8'd2: begin
                    case (chunk)
                        5'd1: go_letters_mask = 8'h03;
                        5'd2: go_letters_mask = 8'hf8;
                        5'd5: go_letters_mask = 8'h1f;
                        5'd6: go_letters_mask = 8'hfe;
                        default: go_letters_mask = 8'h00;
                    endcase
                end
                8'd3: begin
                    case (chunk)
                        5'd1: go_letters_mask = 8'h07;
                        5'd2: go_letters_mask = 8'hf8;
                        5'd5: go_letters_mask = 8'h7f;
                        5'd6: go_letters_mask = 8'hff;
                        5'd7: go_letters_mask = 8'h80;
                        default: go_letters_mask = 8'h00;
                    endcase
                end
                8'd4: begin
                    case (chunk)
                        5'd1: go_letters_mask = 8'h0f;
                        5'd2: go_letters_mask = 8'h80;
                        5'd5: go_letters_mask = 8'hfc;
                        5'd6: go_letters_mask = 8'h0f;
                        5'd7: go_letters_mask = 8'hc0;
                        default: go_letters_mask = 8'h00;
                    endcase
                end
                8'd5: begin
                    case (chunk)
                        5'd1: go_letters_mask = 8'h1e;
                        5'd4: go_letters_mask = 8'h01;
                        5'd5: go_letters_mask = 8'he0;
                        5'd6: go_letters_mask = 8'h01;
                        5'd7: go_letters_mask = 8'he0;
                        default: go_letters_mask = 8'h00;
                    endcase
                end
                8'd6: begin
                    case (chunk)
                        5'd1: go_letters_mask = 8'h3c;
                        5'd4: go_letters_mask = 8'h03;
                        5'd5: go_letters_mask = 8'hc0;
                        5'd7: go_letters_mask = 8'hf0;
                        default: go_letters_mask = 8'h00;
                    endcase
                end
                8'd7: begin
                    case (chunk)
                        5'd1: go_letters_mask = 8'h78;
                        5'd4: go_letters_mask = 8'h07;
                        5'd5: go_letters_mask = 8'h80;
                        5'd7: go_letters_mask = 8'h78;
                        default: go_letters_mask = 8'h00;
                    endcase
                end
                8'd8: begin
                    case (chunk)
                        5'd1: go_letters_mask = 8'hf0;
                        5'd4: go_letters_mask = 8'h07;
                        5'd7: go_letters_mask = 8'h38;
                        default: go_letters_mask = 8'h00;
                    endcase
                end
                8'd9, 8'd10: begin
                    case (chunk)
                        5'd1: go_letters_mask = 8'he0;
                        5'd4: go_letters_mask = 8'h0e;
                        5'd7: go_letters_mask = 8'h1c;
                        default: go_letters_mask = 8'h00;
                    endcase
                end
                8'd11, 8'd12, 8'd13: begin
                    case (chunk)
                        5'd0: go_letters_mask = 8'h01;
                        5'd1: go_letters_mask = 8'hc0;
                        5'd4: go_letters_mask = 8'h1c;
                        5'd7: go_letters_mask = 8'h0e;
                        default: go_letters_mask = 8'h00;
                    endcase
                end
                8'd14, 8'd15, 8'd16: begin
                    case (chunk)
                        5'd0: go_letters_mask = 8'h01;
                        5'd1: go_letters_mask = 8'hc0;
                        5'd2: go_letters_mask = 8'h0f;
                        5'd3: go_letters_mask = 8'hff;
                        5'd4: go_letters_mask = 8'hdc;
                        5'd7: go_letters_mask = 8'h0e;
                        default: go_letters_mask = 8'h00;
                    endcase
                end
                8'd17: begin
                    case (chunk)
                        5'd0: go_letters_mask = 8'h01;
                        5'd1: go_letters_mask = 8'hc0;
                        5'd3: go_letters_mask = 8'h01;
                        5'd4: go_letters_mask = 8'hdc;
                        5'd7: go_letters_mask = 8'h0e;
                        default: go_letters_mask = 8'h00;
                    endcase
                end
                8'd18, 8'd19: begin
                    case (chunk)
                        5'd1: go_letters_mask = 8'he0;
                        5'd3: go_letters_mask = 8'h03;
                        5'd4: go_letters_mask = 8'hce;
                        5'd7: go_letters_mask = 8'h1c;
                        default: go_letters_mask = 8'h00;
                    endcase
                end
                8'd20: begin
                    case (chunk)
                        5'd1: go_letters_mask = 8'hf0;
                        5'd3: go_letters_mask = 8'h07;
                        5'd4: go_letters_mask = 8'hc7;
                        5'd7: go_letters_mask = 8'h38;
                        default: go_letters_mask = 8'h00;
                    endcase
                end
                8'd21: begin
                    case (chunk)
                        5'd1: go_letters_mask = 8'h78;
                        5'd3: go_letters_mask = 8'h0f;
                        5'd4: go_letters_mask = 8'hc7;
                        5'd5: go_letters_mask = 8'h80;
                        5'd7: go_letters_mask = 8'h78;
                        default: go_letters_mask = 8'h00;
                    endcase
                end
                8'd22: begin
                    case (chunk)
                        5'd1: go_letters_mask = 8'h3c;
                        5'd3: go_letters_mask = 8'h1f;
                        5'd4: go_letters_mask = 8'hc3;
                        5'd5: go_letters_mask = 8'hc0;
                        5'd7: go_letters_mask = 8'hf0;
                        default: go_letters_mask = 8'h00;
                    endcase
                end
                8'd23: begin
                    case (chunk)
                        5'd1: go_letters_mask = 8'h1e;
                        5'd3: go_letters_mask = 8'h3c;
                        5'd4: go_letters_mask = 8'h01;
                        5'd5: go_letters_mask = 8'he0;
                        5'd6: go_letters_mask = 8'h01;
                        5'd7: go_letters_mask = 8'he0;
                        default: go_letters_mask = 8'h00;
                    endcase
                end
                8'd24: begin
                    case (chunk)
                        5'd1: go_letters_mask = 8'h0f;
                        5'd2: go_letters_mask = 8'h80;
                        5'd3: go_letters_mask = 8'hf8;
                        5'd5: go_letters_mask = 8'hfc;
                        5'd6: go_letters_mask = 8'h0f;
                        5'd7: go_letters_mask = 8'hc0;
                        default: go_letters_mask = 8'h00;
                    endcase
                end
                8'd25: begin
                    case (chunk)
                        5'd1: go_letters_mask = 8'h07;
                        5'd2: go_letters_mask = 8'hff;
                        5'd3: go_letters_mask = 8'hf0;
                        5'd5: go_letters_mask = 8'h7f;
                        5'd6: go_letters_mask = 8'hff;
                        5'd7: go_letters_mask = 8'h80;
                        default: go_letters_mask = 8'h00;
                    endcase
                end
                8'd26: begin
                    case (chunk)
                        5'd1: go_letters_mask = 8'h03;
                        5'd2: go_letters_mask = 8'hff;
                        5'd3: go_letters_mask = 8'he0;
                        5'd5: go_letters_mask = 8'h1f;
                        5'd6: go_letters_mask = 8'hfe;
                        default: go_letters_mask = 8'h00;
                    endcase
                end
                8'd27: begin
                    case (chunk)
                        5'd2: go_letters_mask = 8'h7f;
                        5'd5: go_letters_mask = 8'h07;
                        5'd6: go_letters_mask = 8'hf8;
                        default: go_letters_mask = 8'h00;
                    endcase
                end
                8'd32: begin
                    case (chunk)
                        5'd0: go_letters_mask = 8'h07;
                        5'd1: go_letters_mask = 8'h8e;
                        5'd2: go_letters_mask = 8'h7c;
                        5'd3: go_letters_mask = 8'he4;
                        5'd4: go_letters_mask = 8'h5c;
                        5'd5: go_letters_mask = 8'hf3;
                        5'd6: go_letters_mask = 8'h90;
                        5'd7: go_letters_mask = 8'h3c;
                        default: go_letters_mask = 8'h00;
                    endcase
                end
                8'd33: begin
                    case (chunk)
                        5'd0: go_letters_mask = 8'h04;
                        5'd1: go_letters_mask = 8'h51;
                        5'd2: go_letters_mask = 8'h11;
                        5'd3: go_letters_mask = 8'h16;
                        5'd4: go_letters_mask = 8'h49;
                        5'd5: go_letters_mask = 8'h04;
                        5'd6: go_letters_mask = 8'h50;
                        5'd7: go_letters_mask = 8'h40;
                        default: go_letters_mask = 8'h00;
                    endcase
                end
                8'd34: begin
                    case (chunk)
                        5'd0: go_letters_mask = 8'h04;
                        5'd1: go_letters_mask = 8'h51;
                        5'd2: go_letters_mask = 8'h11;
                        5'd3: go_letters_mask = 8'h15;
                        5'd4: go_letters_mask = 8'h49;
                        5'd5: go_letters_mask = 8'h04;
                        5'd6: go_letters_mask = 8'h50;
                        5'd7: go_letters_mask = 8'h40;
                        default: go_letters_mask = 8'h00;
                    endcase
                end
                8'd35: begin
                    case (chunk)
                        5'd0: go_letters_mask = 8'h07;
                        5'd1: go_letters_mask = 8'h91;
                        5'd2: go_letters_mask = 8'h11;
                        5'd3: go_letters_mask = 8'hf4;
                        5'd4: go_letters_mask = 8'hc9;
                        5'd5: go_letters_mask = 8'h07;
                        5'd6: go_letters_mask = 8'hd0;
                        5'd7: go_letters_mask = 8'h38;
                        default: go_letters_mask = 8'h00;
                    endcase
                end
                8'd36, 8'd37: begin
                    case (chunk)
                        5'd0: go_letters_mask = 8'h04;
                        5'd1: go_letters_mask = 8'h51;
                        5'd2: go_letters_mask = 8'h11;
                        5'd3: go_letters_mask = 8'h14;
                        5'd4: go_letters_mask = 8'h49;
                        5'd5: go_letters_mask = 8'h04;
                        5'd6: go_letters_mask = 8'h50;
                        5'd7: go_letters_mask = 8'h04;
                        default: go_letters_mask = 8'h00;
                    endcase
                end
                8'd38: begin
                    case (chunk)
                        5'd0: go_letters_mask = 8'h07;
                        5'd1: go_letters_mask = 8'h8e;
                        5'd2: go_letters_mask = 8'h11;
                        5'd3: go_letters_mask = 8'h14;
                        5'd4: go_letters_mask = 8'h5c;
                        5'd5: go_letters_mask = 8'hf4;
                        5'd6: go_letters_mask = 8'h5f;
                        5'd7: go_letters_mask = 8'h78;
                        default: go_letters_mask = 8'h00;
                    endcase
                end
                default: go_letters_mask = 8'h00;
            endcase
        end
    endfunction

    function [7:0] brumo_loop_mask;
        input [7:0] row;
        input [4:0] chunk;
        begin
            brumo_loop_mask = 8'h00;
            case (row)
                8'd1: begin
                    case (chunk)
                        5'd1: brumo_loop_mask = 8'h1f;
                        5'd2: brumo_loop_mask = 8'hc0;
                        default: brumo_loop_mask = 8'h00;
                    endcase
                end
                8'd2: begin
                    case (chunk)
                        5'd1: brumo_loop_mask = 8'h7f;
                        5'd2: brumo_loop_mask = 8'hf0;
                        default: brumo_loop_mask = 8'h00;
                    endcase
                end
                8'd3: begin
                    case (chunk)
                        5'd0: brumo_loop_mask = 8'h01;
                        5'd1: brumo_loop_mask = 8'hff;
                        5'd2: brumo_loop_mask = 8'hfc;
                        default: brumo_loop_mask = 8'h00;
                    endcase
                end
                8'd4: begin
                    case (chunk)
                        5'd0: brumo_loop_mask = 8'h03;
                        5'd1: brumo_loop_mask = 8'hff;
                        5'd2: brumo_loop_mask = 8'hfa;
                        default: brumo_loop_mask = 8'h00;
                    endcase
                end
                8'd5: begin
                    case (chunk)
                        5'd0: brumo_loop_mask = 8'h07;
                        5'd1: brumo_loop_mask = 8'hff;
                        5'd2: brumo_loop_mask = 8'hff;
                        default: brumo_loop_mask = 8'h00;
                    endcase
                end
                8'd6: begin
                    case (chunk)
                        5'd0: brumo_loop_mask = 8'h07;
                        5'd1: brumo_loop_mask = 8'hf0;
                        5'd2: brumo_loop_mask = 8'h7f;
                        default: brumo_loop_mask = 8'h00;
                    endcase
                end
                8'd7: begin
                    case (chunk)
                        5'd0: brumo_loop_mask = 8'h0f;
                        5'd1: brumo_loop_mask = 8'hc0;
                        5'd2: brumo_loop_mask = 8'h1f;
                        5'd3: brumo_loop_mask = 8'h80;
                        default: brumo_loop_mask = 8'h00;
                    endcase
                end
                8'd8, 8'd9: begin
                    case (chunk)
                        5'd0: brumo_loop_mask = 8'h1f;
                        5'd1: brumo_loop_mask = 8'h80;
                        5'd2: brumo_loop_mask = 8'h0f;
                        5'd3: brumo_loop_mask = 8'hc0;
                        default: brumo_loop_mask = 8'h00;
                    endcase
                end
                8'd10: begin
                    case (chunk)
                        5'd0: brumo_loop_mask = 8'h1f;
                        5'd2: brumo_loop_mask = 8'h07;
                        5'd3: brumo_loop_mask = 8'hc0;
                        default: brumo_loop_mask = 8'h00;
                    endcase
                end
                8'd11: begin
                    case (chunk)
                        5'd0: brumo_loop_mask = 8'h1e;
                        5'd2: brumo_loop_mask = 8'h03;
                        5'd3: brumo_loop_mask = 8'hc0;
                        default: brumo_loop_mask = 8'h00;
                    endcase
                end
                8'd12: begin
                    case (chunk)
                        5'd0: brumo_loop_mask = 8'h3e;
                        5'd2: brumo_loop_mask = 8'h03;
                        5'd3: brumo_loop_mask = 8'he0;
                        default: brumo_loop_mask = 8'h00;
                    endcase
                end
                8'd13, 8'd14, 8'd15, 8'd16, 8'd17, 8'd18, 8'd19, 8'd20, 8'd21: begin
                    case (chunk)
                        5'd0: brumo_loop_mask = 8'h3e;
                        5'd1: brumo_loop_mask = 8'h0f;
                        5'd2: brumo_loop_mask = 8'h83;
                        5'd3: brumo_loop_mask = 8'he0;
                        default: brumo_loop_mask = 8'h00;
                    endcase
                end
                8'd22: begin
                    case (chunk)
                        5'd0: brumo_loop_mask = 8'h3e;
                        5'd1: brumo_loop_mask = 8'h0f;
                        5'd2: brumo_loop_mask = 8'h83;
                        5'd3: brumo_loop_mask = 8'hfe;
                        default: brumo_loop_mask = 8'h00;
                    endcase
                end
                8'd23: begin
                    case (chunk)
                        5'd0: brumo_loop_mask = 8'h3e;
                        5'd1: brumo_loop_mask = 8'h0f;
                        5'd2: brumo_loop_mask = 8'h83;
                        5'd3: brumo_loop_mask = 8'hff;
                        5'd4: brumo_loop_mask = 8'h80;
                        default: brumo_loop_mask = 8'h00;
                    endcase
                end
                8'd24: begin
                    case (chunk)
                        5'd0: brumo_loop_mask = 8'h3e;
                        5'd1: brumo_loop_mask = 8'h0f;
                        5'd2: brumo_loop_mask = 8'h83;
                        5'd3: brumo_loop_mask = 8'hff;
                        5'd4: brumo_loop_mask = 8'he0;
                        default: brumo_loop_mask = 8'h00;
                    endcase
                end
                8'd25: begin
                    case (chunk)
                        5'd0: brumo_loop_mask = 8'h3e;
                        5'd1: brumo_loop_mask = 8'h0f;
                        5'd2: brumo_loop_mask = 8'h83;
                        5'd3: brumo_loop_mask = 8'hff;
                        5'd4: brumo_loop_mask = 8'hd0;
                        default: brumo_loop_mask = 8'h00;
                    endcase
                end
                8'd26: begin
                    case (chunk)
                        5'd0: brumo_loop_mask = 8'h3e;
                        5'd1: brumo_loop_mask = 8'h0f;
                        5'd2: brumo_loop_mask = 8'h83;
                        5'd3: brumo_loop_mask = 8'hff;
                        5'd4: brumo_loop_mask = 8'hf8;
                        default: brumo_loop_mask = 8'h00;
                    endcase
                end
                8'd27: begin
                    case (chunk)
                        5'd0: brumo_loop_mask = 8'h3e;
                        5'd1: brumo_loop_mask = 8'h0f;
                        5'd2: brumo_loop_mask = 8'h83;
                        5'd3: brumo_loop_mask = 8'he3;
                        5'd4: brumo_loop_mask = 8'hf8;
                        default: brumo_loop_mask = 8'h00;
                    endcase
                end
                8'd28, 8'd29: begin
                    case (chunk)
                        5'd0: brumo_loop_mask = 8'h3e;
                        5'd1: brumo_loop_mask = 8'h0f;
                        5'd2: brumo_loop_mask = 8'h83;
                        5'd3: brumo_loop_mask = 8'he0;
                        5'd4: brumo_loop_mask = 8'hfc;
                        default: brumo_loop_mask = 8'h00;
                    endcase
                end
                8'd30, 8'd31, 8'd32, 8'd33, 8'd34, 8'd35, 8'd36, 8'd37: begin
                    case (chunk)
                        5'd0: brumo_loop_mask = 8'h3e;
                        5'd1: brumo_loop_mask = 8'h0f;
                        5'd2: brumo_loop_mask = 8'h83;
                        5'd3: brumo_loop_mask = 8'he0;
                        5'd4: brumo_loop_mask = 8'h7c;
                        default: brumo_loop_mask = 8'h00;
                    endcase
                end
                8'd38, 8'd39, 8'd40, 8'd41: begin
                    case (chunk)
                        5'd1: brumo_loop_mask = 8'h0f;
                        5'd2: brumo_loop_mask = 8'h80;
                        5'd4: brumo_loop_mask = 8'h7c;
                        default: brumo_loop_mask = 8'h00;
                    endcase
                end
                8'd42: begin
                    case (chunk)
                        5'd1: brumo_loop_mask = 8'h07;
                        5'd2: brumo_loop_mask = 8'h80;
                        5'd4: brumo_loop_mask = 8'h78;
                        default: brumo_loop_mask = 8'h00;
                    endcase
                end
                8'd43: begin
                    case (chunk)
                        5'd1: brumo_loop_mask = 8'h07;
                        5'd2: brumo_loop_mask = 8'hc0;
                        5'd4: brumo_loop_mask = 8'hf8;
                        default: brumo_loop_mask = 8'h00;
                    endcase
                end
                8'd44, 8'd45: begin
                    case (chunk)
                        5'd1: brumo_loop_mask = 8'h07;
                        5'd2: brumo_loop_mask = 8'he0;
                        5'd3: brumo_loop_mask = 8'h01;
                        5'd4: brumo_loop_mask = 8'hf8;
                        default: brumo_loop_mask = 8'h00;
                    endcase
                end
                8'd46: begin
                    case (chunk)
                        5'd1: brumo_loop_mask = 8'h03;
                        5'd2: brumo_loop_mask = 8'hf0;
                        5'd3: brumo_loop_mask = 8'h03;
                        5'd4: brumo_loop_mask = 8'hf0;
                        default: brumo_loop_mask = 8'h00;
                    endcase
                end
                8'd47: begin
                    case (chunk)
                        5'd1: brumo_loop_mask = 8'h01;
                        5'd2: brumo_loop_mask = 8'hfc;
                        5'd3: brumo_loop_mask = 8'h0f;
                        5'd4: brumo_loop_mask = 8'he0;
                        default: brumo_loop_mask = 8'h00;
                    endcase
                end
                8'd48: begin
                    case (chunk)
                        5'd1: brumo_loop_mask = 8'h01;
                        5'd2: brumo_loop_mask = 8'hff;
                        5'd3: brumo_loop_mask = 8'hff;
                        5'd4: brumo_loop_mask = 8'he0;
                        default: brumo_loop_mask = 8'h00;
                    endcase
                end
                8'd49: begin
                    case (chunk)
                        5'd2: brumo_loop_mask = 8'hff;
                        5'd3: brumo_loop_mask = 8'hff;
                        5'd4: brumo_loop_mask = 8'h40;
                        default: brumo_loop_mask = 8'h00;
                    endcase
                end
                8'd50: begin
                    case (chunk)
                        5'd2: brumo_loop_mask = 8'h7f;
                        5'd3: brumo_loop_mask = 8'hff;
                        5'd4: brumo_loop_mask = 8'h80;
                        default: brumo_loop_mask = 8'h00;
                    endcase
                end
                8'd51: begin
                    case (chunk)
                        5'd2: brumo_loop_mask = 8'h1f;
                        5'd3: brumo_loop_mask = 8'hfe;
                        default: brumo_loop_mask = 8'h00;
                    endcase
                end
                8'd52: begin
                    case (chunk)
                        5'd2: brumo_loop_mask = 8'h07;
                        5'd3: brumo_loop_mask = 8'hf8;
                        default: brumo_loop_mask = 8'h00;
                    endcase
                end
                default: brumo_loop_mask = 8'h00;
            endcase
        end
    endfunction

    function [7:0] brumo_wordmark_mask;
        input [7:0] row;
        input [4:0] chunk;
        begin
            brumo_wordmark_mask = 8'h00;
            case (row)
                8'd0, 8'd1: begin
                    case (chunk)
                        5'd0: brumo_wordmark_mask = 8'h80;
                        default: brumo_wordmark_mask = 8'h00;
                    endcase
                end
                8'd2: begin
                    case (chunk)
                        5'd0: brumo_wordmark_mask = 8'hb2;
                        5'd1: brumo_wordmark_mask = 8'hc8;
                        5'd2: brumo_wordmark_mask = 8'hb5;
                        5'd3: brumo_wordmark_mask = 8'h1c;
                        default: brumo_wordmark_mask = 8'h00;
                    endcase
                end
                8'd3: begin
                    case (chunk)
                        5'd0: brumo_wordmark_mask = 8'hcb;
                        5'd1: brumo_wordmark_mask = 8'h28;
                        5'd2: brumo_wordmark_mask = 8'haa;
                        5'd3: brumo_wordmark_mask = 8'ha2;
                        default: brumo_wordmark_mask = 8'h00;
                    endcase
                end
                8'd4: begin
                    case (chunk)
                        5'd0: brumo_wordmark_mask = 8'h8a;
                        5'd1: brumo_wordmark_mask = 8'h08;
                        5'd2: brumo_wordmark_mask = 8'haa;
                        5'd3: brumo_wordmark_mask = 8'ha2;
                        default: brumo_wordmark_mask = 8'h00;
                    endcase
                end
                8'd5: begin
                    case (chunk)
                        5'd0: brumo_wordmark_mask = 8'h8a;
                        5'd1: brumo_wordmark_mask = 8'h09;
                        5'd2: brumo_wordmark_mask = 8'haa;
                        5'd3: brumo_wordmark_mask = 8'ha2;
                        default: brumo_wordmark_mask = 8'h00;
                    endcase
                end
                8'd6: begin
                    case (chunk)
                        5'd0: brumo_wordmark_mask = 8'hf2;
                        5'd1: brumo_wordmark_mask = 8'h06;
                        5'd2: brumo_wordmark_mask = 8'haa;
                        5'd3: brumo_wordmark_mask = 8'h9c;
                        default: brumo_wordmark_mask = 8'h00;
                    endcase
                end
                default: brumo_wordmark_mask = 8'h00;
            endcase
        end
    endfunction

    function [7:0] nestle_wordmark_mask;
        input [7:0] row;
        input [4:0] chunk;
        begin
            nestle_wordmark_mask = 8'h00;
            case (row)
                8'd0: begin
                    case (chunk)
                        5'd2: nestle_wordmark_mask = 8'h02;
                        5'd3: nestle_wordmark_mask = 8'h10;
                        default: nestle_wordmark_mask = 8'h00;
                    endcase
                end
                8'd1: begin
                    case (chunk)
                        5'd2: nestle_wordmark_mask = 8'h02;
                        5'd3: nestle_wordmark_mask = 8'h20;
                        default: nestle_wordmark_mask = 8'h00;
                    endcase
                end
                8'd2: begin
                    case (chunk)
                        5'd0: nestle_wordmark_mask = 8'h88;
                        5'd2: nestle_wordmark_mask = 8'h12;
                        default: nestle_wordmark_mask = 8'h00;
                    endcase
                end
                8'd3: begin
                    case (chunk)
                        5'd0: nestle_wordmark_mask = 8'hc8;
                        5'd2: nestle_wordmark_mask = 8'h12;
                        default: nestle_wordmark_mask = 8'h00;
                    endcase
                end
                8'd4: begin
                    case (chunk)
                        5'd0: nestle_wordmark_mask = 8'hc9;
                        5'd1: nestle_wordmark_mask = 8'hc7;
                        5'd2: nestle_wordmark_mask = 8'hba;
                        5'd3: nestle_wordmark_mask = 8'h70;
                        default: nestle_wordmark_mask = 8'h00;
                    endcase
                end
                8'd5: begin
                    case (chunk)
                        5'd0: nestle_wordmark_mask = 8'haa;
                        5'd1: nestle_wordmark_mask = 8'h28;
                        5'd2: nestle_wordmark_mask = 8'h12;
                        5'd3: nestle_wordmark_mask = 8'h88;
                        default: nestle_wordmark_mask = 8'h00;
                    endcase
                end
                8'd6: begin
                    case (chunk)
                        5'd0: nestle_wordmark_mask = 8'h9b;
                        5'd1: nestle_wordmark_mask = 8'he7;
                        5'd2: nestle_wordmark_mask = 8'h12;
                        5'd3: nestle_wordmark_mask = 8'hf8;
                        default: nestle_wordmark_mask = 8'h00;
                    endcase
                end
                8'd7: begin
                    case (chunk)
                        5'd0: nestle_wordmark_mask = 8'h9a;
                        5'd2: nestle_wordmark_mask = 8'h92;
                        5'd3: nestle_wordmark_mask = 8'h80;
                        default: nestle_wordmark_mask = 8'h00;
                    endcase
                end
                8'd8: begin
                    case (chunk)
                        5'd0: nestle_wordmark_mask = 8'h89;
                        5'd1: nestle_wordmark_mask = 8'hef;
                        5'd2: nestle_wordmark_mask = 8'h0a;
                        5'd3: nestle_wordmark_mask = 8'h78;
                        default: nestle_wordmark_mask = 8'h00;
                    endcase
                end
                default: nestle_wordmark_mask = 8'h00;
            endcase
        end
    endfunction

    function [7:0] nestle_birds_mask;
        input [7:0] row;
        input [4:0] chunk;
        begin
            nestle_birds_mask = 8'h00;
            case (row)
                8'd0, 8'd19: begin
                    case (chunk)
                        5'd0: nestle_birds_mask = 8'h01;
                        5'd1: nestle_birds_mask = 8'hf8;
                        default: nestle_birds_mask = 8'h00;
                    endcase
                end
                8'd1, 8'd18: begin
                    case (chunk)
                        5'd0: nestle_birds_mask = 8'h06;
                        5'd1: nestle_birds_mask = 8'h06;
                        default: nestle_birds_mask = 8'h00;
                    endcase
                end
                8'd2: begin
                    case (chunk)
                        5'd0: nestle_birds_mask = 8'h08;
                        5'd1: nestle_birds_mask = 8'h01;
                        default: nestle_birds_mask = 8'h00;
                    endcase
                end
                8'd3: begin
                    case (chunk)
                        5'd0: nestle_birds_mask = 8'h10;
                        5'd2: nestle_birds_mask = 8'h80;
                        default: nestle_birds_mask = 8'h00;
                    endcase
                end
                8'd4: begin
                    case (chunk)
                        5'd0: nestle_birds_mask = 8'h20;
                        5'd2: nestle_birds_mask = 8'h40;
                        default: nestle_birds_mask = 8'h00;
                    endcase
                end
                8'd5: begin
                    case (chunk)
                        5'd0: nestle_birds_mask = 8'h40;
                        5'd1: nestle_birds_mask = 8'h3c;
                        5'd2: nestle_birds_mask = 8'h20;
                        default: nestle_birds_mask = 8'h00;
                    endcase
                end
                8'd6: begin
                    case (chunk)
                        5'd0: nestle_birds_mask = 8'h40;
                        5'd1: nestle_birds_mask = 8'h48;
                        5'd2: nestle_birds_mask = 8'h20;
                        default: nestle_birds_mask = 8'h00;
                    endcase
                end
                8'd7: begin
                    case (chunk)
                        5'd0: nestle_birds_mask = 8'h80;
                        5'd1: nestle_birds_mask = 8'hb8;
                        5'd2: nestle_birds_mask = 8'h10;
                        default: nestle_birds_mask = 8'h00;
                    endcase
                end
                8'd8: begin
                    case (chunk)
                        5'd0: nestle_birds_mask = 8'h80;
                        5'd1: nestle_birds_mask = 8'haf;
                        5'd2: nestle_birds_mask = 8'h10;
                        default: nestle_birds_mask = 8'h00;
                    endcase
                end
                8'd9: begin
                    case (chunk)
                        5'd0: nestle_birds_mask = 8'h83;
                        5'd1: nestle_birds_mask = 8'h20;
                        5'd2: nestle_birds_mask = 8'h90;
                        default: nestle_birds_mask = 8'h00;
                    endcase
                end
                8'd10: begin
                    case (chunk)
                        5'd0: nestle_birds_mask = 8'h85;
                        5'd1: nestle_birds_mask = 8'he3;
                        5'd2: nestle_birds_mask = 8'h10;
                        default: nestle_birds_mask = 8'h00;
                    endcase
                end
                8'd11: begin
                    case (chunk)
                        5'd0: nestle_birds_mask = 8'h83;
                        5'd1: nestle_birds_mask = 8'h18;
                        5'd2: nestle_birds_mask = 8'h10;
                        default: nestle_birds_mask = 8'h00;
                    endcase
                end
                8'd12: begin
                    case (chunk)
                        5'd0: nestle_birds_mask = 8'h81;
                        5'd1: nestle_birds_mask = 8'h08;
                        5'd2: nestle_birds_mask = 8'h90;
                        default: nestle_birds_mask = 8'h00;
                    endcase
                end
                8'd13: begin
                    case (chunk)
                        5'd0: nestle_birds_mask = 8'h4f;
                        5'd1: nestle_birds_mask = 8'h93;
                        5'd2: nestle_birds_mask = 8'h20;
                        default: nestle_birds_mask = 8'h00;
                    endcase
                end
                8'd14: begin
                    case (chunk)
                        5'd0: nestle_birds_mask = 8'h48;
                        5'd1: nestle_birds_mask = 8'hfd;
                        5'd2: nestle_birds_mask = 8'h20;
                        default: nestle_birds_mask = 8'h00;
                    endcase
                end
                8'd15: begin
                    case (chunk)
                        5'd0: nestle_birds_mask = 8'h24;
                        5'd1: nestle_birds_mask = 8'h06;
                        5'd2: nestle_birds_mask = 8'h40;
                        default: nestle_birds_mask = 8'h00;
                    endcase
                end
                8'd16: begin
                    case (chunk)
                        5'd0: nestle_birds_mask = 8'h16;
                        5'd1: nestle_birds_mask = 8'h18;
                        5'd2: nestle_birds_mask = 8'h80;
                        default: nestle_birds_mask = 8'h00;
                    endcase
                end
                8'd17: begin
                    case (chunk)
                        5'd0: nestle_birds_mask = 8'h09;
                        5'd1: nestle_birds_mask = 8'he1;
                        default: nestle_birds_mask = 8'h00;
                    endcase
                end
                default: nestle_birds_mask = 8'h00;
            endcase
        end
    endfunction

    function [7:0] nestle_subtitle_mask;
        input [7:0] row;
        input [4:0] chunk;
        begin
            nestle_subtitle_mask = 8'h00;
            case (row)
                8'd0: begin
                    case (chunk)
                        5'd7: nestle_subtitle_mask = 8'h3e;
                        default: nestle_subtitle_mask = 8'h00;
                    endcase
                end
                8'd2: begin
                    case (chunk)
                        5'd0: nestle_subtitle_mask = 8'hf3;
                        5'd1: nestle_subtitle_mask = 8'hc7;
                        5'd2: nestle_subtitle_mask = 8'h22;
                        5'd3: nestle_subtitle_mask = 8'h71;
                        5'd4: nestle_subtitle_mask = 8'hef;
                        5'd5: nestle_subtitle_mask = 8'ha2;
                        5'd6: nestle_subtitle_mask = 8'h0f;
                        5'd7: nestle_subtitle_mask = 8'h1c;
                        5'd8: nestle_subtitle_mask = 8'hf1;
                        5'd9: nestle_subtitle_mask = 8'he8;
                        5'd10: nestle_subtitle_mask = 8'h1c;
                        5'd11: nestle_subtitle_mask = 8'h78;
                        default: nestle_subtitle_mask = 8'h00;
                    endcase
                end
                8'd3: begin
                    case (chunk)
                        5'd0: nestle_subtitle_mask = 8'h8a;
                        5'd1: nestle_subtitle_mask = 8'h28;
                        5'd2: nestle_subtitle_mask = 8'ha4;
                        5'd3: nestle_subtitle_mask = 8'h8a;
                        5'd4: nestle_subtitle_mask = 8'h02;
                        5'd5: nestle_subtitle_mask = 8'h22;
                        5'd6: nestle_subtitle_mask = 8'h08;
                        5'd7: nestle_subtitle_mask = 8'ha2;
                        5'd8: nestle_subtitle_mask = 8'h8a;
                        5'd9: nestle_subtitle_mask = 8'h08;
                        5'd10: nestle_subtitle_mask = 8'h22;
                        5'd11: nestle_subtitle_mask = 8'h80;
                        default: nestle_subtitle_mask = 8'h00;
                    endcase
                end
                8'd4: begin
                    case (chunk)
                        5'd0: nestle_subtitle_mask = 8'h8a;
                        5'd1: nestle_subtitle_mask = 8'h28;
                        5'd2: nestle_subtitle_mask = 8'ha8;
                        5'd3: nestle_subtitle_mask = 8'h8a;
                        5'd4: nestle_subtitle_mask = 8'h02;
                        5'd5: nestle_subtitle_mask = 8'h22;
                        5'd6: nestle_subtitle_mask = 8'h08;
                        5'd7: nestle_subtitle_mask = 8'ha2;
                        5'd8: nestle_subtitle_mask = 8'h8a;
                        5'd9: nestle_subtitle_mask = 8'h08;
                        5'd10: nestle_subtitle_mask = 8'h22;
                        5'd11: nestle_subtitle_mask = 8'h80;
                        default: nestle_subtitle_mask = 8'h00;
                    endcase
                end
                8'd5: begin
                    case (chunk)
                        5'd0: nestle_subtitle_mask = 8'hf3;
                        5'd1: nestle_subtitle_mask = 8'hc8;
                        5'd2: nestle_subtitle_mask = 8'hb0;
                        5'd3: nestle_subtitle_mask = 8'hf9;
                        5'd4: nestle_subtitle_mask = 8'hc2;
                        5'd5: nestle_subtitle_mask = 8'h22;
                        5'd6: nestle_subtitle_mask = 8'h0f;
                        5'd7: nestle_subtitle_mask = 8'h3e;
                        5'd8: nestle_subtitle_mask = 8'hf1;
                        5'd9: nestle_subtitle_mask = 8'hc8;
                        5'd10: nestle_subtitle_mask = 8'h3e;
                        5'd11: nestle_subtitle_mask = 8'h70;
                        default: nestle_subtitle_mask = 8'h00;
                    endcase
                end
                8'd6: begin
                    case (chunk)
                        5'd0: nestle_subtitle_mask = 8'h8a;
                        5'd1: nestle_subtitle_mask = 8'h88;
                        5'd2: nestle_subtitle_mask = 8'ha8;
                        5'd3: nestle_subtitle_mask = 8'h88;
                        5'd4: nestle_subtitle_mask = 8'h22;
                        5'd5: nestle_subtitle_mask = 8'h22;
                        5'd6: nestle_subtitle_mask = 8'h08;
                        5'd7: nestle_subtitle_mask = 8'h22;
                        5'd8: nestle_subtitle_mask = 8'ha0;
                        5'd9: nestle_subtitle_mask = 8'h28;
                        5'd10: nestle_subtitle_mask = 8'h22;
                        5'd11: nestle_subtitle_mask = 8'h08;
                        default: nestle_subtitle_mask = 8'h00;
                    endcase
                end
                8'd7: begin
                    case (chunk)
                        5'd0: nestle_subtitle_mask = 8'h8a;
                        5'd1: nestle_subtitle_mask = 8'h48;
                        5'd2: nestle_subtitle_mask = 8'ha4;
                        5'd3: nestle_subtitle_mask = 8'h88;
                        5'd4: nestle_subtitle_mask = 8'h22;
                        5'd5: nestle_subtitle_mask = 8'h22;
                        5'd6: nestle_subtitle_mask = 8'h08;
                        5'd7: nestle_subtitle_mask = 8'h22;
                        5'd8: nestle_subtitle_mask = 8'h90;
                        5'd9: nestle_subtitle_mask = 8'h28;
                        5'd10: nestle_subtitle_mask = 8'h22;
                        5'd11: nestle_subtitle_mask = 8'h08;
                        default: nestle_subtitle_mask = 8'h00;
                    endcase
                end
                8'd8: begin
                    case (chunk)
                        5'd0: nestle_subtitle_mask = 8'hf2;
                        5'd1: nestle_subtitle_mask = 8'h27;
                        5'd2: nestle_subtitle_mask = 8'h22;
                        5'd3: nestle_subtitle_mask = 8'h8b;
                        5'd4: nestle_subtitle_mask = 8'hc2;
                        5'd5: nestle_subtitle_mask = 8'h1c;
                        5'd6: nestle_subtitle_mask = 8'h08;
                        5'd7: nestle_subtitle_mask = 8'h22;
                        5'd8: nestle_subtitle_mask = 8'h8b;
                        5'd9: nestle_subtitle_mask = 8'hcf;
                        5'd10: nestle_subtitle_mask = 8'ha2;
                        5'd11: nestle_subtitle_mask = 8'hf0;
                        default: nestle_subtitle_mask = 8'h00;
                    endcase
                end
                default: nestle_subtitle_mask = 8'h00;
            endcase
        end
    endfunction

    function [7:0] lulu_black_mask;
        input [7:0] row;
        input [4:0] chunk;
        begin
            lulu_black_mask = 8'h00;
            case (row)
                8'd0: begin
                    case (chunk)
                        5'd3: lulu_black_mask = 8'h10;
                        default: lulu_black_mask = 8'h00;
                    endcase
                end
                8'd1: begin
                    case (chunk)
                        5'd2: lulu_black_mask = 8'h03;
                        5'd3: lulu_black_mask = 8'hf8;
                        default: lulu_black_mask = 8'h00;
                    endcase
                end
                8'd2: begin
                    case (chunk)
                        5'd2: lulu_black_mask = 8'h3f;
                        5'd3: lulu_black_mask = 8'hf8;
                        default: lulu_black_mask = 8'h00;
                    endcase
                end
                8'd3: begin
                    case (chunk)
                        5'd1: lulu_black_mask = 8'h03;
                        5'd2: lulu_black_mask = 8'hff;
                        5'd3: lulu_black_mask = 8'hf8;
                        default: lulu_black_mask = 8'h00;
                    endcase
                end
                8'd4: begin
                    case (chunk)
                        5'd1: lulu_black_mask = 8'h7f;
                        5'd2: lulu_black_mask = 8'hff;
                        5'd3: lulu_black_mask = 8'hf8;
                        default: lulu_black_mask = 8'h00;
                    endcase
                end
                8'd5, 8'd29: begin
                    case (chunk)
                        5'd0: lulu_black_mask = 8'h07;
                        5'd1: lulu_black_mask = 8'hff;
                        5'd2: lulu_black_mask = 8'hff;
                        5'd3: lulu_black_mask = 8'hfc;
                        default: lulu_black_mask = 8'h00;
                    endcase
                end
                8'd6, 8'd8: begin
                    case (chunk)
                        5'd0: lulu_black_mask = 8'h7f;
                        5'd1: lulu_black_mask = 8'hff;
                        5'd2: lulu_black_mask = 8'hff;
                        5'd3: lulu_black_mask = 8'hfc;
                        default: lulu_black_mask = 8'h00;
                    endcase
                end
                8'd7: begin
                    case (chunk)
                        5'd0: lulu_black_mask = 8'hff;
                        5'd1: lulu_black_mask = 8'hff;
                        5'd2: lulu_black_mask = 8'hff;
                        5'd3: lulu_black_mask = 8'hfc;
                        default: lulu_black_mask = 8'h00;
                    endcase
                end
                8'd9, 8'd10, 8'd11, 8'd12: begin
                    case (chunk)
                        5'd0: lulu_black_mask = 8'h7f;
                        5'd1: lulu_black_mask = 8'hff;
                        5'd2: lulu_black_mask = 8'hff;
                        5'd3: lulu_black_mask = 8'hfe;
                        default: lulu_black_mask = 8'h00;
                    endcase
                end
                8'd13: begin
                    case (chunk)
                        5'd0: lulu_black_mask = 8'h3f;
                        5'd1: lulu_black_mask = 8'hff;
                        5'd2: lulu_black_mask = 8'hff;
                        5'd3: lulu_black_mask = 8'hfe;
                        default: lulu_black_mask = 8'h00;
                    endcase
                end
                8'd14, 8'd15, 8'd16: begin
                    case (chunk)
                        5'd0: lulu_black_mask = 8'h3f;
                        5'd1: lulu_black_mask = 8'hff;
                        5'd2: lulu_black_mask = 8'hff;
                        5'd3: lulu_black_mask = 8'hff;
                        default: lulu_black_mask = 8'h00;
                    endcase
                end
                8'd17: begin
                    case (chunk)
                        5'd0: lulu_black_mask = 8'h1f;
                        5'd1: lulu_black_mask = 8'hff;
                        5'd2: lulu_black_mask = 8'hff;
                        5'd3: lulu_black_mask = 8'hff;
                        default: lulu_black_mask = 8'h00;
                    endcase
                end
                8'd18, 8'd19, 8'd20: begin
                    case (chunk)
                        5'd0: lulu_black_mask = 8'h1f;
                        5'd1: lulu_black_mask = 8'hff;
                        5'd2: lulu_black_mask = 8'hff;
                        5'd3: lulu_black_mask = 8'hff;
                        5'd4: lulu_black_mask = 8'h80;
                        default: lulu_black_mask = 8'h00;
                    endcase
                end
                8'd21: begin
                    case (chunk)
                        5'd0: lulu_black_mask = 8'h0f;
                        5'd1: lulu_black_mask = 8'hff;
                        5'd2: lulu_black_mask = 8'hff;
                        5'd3: lulu_black_mask = 8'hff;
                        5'd4: lulu_black_mask = 8'h80;
                        default: lulu_black_mask = 8'h00;
                    endcase
                end
                8'd22, 8'd23, 8'd24, 8'd25: begin
                    case (chunk)
                        5'd0: lulu_black_mask = 8'h0f;
                        5'd1: lulu_black_mask = 8'hff;
                        5'd2: lulu_black_mask = 8'hff;
                        5'd3: lulu_black_mask = 8'hff;
                        5'd4: lulu_black_mask = 8'hc0;
                        default: lulu_black_mask = 8'h00;
                    endcase
                end
                8'd26, 8'd28: begin
                    case (chunk)
                        5'd0: lulu_black_mask = 8'h07;
                        5'd1: lulu_black_mask = 8'hff;
                        5'd2: lulu_black_mask = 8'hff;
                        5'd3: lulu_black_mask = 8'hff;
                        5'd4: lulu_black_mask = 8'hc0;
                        default: lulu_black_mask = 8'h00;
                    endcase
                end
                8'd27: begin
                    case (chunk)
                        5'd0: lulu_black_mask = 8'h07;
                        5'd1: lulu_black_mask = 8'hff;
                        5'd2: lulu_black_mask = 8'hff;
                        5'd3: lulu_black_mask = 8'hff;
                        5'd4: lulu_black_mask = 8'he0;
                        default: lulu_black_mask = 8'h00;
                    endcase
                end
                8'd30: begin
                    case (chunk)
                        5'd0: lulu_black_mask = 8'h03;
                        5'd1: lulu_black_mask = 8'hff;
                        5'd2: lulu_black_mask = 8'hff;
                        5'd3: lulu_black_mask = 8'hc0;
                        default: lulu_black_mask = 8'h00;
                    endcase
                end
                8'd31: begin
                    case (chunk)
                        5'd0: lulu_black_mask = 8'h03;
                        5'd1: lulu_black_mask = 8'hff;
                        5'd2: lulu_black_mask = 8'hf8;
                        default: lulu_black_mask = 8'h00;
                    endcase
                end
                8'd32: begin
                    case (chunk)
                        5'd0: lulu_black_mask = 8'h03;
                        5'd1: lulu_black_mask = 8'hff;
                        5'd2: lulu_black_mask = 8'h80;
                        default: lulu_black_mask = 8'h00;
                    endcase
                end
                8'd33: begin
                    case (chunk)
                        5'd0: lulu_black_mask = 8'h03;
                        5'd1: lulu_black_mask = 8'hf8;
                        default: lulu_black_mask = 8'h00;
                    endcase
                end
                8'd34: begin
                    case (chunk)
                        5'd0: lulu_black_mask = 8'h01;
                        default: lulu_black_mask = 8'h00;
                    endcase
                end
                default: lulu_black_mask = 8'h00;
            endcase
        end
    endfunction

    function [7:0] lulu_orange_mask;
        input [7:0] row;
        input [4:0] chunk;
        begin
            lulu_orange_mask = 8'h00;
            case (row)
                8'd12: begin
                    case (chunk)
                        5'd0: lulu_orange_mask = 8'h02;
                        default: lulu_orange_mask = 8'h00;
                    endcase
                end
                8'd13, 8'd14, 8'd15: begin
                    case (chunk)
                        5'd0: lulu_orange_mask = 8'h06;
                        default: lulu_orange_mask = 8'h00;
                    endcase
                end
                8'd16: begin
                    case (chunk)
                        5'd0: lulu_orange_mask = 8'h07;
                        default: lulu_orange_mask = 8'h00;
                    endcase
                end
                8'd17, 8'd18, 8'd19, 8'd20: begin
                    case (chunk)
                        5'd0: lulu_orange_mask = 8'h03;
                        default: lulu_orange_mask = 8'h00;
                    endcase
                end
                8'd21, 8'd22, 8'd23, 8'd24: begin
                    case (chunk)
                        5'd0: lulu_orange_mask = 8'h01;
                        5'd1: lulu_orange_mask = 8'h80;
                        default: lulu_orange_mask = 8'h00;
                    endcase
                end
                8'd25, 8'd26: begin
                    case (chunk)
                        5'd1: lulu_orange_mask = 8'hc0;
                        default: lulu_orange_mask = 8'h00;
                    endcase
                end
                8'd27: begin
                    case (chunk)
                        5'd1: lulu_orange_mask = 8'hc0;
                        5'd3: lulu_orange_mask = 8'h80;
                        default: lulu_orange_mask = 8'h00;
                    endcase
                end
                8'd28: begin
                    case (chunk)
                        5'd1: lulu_orange_mask = 8'hc0;
                        5'd3: lulu_orange_mask = 8'h40;
                        default: lulu_orange_mask = 8'h00;
                    endcase
                end
                8'd29: begin
                    case (chunk)
                        5'd1: lulu_orange_mask = 8'hef;
                        5'd2: lulu_orange_mask = 8'h80;
                        5'd3: lulu_orange_mask = 8'h40;
                        default: lulu_orange_mask = 8'h00;
                    endcase
                end
                8'd30: begin
                    case (chunk)
                        5'd1: lulu_orange_mask = 8'h7f;
                        5'd2: lulu_orange_mask = 8'h80;
                        default: lulu_orange_mask = 8'h00;
                    endcase
                end
                8'd31: begin
                    case (chunk)
                        5'd1: lulu_orange_mask = 8'h70;
                        default: lulu_orange_mask = 8'h00;
                    endcase
                end
                default: lulu_orange_mask = 8'h00;
            endcase
        end
    endfunction

    function [7:0] lulu_blue_mask;
        input [7:0] row;
        input [4:0] chunk;
        begin
            lulu_blue_mask = 8'h00;
            case (row)
                8'd8, 8'd9, 8'd10: begin
                    case (chunk)
                        5'd0: lulu_blue_mask = 8'h10;
                        default: lulu_blue_mask = 8'h00;
                    endcase
                end
                8'd11: begin
                    case (chunk)
                        5'd1: lulu_blue_mask = 8'h1c;
                        default: lulu_blue_mask = 8'h00;
                    endcase
                end
                8'd12, 8'd13, 8'd14, 8'd15: begin
                    case (chunk)
                        5'd1: lulu_blue_mask = 8'h6c;
                        default: lulu_blue_mask = 8'h00;
                    endcase
                end
                8'd16, 8'd17, 8'd18, 8'd19: begin
                    case (chunk)
                        5'd1: lulu_blue_mask = 8'h36;
                        default: lulu_blue_mask = 8'h00;
                    endcase
                end
                8'd20: begin
                    case (chunk)
                        5'd1: lulu_blue_mask = 8'h3b;
                        default: lulu_blue_mask = 8'h00;
                    endcase
                end
                8'd21, 8'd22, 8'd23: begin
                    case (chunk)
                        5'd1: lulu_blue_mask = 8'h1b;
                        default: lulu_blue_mask = 8'h00;
                    endcase
                end
                8'd24: begin
                    case (chunk)
                        5'd1: lulu_blue_mask = 8'h1f;
                        default: lulu_blue_mask = 8'h00;
                    endcase
                end
                8'd25: begin
                    case (chunk)
                        5'd1: lulu_blue_mask = 8'h07;
                        5'd4: lulu_blue_mask = 8'h80;
                        default: lulu_blue_mask = 8'h00;
                    endcase
                end
                8'd26: begin
                    case (chunk)
                        5'd1: lulu_blue_mask = 8'h02;
                        5'd4: lulu_blue_mask = 8'h80;
                        default: lulu_blue_mask = 8'h00;
                    endcase
                end
                8'd27: begin
                    case (chunk)
                        5'd4: lulu_blue_mask = 8'h40;
                        default: lulu_blue_mask = 8'h00;
                    endcase
                end
                default: lulu_blue_mask = 8'h00;
            endcase
        end
    endfunction

    function [7:0] lulu_green_mask;
        input [7:0] row;
        input [4:0] chunk;
        begin
            lulu_green_mask = 8'h00;
            case (row)
                8'd6: begin
                    case (chunk)
                        5'd1: lulu_green_mask = 8'h01;
                        5'd2: lulu_green_mask = 8'hc0;
                        default: lulu_green_mask = 8'h00;
                    endcase
                end
                8'd7, 8'd8, 8'd9: begin
                    case (chunk)
                        5'd1: lulu_green_mask = 8'h40;
                        5'd2: lulu_green_mask = 8'hc0;
                        default: lulu_green_mask = 8'h00;
                    endcase
                end
                8'd10: begin
                    case (chunk)
                        5'd2: lulu_green_mask = 8'hc0;
                        default: lulu_green_mask = 8'h00;
                    endcase
                end
                8'd11, 8'd12, 8'd13, 8'd14: begin
                    case (chunk)
                        5'd2: lulu_green_mask = 8'h60;
                        default: lulu_green_mask = 8'h00;
                    endcase
                end
                8'd15, 8'd16, 8'd17, 8'd18: begin
                    case (chunk)
                        5'd2: lulu_green_mask = 8'h30;
                        default: lulu_green_mask = 8'h00;
                    endcase
                end
                8'd19: begin
                    case (chunk)
                        5'd2: lulu_green_mask = 8'h38;
                        default: lulu_green_mask = 8'h00;
                    endcase
                end
                8'd20: begin
                    case (chunk)
                        5'd2: lulu_green_mask = 8'h18;
                        default: lulu_green_mask = 8'h00;
                    endcase
                end
                8'd21: begin
                    case (chunk)
                        5'd2: lulu_green_mask = 8'h18;
                        5'd3: lulu_green_mask = 8'h06;
                        default: lulu_green_mask = 8'h00;
                    endcase
                end
                8'd22: begin
                    case (chunk)
                        5'd2: lulu_green_mask = 8'h18;
                        5'd3: lulu_green_mask = 8'h7e;
                        default: lulu_green_mask = 8'h00;
                    endcase
                end
                8'd23: begin
                    case (chunk)
                        5'd2: lulu_green_mask = 8'h1f;
                        5'd3: lulu_green_mask = 8'hf8;
                        default: lulu_green_mask = 8'h00;
                    endcase
                end
                8'd24: begin
                    case (chunk)
                        5'd2: lulu_green_mask = 8'h0f;
                        5'd3: lulu_green_mask = 8'h80;
                        default: lulu_green_mask = 8'h00;
                    endcase
                end
                8'd25: begin
                    case (chunk)
                        5'd2: lulu_green_mask = 8'h08;
                        default: lulu_green_mask = 8'h00;
                    endcase
                end
                8'd27: begin
                    case (chunk)
                        5'd2: lulu_green_mask = 8'h04;
                        default: lulu_green_mask = 8'h00;
                    endcase
                end
                8'd28, 8'd29: begin
                    case (chunk)
                        5'd2: lulu_green_mask = 8'h02;
                        default: lulu_green_mask = 8'h00;
                    endcase
                end
                default: lulu_green_mask = 8'h00;
            endcase
        end
    endfunction

    function [7:0] lulu_red_mask;
        input [7:0] row;
        input [4:0] chunk;
        begin
            lulu_red_mask = 8'h00;
            case (row)
                8'd6: begin
                    case (chunk)
                        5'd1: lulu_red_mask = 8'h10;
                        default: lulu_red_mask = 8'h00;
                    endcase
                end
                8'd7: begin
                    case (chunk)
                        5'd1: lulu_red_mask = 8'h08;
                        default: lulu_red_mask = 8'h00;
                    endcase
                end
                8'd8: begin
                    case (chunk)
                        5'd1: lulu_red_mask = 8'h08;
                        5'd3: lulu_red_mask = 8'hc0;
                        default: lulu_red_mask = 8'h00;
                    endcase
                end
                8'd9: begin
                    case (chunk)
                        5'd2: lulu_red_mask = 8'h0c;
                        5'd3: lulu_red_mask = 8'hc0;
                        default: lulu_red_mask = 8'h00;
                    endcase
                end
                8'd10, 8'd11, 8'd12, 8'd13: begin
                    case (chunk)
                        5'd2: lulu_red_mask = 8'h06;
                        5'd3: lulu_red_mask = 8'h60;
                        default: lulu_red_mask = 8'h00;
                    endcase
                end
                8'd14: begin
                    case (chunk)
                        5'd2: lulu_red_mask = 8'h06;
                        5'd3: lulu_red_mask = 8'h30;
                        default: lulu_red_mask = 8'h00;
                    endcase
                end
                8'd15, 8'd16: begin
                    case (chunk)
                        5'd2: lulu_red_mask = 8'h03;
                        5'd3: lulu_red_mask = 8'h30;
                        default: lulu_red_mask = 8'h00;
                    endcase
                end
                8'd17: begin
                    case (chunk)
                        5'd2: lulu_red_mask = 8'h03;
                        5'd3: lulu_red_mask = 8'hf0;
                        default: lulu_red_mask = 8'h00;
                    endcase
                end
                8'd18: begin
                    case (chunk)
                        5'd2: lulu_red_mask = 8'h03;
                        5'd3: lulu_red_mask = 8'hc0;
                        default: lulu_red_mask = 8'h00;
                    endcase
                end
                8'd19: begin
                    case (chunk)
                        5'd3: lulu_red_mask = 8'h40;
                        default: lulu_red_mask = 8'h00;
                    endcase
                end
                8'd26: begin
                    case (chunk)
                        5'd3: lulu_red_mask = 8'h10;
                        default: lulu_red_mask = 8'h00;
                    endcase
                end
                8'd27, 8'd28: begin
                    case (chunk)
                        5'd3: lulu_red_mask = 8'h08;
                        default: lulu_red_mask = 8'h00;
                    endcase
                end
                default: lulu_red_mask = 8'h00;
            endcase
        end
    endfunction

    function [7:0] lulu_yellow_mask;
        input [7:0] row;
        input [4:0] chunk;
        begin
            lulu_yellow_mask = 8'h00;
            case (row)
                8'd4: begin
                    case (chunk)
                        5'd2: lulu_yellow_mask = 8'h01;
                        5'd3: lulu_yellow_mask = 8'h80;
                        default: lulu_yellow_mask = 8'h00;
                    endcase
                end
                8'd5: begin
                    case (chunk)
                        5'd2: lulu_yellow_mask = 8'h3f;
                        5'd3: lulu_yellow_mask = 8'hc0;
                        default: lulu_yellow_mask = 8'h00;
                    endcase
                end
                8'd6: begin
                    case (chunk)
                        5'd2: lulu_yellow_mask = 8'h1e;
                        default: lulu_yellow_mask = 8'h00;
                    endcase
                end
                8'd7: begin
                    case (chunk)
                        5'd0: lulu_yellow_mask = 8'h04;
                        default: lulu_yellow_mask = 8'h00;
                    endcase
                end
                8'd8, 8'd9: begin
                    case (chunk)
                        5'd0: lulu_yellow_mask = 8'h02;
                        default: lulu_yellow_mask = 8'h00;
                    endcase
                end
                8'd25, 8'd26: begin
                    case (chunk)
                        5'd3: lulu_yellow_mask = 8'h02;
                        default: lulu_yellow_mask = 8'h00;
                    endcase
                end
                8'd27: begin
                    case (chunk)
                        5'd3: lulu_yellow_mask = 8'h01;
                        default: lulu_yellow_mask = 8'h00;
                    endcase
                end
                default: lulu_yellow_mask = 8'h00;
            endcase
        end
    endfunction

    wire [7:0] heading_gx;
    wire [7:0] heading_gy;
    wire [7:0] heading_x;
    wire [7:0] heading_y;
    wire [7:0] heading_byte;
    wire heading_pixel;
    assign heading_gx = x_group - 8'd46;
    assign heading_gy = y_group - 8'd11;
    assign heading_x = heading_gx;
    assign heading_y = heading_gy;
    assign heading_byte = heading_mask(heading_y, heading_x[7:3]);
    assign heading_pixel =
        (x_group >= 8'd46) && (x_group < 8'd113) &&
        (y_group >= 8'd11) && (y_group < 8'd20) &&
        (heading_x < 8'd67) && (heading_y < 8'd9) &&
        heading_byte[3'd7 - heading_x[2:0]];

    wire [7:0] semi_green_gx;
    wire [7:0] semi_green_gy;
    wire [7:0] semi_green_x;
    wire [7:0] semi_green_y;
    wire [7:0] semi_green_byte;
    wire semi_green_pixel;
    assign semi_green_gx = x_group - 8'd8;
    assign semi_green_gy = y_group - 8'd43;
    assign semi_green_x = {semi_green_gx[6:0], x_phase[1]};
    assign semi_green_y = {semi_green_gy[6:0], y_phase[1]};
    assign semi_green_byte = semi_green_mask(semi_green_y, semi_green_x[7:3]);
    assign semi_green_pixel =
        (x_group >= 8'd8) && (x_group < 8'd21) &&
        (y_group >= 8'd43) && (y_group < 8'd53) &&
        (semi_green_x < 8'd26) && (semi_green_y < 8'd20) &&
        semi_green_byte[3'd7 - semi_green_x[2:0]];

    wire [7:0] semi_black_gx;
    wire [7:0] semi_black_gy;
    wire [7:0] semi_black_x;
    wire [7:0] semi_black_y;
    wire [7:0] semi_black_byte;
    wire semi_black_pixel;
    assign semi_black_gx = x_group - 8'd8;
    assign semi_black_gy = y_group - 8'd43;
    assign semi_black_x = {semi_black_gx[6:0], x_phase[1]};
    assign semi_black_y = {semi_black_gy[6:0], y_phase[1]};
    assign semi_black_byte = semi_black_mask(semi_black_y, semi_black_x[7:3]);
    assign semi_black_pixel =
        (x_group >= 8'd8) && (x_group < 8'd21) &&
        (y_group >= 8'd43) && (y_group < 8'd53) &&
        (semi_black_x < 8'd26) && (semi_black_y < 8'd20) &&
        semi_black_byte[3'd7 - semi_black_x[2:0]];

    wire [7:0] semi_wordmark_gx;
    wire [7:0] semi_wordmark_gy;
    wire [7:0] semi_wordmark_x;
    wire [7:0] semi_wordmark_y;
    wire [7:0] semi_wordmark_byte;
    wire semi_wordmark_pixel;
    assign semi_wordmark_gx = x_group - 8'd23;
    assign semi_wordmark_gy = y_group - 8'd44;
    assign semi_wordmark_x = semi_wordmark_gx;
    assign semi_wordmark_y = semi_wordmark_gy;
    assign semi_wordmark_byte = semi_wordmark_mask(semi_wordmark_y, semi_wordmark_x[7:3]);
    assign semi_wordmark_pixel =
        (x_group >= 8'd23) && (x_group < 8'd47) &&
        (y_group >= 8'd44) && (y_group < 8'd51) &&
        (semi_wordmark_x < 8'd24) && (semi_wordmark_y < 8'd7) &&
        semi_wordmark_byte[3'd7 - semi_wordmark_x[2:0]];

    wire [7:0] lccc_navy_gx;
    wire [7:0] lccc_navy_gy;
    wire [7:0] lccc_navy_x;
    wire [7:0] lccc_navy_y;
    wire [7:0] lccc_navy_byte;
    wire lccc_navy_pixel;
    assign lccc_navy_gx = x_group - 8'd56;
    assign lccc_navy_gy = y_group - 8'd41;
    assign lccc_navy_x = {lccc_navy_gx[6:0], x_phase[1]};
    assign lccc_navy_y = {lccc_navy_gy[6:0], y_phase[1]};
    assign lccc_navy_byte = lccc_navy_mask(lccc_navy_y, lccc_navy_x[7:3]);
    assign lccc_navy_pixel =
        (x_group >= 8'd56) && (x_group < 8'd67) &&
        (y_group >= 8'd41) && (y_group < 8'd54) &&
        (lccc_navy_x < 8'd22) && (lccc_navy_y < 8'd26) &&
        lccc_navy_byte[3'd7 - lccc_navy_x[2:0]];

    wire [7:0] lccc_accent_gx;
    wire [7:0] lccc_accent_gy;
    wire [7:0] lccc_accent_x;
    wire [7:0] lccc_accent_y;
    wire [7:0] lccc_accent_byte;
    wire lccc_accent_pixel;
    assign lccc_accent_gx = x_group - 8'd56;
    assign lccc_accent_gy = y_group - 8'd41;
    assign lccc_accent_x = {lccc_accent_gx[6:0], x_phase[1]};
    assign lccc_accent_y = {lccc_accent_gy[6:0], y_phase[1]};
    assign lccc_accent_byte = lccc_accent_mask(lccc_accent_y, lccc_accent_x[7:3]);
    assign lccc_accent_pixel =
        (x_group >= 8'd56) && (x_group < 8'd67) &&
        (y_group >= 8'd41) && (y_group < 8'd54) &&
        (lccc_accent_x < 8'd22) && (lccc_accent_y < 8'd26) &&
        lccc_accent_byte[3'd7 - lccc_accent_x[2:0]];

    wire [7:0] lccc_line1_gx;
    wire [7:0] lccc_line1_gy;
    wire [7:0] lccc_line1_x;
    wire [7:0] lccc_line1_y;
    wire [7:0] lccc_line1_byte;
    wire lccc_line1_pixel;
    assign lccc_line1_gx = x_group - 8'd70;
    assign lccc_line1_gy = y_group - 8'd43;
    assign lccc_line1_x = {lccc_line1_gx[6:0], x_phase[1]};
    assign lccc_line1_y = {lccc_line1_gy[6:0], y_phase[1]};
    assign lccc_line1_byte = lccc_line1_mask(lccc_line1_y, lccc_line1_x[7:3]);
    assign lccc_line1_pixel =
        (x_group >= 8'd70) && (x_group < 8'd94) &&
        (y_group >= 8'd43) && (y_group < 8'd47) &&
        (lccc_line1_x < 8'd47) && (lccc_line1_y < 8'd7) &&
        lccc_line1_byte[3'd7 - lccc_line1_x[2:0]];

    wire [7:0] lccc_line2_gx;
    wire [7:0] lccc_line2_gy;
    wire [7:0] lccc_line2_x;
    wire [7:0] lccc_line2_y;
    wire [7:0] lccc_line2_byte;
    wire lccc_line2_pixel;
    assign lccc_line2_gx = x_group - 8'd70;
    assign lccc_line2_gy = y_group - 8'd48;
    assign lccc_line2_x = {lccc_line2_gx[6:0], x_phase[1]};
    assign lccc_line2_y = {lccc_line2_gy[6:0], y_phase[1]};
    assign lccc_line2_byte = lccc_line2_mask(lccc_line2_y, lccc_line2_x[7:3]);
    assign lccc_line2_pixel =
        (x_group >= 8'd70) && (x_group < 8'd105) &&
        (y_group >= 8'd48) && (y_group < 8'd52) &&
        (lccc_line2_x < 8'd70) && (lccc_line2_y < 8'd7) &&
        lccc_line2_byte[3'd7 - lccc_line2_x[2:0]];

    wire [7:0] go_ribbon_gx;
    wire [7:0] go_ribbon_gy;
    wire [7:0] go_ribbon_x;
    wire [7:0] go_ribbon_y;
    wire [7:0] go_ribbon_byte;
    wire go_ribbon_pixel;
    assign go_ribbon_gx = x_group - 8'd115;
    assign go_ribbon_gy = y_group - 8'd36;
    assign go_ribbon_x = {go_ribbon_gx[6:0], x_phase[1]};
    assign go_ribbon_y = {go_ribbon_gy[6:0], y_phase[1]};
    assign go_ribbon_byte = go_ribbon_mask(go_ribbon_y, go_ribbon_x[7:3]);
    assign go_ribbon_pixel =
        (x_group >= 8'd115) && (x_group < 8'd149) &&
        (y_group >= 8'd36) && (y_group < 8'd59) &&
        (go_ribbon_x < 8'd68) && (go_ribbon_y < 8'd46) &&
        go_ribbon_byte[3'd7 - go_ribbon_x[2:0]];

    wire [7:0] go_letters_gx;
    wire [7:0] go_letters_gy;
    wire [7:0] go_letters_x;
    wire [7:0] go_letters_y;
    wire [7:0] go_letters_byte;
    wire go_letters_pixel;
    assign go_letters_gx = x_group - 8'd115;
    assign go_letters_gy = y_group - 8'd36;
    assign go_letters_x = {go_letters_gx[6:0], x_phase[1]};
    assign go_letters_y = {go_letters_gy[6:0], y_phase[1]};
    assign go_letters_byte = go_letters_mask(go_letters_y, go_letters_x[7:3]);
    assign go_letters_pixel =
        (x_group >= 8'd115) && (x_group < 8'd149) &&
        (y_group >= 8'd36) && (y_group < 8'd59) &&
        (go_letters_x < 8'd68) && (go_letters_y < 8'd46) &&
        go_letters_byte[3'd7 - go_letters_x[2:0]];

    wire [7:0] brumo_loop_gx;
    wire [7:0] brumo_loop_gy;
    wire [7:0] brumo_loop_x;
    wire [7:0] brumo_loop_y;
    wire [7:0] brumo_loop_byte;
    wire brumo_loop_pixel;
    assign brumo_loop_gx = x_group - 8'd18;
    assign brumo_loop_gy = y_group - 8'd73;
    assign brumo_loop_x = {brumo_loop_gx[6:0], x_phase[1]};
    assign brumo_loop_y = {brumo_loop_gy[6:0], y_phase[1]};
    assign brumo_loop_byte = brumo_loop_mask(brumo_loop_y, brumo_loop_x[7:3]);
    assign brumo_loop_pixel =
        (x_group >= 8'd18) && (x_group < 8'd38) &&
        (y_group >= 8'd73) && (y_group < 8'd100) &&
        (brumo_loop_x < 8'd40) && (brumo_loop_y < 8'd54) &&
        brumo_loop_byte[3'd7 - brumo_loop_x[2:0]];

    wire [7:0] brumo_wordmark_gx;
    wire [7:0] brumo_wordmark_gy;
    wire [7:0] brumo_wordmark_x;
    wire [7:0] brumo_wordmark_y;
    wire [7:0] brumo_wordmark_byte;
    wire brumo_wordmark_pixel;
    assign brumo_wordmark_gx = x_group - 8'd13;
    assign brumo_wordmark_gy = y_group - 8'd100;
    assign brumo_wordmark_x = brumo_wordmark_gx;
    assign brumo_wordmark_y = brumo_wordmark_gy;
    assign brumo_wordmark_byte = brumo_wordmark_mask(brumo_wordmark_y, brumo_wordmark_x[7:3]);
    assign brumo_wordmark_pixel =
        (x_group >= 8'd13) && (x_group < 8'd44) &&
        (y_group >= 8'd100) && (y_group < 8'd107) &&
        (brumo_wordmark_x < 8'd31) && (brumo_wordmark_y < 8'd7) &&
        brumo_wordmark_byte[3'd7 - brumo_wordmark_x[2:0]];

    wire [7:0] nestle_wordmark_gx;
    wire [7:0] nestle_wordmark_gy;
    wire [7:0] nestle_wordmark_x;
    wire [7:0] nestle_wordmark_y;
    wire [7:0] nestle_wordmark_byte;
    wire nestle_wordmark_pixel;
    assign nestle_wordmark_gx = x_group - 8'd59;
    assign nestle_wordmark_gy = y_group - 8'd81;
    assign nestle_wordmark_x = nestle_wordmark_gx;
    assign nestle_wordmark_y = nestle_wordmark_gy;
    assign nestle_wordmark_byte = nestle_wordmark_mask(nestle_wordmark_y, nestle_wordmark_x[7:3]);
    assign nestle_wordmark_pixel =
        (x_group >= 8'd59) && (x_group < 8'd88) &&
        (y_group >= 8'd81) && (y_group < 8'd90) &&
        (nestle_wordmark_x < 8'd29) && (nestle_wordmark_y < 8'd9) &&
        nestle_wordmark_byte[3'd7 - nestle_wordmark_x[2:0]];

    wire [7:0] nestle_birds_gx;
    wire [7:0] nestle_birds_gy;
    wire [7:0] nestle_birds_x;
    wire [7:0] nestle_birds_y;
    wire [7:0] nestle_birds_byte;
    wire nestle_birds_pixel;
    assign nestle_birds_gx = x_group - 8'd91;
    assign nestle_birds_gy = y_group - 8'd81;
    assign nestle_birds_x = {nestle_birds_gx[6:0], x_phase[1]};
    assign nestle_birds_y = {nestle_birds_gy[6:0], y_phase[1]};
    assign nestle_birds_byte = nestle_birds_mask(nestle_birds_y, nestle_birds_x[7:3]);
    assign nestle_birds_pixel =
        (x_group >= 8'd91) && (x_group < 8'd101) &&
        (y_group >= 8'd81) && (y_group < 8'd91) &&
        (nestle_birds_x < 8'd20) && (nestle_birds_y < 8'd20) &&
        nestle_birds_byte[3'd7 - nestle_birds_x[2:0]];

    wire [7:0] nestle_subtitle_gx;
    wire [7:0] nestle_subtitle_gy;
    wire [7:0] nestle_subtitle_x;
    wire [7:0] nestle_subtitle_y;
    wire [7:0] nestle_subtitle_byte;
    wire nestle_subtitle_pixel;
    assign nestle_subtitle_gx = x_group - 8'd57;
    assign nestle_subtitle_gy = y_group - 8'd93;
    assign nestle_subtitle_x = {nestle_subtitle_gx[6:0], x_phase[1]};
    assign nestle_subtitle_y = {nestle_subtitle_gy[6:0], y_phase[1]};
    assign nestle_subtitle_byte = nestle_subtitle_mask(nestle_subtitle_y, nestle_subtitle_x[7:3]);
    assign nestle_subtitle_pixel =
        (x_group >= 8'd57) && (x_group < 8'd104) &&
        (y_group >= 8'd93) && (y_group < 8'd98) &&
        (nestle_subtitle_x < 8'd93) && (nestle_subtitle_y < 8'd9) &&
        nestle_subtitle_byte[3'd7 - nestle_subtitle_x[2:0]];

    wire [7:0] lulu_black_gx;
    wire [7:0] lulu_black_gy;
    wire [7:0] lulu_black_x;
    wire [7:0] lulu_black_y;
    wire [7:0] lulu_black_byte;
    wire lulu_black_pixel;
    assign lulu_black_gx = x_group - 8'd115;
    assign lulu_black_gy = y_group - 8'd74;
    assign lulu_black_x = lulu_black_gx;
    assign lulu_black_y = lulu_black_gy;
    assign lulu_black_byte = lulu_black_mask(lulu_black_y, lulu_black_x[7:3]);
    assign lulu_black_pixel =
        (x_group >= 8'd115) && (x_group < 8'd150) &&
        (y_group >= 8'd74) && (y_group < 8'd109) &&
        (lulu_black_x < 8'd35) && (lulu_black_y < 8'd35) &&
        lulu_black_byte[3'd7 - lulu_black_x[2:0]];

    wire [7:0] lulu_orange_gx;
    wire [7:0] lulu_orange_gy;
    wire [7:0] lulu_orange_x;
    wire [7:0] lulu_orange_y;
    wire [7:0] lulu_orange_byte;
    wire lulu_orange_pixel;
    assign lulu_orange_gx = x_group - 8'd115;
    assign lulu_orange_gy = y_group - 8'd74;
    assign lulu_orange_x = lulu_orange_gx;
    assign lulu_orange_y = lulu_orange_gy;
    assign lulu_orange_byte = lulu_orange_mask(lulu_orange_y, lulu_orange_x[7:3]);
    assign lulu_orange_pixel =
        (x_group >= 8'd115) && (x_group < 8'd150) &&
        (y_group >= 8'd74) && (y_group < 8'd109) &&
        (lulu_orange_x < 8'd35) && (lulu_orange_y < 8'd35) &&
        lulu_orange_byte[3'd7 - lulu_orange_x[2:0]];

    wire [7:0] lulu_blue_gx;
    wire [7:0] lulu_blue_gy;
    wire [7:0] lulu_blue_x;
    wire [7:0] lulu_blue_y;
    wire [7:0] lulu_blue_byte;
    wire lulu_blue_pixel;
    assign lulu_blue_gx = x_group - 8'd115;
    assign lulu_blue_gy = y_group - 8'd74;
    assign lulu_blue_x = lulu_blue_gx;
    assign lulu_blue_y = lulu_blue_gy;
    assign lulu_blue_byte = lulu_blue_mask(lulu_blue_y, lulu_blue_x[7:3]);
    assign lulu_blue_pixel =
        (x_group >= 8'd115) && (x_group < 8'd150) &&
        (y_group >= 8'd74) && (y_group < 8'd109) &&
        (lulu_blue_x < 8'd35) && (lulu_blue_y < 8'd35) &&
        lulu_blue_byte[3'd7 - lulu_blue_x[2:0]];

    wire [7:0] lulu_green_gx;
    wire [7:0] lulu_green_gy;
    wire [7:0] lulu_green_x;
    wire [7:0] lulu_green_y;
    wire [7:0] lulu_green_byte;
    wire lulu_green_pixel;
    assign lulu_green_gx = x_group - 8'd115;
    assign lulu_green_gy = y_group - 8'd74;
    assign lulu_green_x = lulu_green_gx;
    assign lulu_green_y = lulu_green_gy;
    assign lulu_green_byte = lulu_green_mask(lulu_green_y, lulu_green_x[7:3]);
    assign lulu_green_pixel =
        (x_group >= 8'd115) && (x_group < 8'd150) &&
        (y_group >= 8'd74) && (y_group < 8'd109) &&
        (lulu_green_x < 8'd35) && (lulu_green_y < 8'd35) &&
        lulu_green_byte[3'd7 - lulu_green_x[2:0]];

    wire [7:0] lulu_red_gx;
    wire [7:0] lulu_red_gy;
    wire [7:0] lulu_red_x;
    wire [7:0] lulu_red_y;
    wire [7:0] lulu_red_byte;
    wire lulu_red_pixel;
    assign lulu_red_gx = x_group - 8'd115;
    assign lulu_red_gy = y_group - 8'd74;
    assign lulu_red_x = lulu_red_gx;
    assign lulu_red_y = lulu_red_gy;
    assign lulu_red_byte = lulu_red_mask(lulu_red_y, lulu_red_x[7:3]);
    assign lulu_red_pixel =
        (x_group >= 8'd115) && (x_group < 8'd150) &&
        (y_group >= 8'd74) && (y_group < 8'd109) &&
        (lulu_red_x < 8'd35) && (lulu_red_y < 8'd35) &&
        lulu_red_byte[3'd7 - lulu_red_x[2:0]];

    wire [7:0] lulu_yellow_gx;
    wire [7:0] lulu_yellow_gy;
    wire [7:0] lulu_yellow_x;
    wire [7:0] lulu_yellow_y;
    wire [7:0] lulu_yellow_byte;
    wire lulu_yellow_pixel;
    assign lulu_yellow_gx = x_group - 8'd115;
    assign lulu_yellow_gy = y_group - 8'd74;
    assign lulu_yellow_x = lulu_yellow_gx;
    assign lulu_yellow_y = lulu_yellow_gy;
    assign lulu_yellow_byte = lulu_yellow_mask(lulu_yellow_y, lulu_yellow_x[7:3]);
    assign lulu_yellow_pixel =
        (x_group >= 8'd115) && (x_group < 8'd150) &&
        (y_group >= 8'd74) && (y_group < 8'd109) &&
        (lulu_yellow_x < 8'd35) && (lulu_yellow_y < 8'd35) &&
        lulu_yellow_byte[3'd7 - lulu_yellow_x[2:0]];

    always @* begin
        red = 2'd3; green = 2'd3; blue = 2'd3;
        if (heading_pixel) begin
            red = 2'd0; green = 2'd0; blue = 2'd0;
        end
        if (semi_green_pixel) begin
            red = 2'd1; green = 2'd2; blue = 2'd1;
        end
        if (semi_black_pixel) begin
            red = 2'd0; green = 2'd0; blue = 2'd0;
        end
        if (semi_wordmark_pixel) begin
            red = 2'd0; green = 2'd0; blue = 2'd0;
        end
        if (lccc_navy_pixel) begin
            red = 2'd0; green = 2'd0; blue = 2'd1;
        end
        if (lccc_accent_pixel) begin
            red = 2'd2; green = 2'd1; blue = 2'd3;
        end
        if (lccc_line1_pixel) begin
            red = 2'd0; green = 2'd0; blue = 2'd1;
        end
        if (lccc_line2_pixel) begin
            red = 2'd0; green = 2'd0; blue = 2'd1;
        end
        if (go_ribbon_pixel) begin
            red = 2'd2; green = 2'd3; blue = 2'd0;
        end
        if (go_letters_pixel) begin
            red = 2'd0; green = 2'd0; blue = 2'd0;
        end
        if (brumo_loop_pixel) begin
            red = 2'd0; green = 2'd0; blue = 2'd0;
        end
        if (brumo_wordmark_pixel) begin
            red = 2'd0; green = 2'd0; blue = 2'd0;
        end
        if (nestle_wordmark_pixel) begin
            red = 2'd0; green = 2'd2; blue = 2'd1;
        end
        if (nestle_birds_pixel) begin
            red = 2'd0; green = 2'd2; blue = 2'd1;
        end
        if (nestle_subtitle_pixel) begin
            red = 2'd0; green = 2'd2; blue = 2'd1;
        end
        if (lulu_black_pixel) begin
            red = 2'd0; green = 2'd0; blue = 2'd0;
        end
        if (lulu_orange_pixel) begin
            red = 2'd3; green = 2'd2; blue = 2'd0;
        end
        if (lulu_blue_pixel) begin
            red = 2'd0; green = 2'd1; blue = 2'd3;
        end
        if (lulu_green_pixel) begin
            red = 2'd0; green = 2'd2; blue = 2'd1;
        end
        if (lulu_red_pixel) begin
            red = 2'd3; green = 2'd0; blue = 2'd0;
        end
        if (lulu_yellow_pixel) begin
            red = 2'd3; green = 2'd3; blue = 2'd0;
        end
    end
endmodule
