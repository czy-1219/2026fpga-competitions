`timescale 1ns/1ps

 

module frame_capture_ctrl (
    input  wire pclk,
    input  wire rst_n,
    input  wire sensor_vsync,
    input  wire sensor_data_en,
    input  wire capture_toggle_async,
    input  wire resume_toggle_async,
    output wire writer_vsync,
    output wire writer_data_en,
    output reg  frozen,
    output reg  capture_done_toggle
);
    reg [2:0] capture_sync;
    reg [2:0] resume_sync;
    reg capture_seen;
    reg resume_seen;
    reg vsync_d;
    reg freeze_pending;
    reg resume_pending;

    wire vsync_rise = sensor_vsync && !vsync_d;
    wire vsync_fall = !sensor_vsync && vsync_d;

    assign writer_vsync  = frozen ? 1'b0 : sensor_vsync;
    assign writer_data_en = frozen ? 1'b0 : sensor_data_en;

    always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            capture_sync <= 0;
            resume_sync <= 0;
            capture_seen <= 0;
            resume_seen <= 0;
            vsync_d <= 0;
            freeze_pending <= 0;
            resume_pending <= 0;
            frozen <= 0;
            capture_done_toggle <= 0;
        end else begin
            capture_sync <= {capture_sync[1:0], capture_toggle_async};
            resume_sync <= {resume_sync[1:0], resume_toggle_async};
            vsync_d <= sensor_vsync;

            if (capture_sync[2] != capture_seen) begin
                capture_seen <= capture_sync[2];
                if (!frozen)
                    freeze_pending <= 1'b1;
            end

            if (resume_sync[2] != resume_seen) begin
                resume_seen <= resume_sync[2];
                if (frozen)
                    resume_pending <= 1'b1;
            end

             

            if (!frozen && freeze_pending && vsync_fall) begin
                frozen <= 1'b1;
                freeze_pending <= 1'b0;
                capture_done_toggle <= ~capture_done_toggle;
            end

             
            if (frozen && resume_pending && vsync_rise) begin
                frozen <= 1'b0;
                resume_pending <= 1'b0;
            end
        end
    end
endmodule

