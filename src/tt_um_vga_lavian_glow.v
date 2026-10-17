// src/project.v
`default_nettype none

module tt_um_janiss94_LCCC_Animation (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    // Use the existing 640x480 VGA timing generator and pixel clock.
    wire       hsync;
    wire       vsync;
    wire       display_on;
    wire [9:0] pix_x;
    wire [9:0] pix_y;

    hvsync_generator hvsync_gen (
        .clk        (clk),
        .reset      (~rst_n),
        .hsync      (hsync),
        .vsync      (vsync),
        .display_on (display_on),
        .hpos       (pix_x),
        .vpos       (pix_y)
    );

    // Advance once per frame. Preserve the existing three-level glow:
    // low -> medium -> bright -> bright -> bright -> bright -> medium -> low.
    reg [7:0] frame_count;
    always @(posedge clk) begin
        if (!rst_n) begin
            frame_count <= 8'd0;
        end else if ((pix_x == 10'd0) && (pix_y == 10'd0)) begin
            frame_count <= frame_count + 8'd1;
        end
    end

    wire [2:0] glow_phase;
    wire       glow_low;
    wire       glow_mid;

    assign glow_phase = frame_count[7:5];
    assign glow_low   = (glow_phase == 3'd0) || (glow_phase == 3'd7);
    assign glow_mid   = (glow_phase == 3'd1) || (glow_phase == 3'd6);

    // Reference proportions on a 20-pixel grid.
    // White body: x = [160,480), y = [80,400), i.e. 320x320 pixels.
    // Each rectangle includes its lower bound and excludes its upper bound.
    // Draw only the white regions; no blue stripe mask is needed.
    wire logo_pixel;
    assign logo_pixel =
        // Left vertical stem: 100 pixels wide.
        ((pix_x >= 10'd160) && (pix_x < 10'd260) &&
         (pix_y >= 10'd80)  && (pix_y < 10'd400)) ||

        // Short left foot. Stop at x=300 to leave the bottom vertical gap.
        ((pix_x >= 10'd160) && (pix_x < 10'd300) &&
         (pix_y >= 10'd300) && (pix_y < 10'd400)) ||

        // Upper block of the right-hand shape.
        ((pix_x >= 10'd280) && (pix_x < 10'd420) &&
         (pix_y >= 10'd80)  && (pix_y < 10'd180)) ||

        // Right vertical stem; begins below the upper block's top edge.
        ((pix_x >= 10'd380) && (pix_x < 10'd480) &&
         (pix_y >= 10'd140) && (pix_y < 10'd400)) ||

        // Middle tooth projecting left from the right stem.
        ((pix_x >= 10'd300) && (pix_x < 10'd380) &&
         (pix_y >= 10'd220) && (pix_y < 10'd260)) ||

        // Lower right block. The gap x=[300,320) stays open to y=400.
        ((pix_x >= 10'd320) && (pix_x < 10'd480) &&
         (pix_y >= 10'd300) && (pix_y < 10'd400));

    // Detached square accent, positioned as in the reference.
    wire accent_pixel;
    assign accent_pixel =
        (pix_x >= 10'd460) && (pix_x < 10'd520) &&
        (pix_y >= 10'd40)  && (pix_y < 10'd100);

    reg [1:0] red;
    reg [1:0] green;
    reg [1:0] blue;

    always @* begin
        // RGB must be black during horizontal and vertical blanking.
        red   = 2'b00;
        green = 2'b00;
        blue  = 2'b00;

        if (display_on) begin
            // Navy background in the visible area.
            blue = 2'b01;

            if (logo_pixel) begin
                if (glow_low) begin
                    red   = 2'b01;
                    green = 2'b01;
                    blue  = 2'b10;
                end else if (glow_mid) begin
                    red   = 2'b10;
                    green = 2'b10;
                    blue  = 2'b11;
                end else begin
                    red   = 2'b11;
                    green = 2'b11;
                    blue  = 2'b11;
                end
            end

            // Preserve the original accent glow palette.
            if (accent_pixel) begin
                if (glow_low) begin
                    red   = 2'b01;
                    green = 2'b00;
                    blue  = 2'b10;
                end else if (glow_mid) begin
                    red   = 2'b10;
                    green = 2'b00;
                    blue  = 2'b11;
                end else begin
                    red   = 2'b11;
                    green = 2'b01;
                    blue  = 2'b11;
                end
            end
        end
    end

    // TinyVGA PMOD mapping.
    assign uo_out = {hsync, blue[0], green[0], red[0],
                    vsync, blue[1], green[1], red[1]};

    assign uio_out = 8'h00;
    assign uio_oe  = 8'h00;

    wire _unused;
    assign _unused = &{ena, ui_in, uio_in, 1'b0};

endmodule
