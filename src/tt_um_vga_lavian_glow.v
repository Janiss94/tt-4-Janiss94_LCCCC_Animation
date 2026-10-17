// src/project.v
// LCCC / Chipathon slideshow, with synthesizable vectors no wider than 8 bits.
// Standalone: VGA timing is integrated; no hvsync_generator is instantiated.
// Pixel clock: 25 MHz. Raster: 800 clocks per line, 525 lines per frame.
// The output bus carries 2-bit R, G, B plus horizontal and vertical sync.
`default_nettype none

module tt_um_janiss94_LCCC_Animation #(
    // Valid range: 1..255. Each unit is TWO complete visible frames.
    // 150 pairs = 300 frames = 5.04 seconds at 25 MHz and 800x525 timing.
    parameter [7:0] SLIDE_FRAME_PAIRS = 8'd50
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
    reg       slide_select; // 0 = LCCC, 1 = Chipathon
    reg [7:0] frame_count;

    always @(posedge clk) begin
        if (!rst_n) begin
            slide_pair_count <= 8'd0;
            frame_half       <= 1'b0;
            slide_select     <= 1'b0;
            frame_count      <= 8'd0;
        end else if (frame_tick) begin
            frame_count <= frame_count + 8'd1;
            if (frame_half) begin
                frame_half <= 1'b0;
                if (slide_pair_count == (SLIDE_FRAME_PAIRS - 8'd1)) begin
                    slide_pair_count <= 8'd0;
                    slide_select <= ~slide_select;
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

    // ---------------- RGB compositor ----------------
    reg [1:0] red, green, blue;
    always @* begin
        // Black in all blanking intervals.
        red = 2'd0;
        green = 2'd0;
        blue = 2'd0;
        if (display_on) begin
            if (!slide_select) begin
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
            end else begin
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

