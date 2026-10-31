`timescale 1ns/1ps

 

module fpga_spi_control (
    input wire frame_job_busy_i,
    input wire upload_flow_ready_i,
    input wire [7:0] jpeg_diag_i,
    input wire [21:0] stream_size_i,
    input  wire       clk,
    input  wire       rst_n,
    input  wire       spi_sclk,
    input  wire       spi_cs_n,
    input  wire       spi_mosi,
    output wire       spi_miso,
    input  wire       capture_frozen_i,
    input  wire       frozen_frame_ready_i,
    input  wire       dump_busy_i,
    input  wire       ddr_cal_done_i,
    input  wire       ddr_cal_pass_i,
    input  wire       camera_alive_i,
    input  wire       stream_busy_i,
    input  wire       stream_ready_i,
    input  wire       stream_miso_i,
    input  wire       upload_packet_done_i,
    input  wire       upload_packet_good_i,
    input  wire       upload_header_error_i,
    input  wire       upload_overflow_i,
    input  wire [21:0] upload_payload_count_i,
    input  wire       upload_writer_active_i,
    input  wire       upload_writer_success_i,
    input  wire       upload_writer_error_i,
    input  wire       host_frame_valid_i,
    input  wire [1:0] scan_select_i,
    input  wire [15:0] camera_frame_count_i,
    input  wire [15:0] camera_line_count_i,
    input  wire [15:0] camera_line_bytes_min_i,
    input  wire [15:0] camera_line_bytes_max_i,
    input  wire [7:0] i2c_config_index_i,
    input  wire       i2c_config_done_i,
    input  wire       i2c_reconfig_active_i,
    input  wire       i2c_nack_seen_i,
    input  wire [7:0] i2c_first_nack_index_i,
    input  wire [7:0] i2c_nack_count_i,
    output reg        capture_pulse_o,
    output reg        resume_pulse_o,
    output reg        send_pulse_o,
    output reg        stream_pulse_o,
    output reg        scan_write_pulse_o,
    output reg [1:0]  scan_write_value_o,
    output reg        resolution_write_pulse_o,
    output reg [1:0]  resolution_write_value_o,
    output reg        upload_begin_pulse_o,
    output reg [1:0]  upload_begin_mode_o,
    output reg [1:0] upload_begin_1080_o,
    output reg [7:0]  upload_algorithm_flags_o,
    output wire [7:0] camera_algorithm_flags_o,
    output reg [7:0]  pwm_o,
    output reg [6:0] camera_profile_o,
    output reg camera_profile_write_o,
    output wire       stream_select_o,
    output reg        stream_host_select_o,
    output reg        stream_raw_select_o,
    output reg        stream_preview_select_o,
    output wire       upload_select_o,
    input wire student_stream_miso_i,
    output wire [1:0] student_stream_select_o,
    input wire [7:0] student_read_data_i,
    output wire [6:0] student_read_address_o,
    output reg student_write_pulse_o,
    output reg [6:0] student_write_address_o,
    output reg [7:0] student_write_data_o
);
    localparam [6:0] REG_DEVICE_ID = 7'h00;
    localparam [6:0] REG_VERSION   = 7'h01;
    localparam [6:0] REG_STATUS    = 7'h02;
    localparam [6:0] REG_CONTROL   = 7'h10;
    localparam [6:0] REG_PWM       = 7'h11;
    localparam [6:0] REG_SCRATCH   = 7'h12;
    localparam [6:0] REG_SCAN_MODE = 7'h13;
    localparam [6:0] REG_RESOLUTION = 7'h14;
    localparam [6:0] REG_CAM_FRAME_LO = 7'h20;
    localparam [6:0] REG_CAM_FRAME_HI = 7'h21;
    localparam [6:0] REG_CAM_LINES_LO = 7'h22;
    localparam [6:0] REG_CAM_LINES_HI = 7'h23;
    localparam [6:0] REG_CAM_MIN_LO   = 7'h24;
    localparam [6:0] REG_CAM_MIN_HI   = 7'h25;
    localparam [6:0] REG_CAM_MAX_LO   = 7'h26;
    localparam [6:0] REG_CAM_MAX_HI   = 7'h27;
    localparam [6:0] REG_I2C_INDEX    = 7'h28;
    localparam [6:0] REG_I2C_STATUS   = 7'h29;
    localparam [6:0] REG_I2C_FIRST_NACK = 7'h2a;
    localparam [6:0] REG_I2C_NACK_COUNT = 7'h2b;
    localparam [6:0] REG_UPLOAD_CONTROL = 7'h30;
    localparam [6:0] REG_UPLOAD_STATUS  = 7'h31;
    localparam [6:0] REG_UPLOAD_COUNT_LO = 7'h32;
    localparam [6:0] REG_UPLOAD_COUNT_MI = 7'h33;
    localparam [6:0] REG_UPLOAD_COUNT_HI = 7'h34;
    localparam [6:0] REG_ALGORITHM = 7'h35;
    reg [7:0] algorithm_flags;
    reg [1:0] student_select,student_pending;
    reg student_cs_seen;
    assign student_stream_select_o=student_select;

    reg [7:0] rx_shift = 0;
    reg [7:0] tx_shift = 0;
    reg [7:0] command = 0;
    reg [4:0] bit_count = 0;

     

    reg [6:0] write_addr = 0;
    reg [7:0] write_data = 0;
    reg       write_toggle = 0;

    reg [7:0] scratch = 0;
     

    reg [31:0] task_cookie,pending_task_cookie;
     
    assign camera_algorithm_flags_o = algorithm_flags;
    reg [2:0] write_toggle_sync = 0;
    reg       write_toggle_seen = 0;
    reg       stream_select = 1'b0;
    reg       stream_select_pending = 1'b0;
    reg       stream_cs_seen = 1'b0;
    reg       upload_select = 1'b0;
    reg       upload_select_pending = 1'b0;
    reg       upload_cs_seen = 1'b0;

    wire [7:0] status_value = {
        1'b0,
        frozen_frame_ready_i,
        stream_ready_i,
        camera_alive_i,
        ddr_cal_pass_i,
        ddr_cal_done_i,
        dump_busy_i | stream_busy_i,
        capture_frozen_i
    };

    assign student_read_address_o = command[6:0];

    function [7:0] read_register;
        input [6:0] address;
        begin
            case (address)
                7'h2c: read_register={1'b0,camera_profile_o};
                7'h2d: read_register=8'h77;
                REG_DEVICE_ID: read_register = 8'h60;
                REG_VERSION:   read_register = 8'h01;
                REG_STATUS:    read_register = status_value;
                7'h03: read_register=stream_size_i[7:0];
                7'h04: read_register=stream_size_i[15:8];
                7'h05: read_register={2'b0,stream_size_i[21:16]};
                REG_PWM:       read_register = pwm_o;
                REG_SCRATCH:   read_register = scratch;
                REG_SCAN_MODE: read_register = {6'd0, scan_select_i};
                REG_RESOLUTION: read_register = {6'd0, resolution_write_value_o};
                7'h1e: read_register=8'h52;
                7'h1f: read_register = 8'h52;  
                7'h15: read_register=8'hc4;
                7'h16: read_register=task_cookie[7:0];
                7'h17: read_register=task_cookie[15:8];
                7'h18: read_register=task_cookie[23:16];
                7'h19: read_register=task_cookie[31:24];
                7'h1a: read_register=pending_task_cookie[7:0];
                7'h1b: read_register=pending_task_cookie[15:8];
                7'h1c: read_register=pending_task_cookie[23:16];
                7'h1d: read_register=pending_task_cookie[31:24];
                REG_CAM_FRAME_LO: read_register = camera_frame_count_i[7:0];
                REG_CAM_FRAME_HI: read_register = camera_frame_count_i[15:8];
                REG_CAM_LINES_LO: read_register = camera_line_count_i[7:0];
                REG_CAM_LINES_HI: read_register = camera_line_count_i[15:8];
                REG_CAM_MIN_LO:   read_register = camera_line_bytes_min_i[7:0];
                REG_CAM_MIN_HI:   read_register = camera_line_bytes_min_i[15:8];
                REG_CAM_MAX_LO:   read_register = camera_line_bytes_max_i[7:0];
                REG_CAM_MAX_HI:   read_register = camera_line_bytes_max_i[15:8];
                REG_I2C_INDEX:    read_register = i2c_config_index_i;
                REG_I2C_STATUS:   read_register = {5'd0, i2c_nack_seen_i,
                                                   i2c_reconfig_active_i,
                                                   i2c_config_done_i};
                REG_I2C_FIRST_NACK: read_register = i2c_first_nack_index_i;
                REG_I2C_NACK_COUNT: read_register = i2c_nack_count_i;
                REG_UPLOAD_STATUS: read_register = {
                    upload_writer_error_i,
                    upload_overflow_i,
                    upload_header_error_i,
                    host_frame_valid_i,
                    upload_writer_success_i,
                    upload_writer_active_i,
                    upload_packet_good_i,
                    upload_packet_done_i
                };
                REG_ALGORITHM: read_register = algorithm_flags;
                REG_UPLOAD_COUNT_LO: read_register = upload_payload_count_i[7:0];
                REG_UPLOAD_COUNT_MI: read_register = upload_payload_count_i[15:8];
                REG_UPLOAD_COUNT_HI: read_register = {2'd0, upload_payload_count_i[21:16]};
                7'h36: read_register=8'ha3;
                7'h38: read_register=jpeg_diag_i;
                7'h37: read_register={6'd0,upload_begin_1080_o};
                default:       read_register = (address[6] || address>=7'h3a) ? student_read_data_i : 8'h00;
            endcase
        end
    endfunction

     


    assign spi_miso = spi_cs_n ? 1'b0 :
                      (student_select!=0 ? student_stream_miso_i :
                       stream_select ? stream_miso_i :
                       upload_select ? upload_flow_ready_i : tx_shift[7]);
    assign stream_select_o = stream_select;
    assign upload_select_o = upload_select;

     

    always @(posedge spi_sclk or posedge spi_cs_n) begin
        if (spi_cs_n) begin
            rx_shift <= 0;
            command <= 0;
            bit_count <= 0;
        end else begin
            rx_shift <= {rx_shift[6:0], spi_mosi};

            if (bit_count == 5'd7) begin
                command <= {rx_shift[6:0], spi_mosi};
                bit_count <= bit_count + 1'b1;
            end else if (bit_count == 5'd15) begin
                if (!command[7] && !stream_select && !upload_select && student_select==0) begin
                    write_addr <= command[6:0];
                    write_data <= {rx_shift[6:0], spi_mosi};
                    write_toggle <= ~write_toggle;
                end
                bit_count <= 0;
            end else begin
                bit_count <= bit_count + 1'b1;
            end
        end
    end

     

    always @(negedge spi_sclk or posedge spi_cs_n) begin
        if (spi_cs_n) begin
            tx_shift <= 0;
        end else if (bit_count == 5'd8) begin
            tx_shift <= read_register(command[6:0]);
        end else if (bit_count > 5'd8) begin
            tx_shift <= {tx_shift[6:0], 1'b0};
        end else if (bit_count != 0) begin
            tx_shift <= 0;
        end
         
    end

     
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            student_select<=0;student_pending<=0;student_cs_seen<=0;
            student_write_pulse_o <= 0;
            student_write_address_o <= 0;
            student_write_data_o <= 0;
            write_toggle_sync <= 0;
            write_toggle_seen <= 0;
            capture_pulse_o <= 0;
            resume_pulse_o <= 0;
            send_pulse_o <= 0;
            stream_pulse_o <= 0;
            scan_write_pulse_o <= 0;
            resolution_write_pulse_o <= 1'b0;camera_profile_write_o<=0;
            resolution_write_value_o <= 2'd0;camera_profile_o<=0;
            upload_begin_pulse_o <= 1'b0;
            upload_begin_mode_o <= 2'd0;
            upload_begin_1080_o <= 1'b0;
            upload_algorithm_flags_o <= 8'd0;
            algorithm_flags <= 8'd0;
            scan_write_value_o <= 0;
            pwm_o <= 8'h40;
            scratch <= 0;
            task_cookie <= 0;
            pending_task_cookie <= 0;
            stream_select <= 1'b0;
            stream_host_select_o <= 1'b0;
            stream_raw_select_o <= 1'b0;stream_preview_select_o <= 1'b0;
            stream_select_pending <= 1'b0;
            stream_cs_seen <= 1'b0;
            upload_select <= 1'b0;
            upload_select_pending <= 1'b0;
            upload_cs_seen <= 1'b0;
        end else begin
            if(student_select!=0)begin
                if(!spi_cs_n)student_cs_seen<=1;
                else if(student_cs_seen)begin student_select<=0;student_cs_seen<=0;end
            end
            if(student_pending!=0 && spi_cs_n)begin student_select<=student_pending;student_pending<=0;student_cs_seen<=0;end
            student_write_pulse_o <= 0;
            write_toggle_sync <= {write_toggle_sync[1:0], write_toggle};
            capture_pulse_o <= 1'b0;
            resume_pulse_o <= 1'b0;
            send_pulse_o <= 1'b0;
            stream_pulse_o <= 1'b0;
            scan_write_pulse_o <= 1'b0;
            resolution_write_pulse_o <= 1'b0;camera_profile_write_o<=0;
            upload_begin_pulse_o <= 1'b0;

            if (!stream_busy_i) begin
                stream_select <= 1'b0;
                stream_cs_seen <= 1'b0;
            end
            if (upload_packet_done_i) begin
                upload_select <= 1'b0;
                upload_select_pending <= 1'b0;
                upload_cs_seen <= 1'b0;
            end

             



            if (stream_select) begin
                if (!spi_cs_n)
                    stream_cs_seen <= 1'b1;
                else if (stream_cs_seen) begin
                    stream_select <= 1'b0;
                    stream_cs_seen <= 1'b0;
                end
            end
            if (upload_select) begin
                if (!spi_cs_n)
                    upload_cs_seen <= 1'b1;
                else if (upload_cs_seen) begin
                    upload_select <= 1'b0;
                    upload_select_pending <= 1'b0;
                    upload_cs_seen <= 1'b0;
                end
            end

             


            if (stream_select_pending && spi_cs_n) begin
                stream_select <= 1'b1;
                stream_select_pending <= 1'b0;
                stream_cs_seen <= 1'b0;
            end
            if (upload_select_pending && spi_cs_n) begin
                upload_select <= 1'b1;
                upload_select_pending <= 1'b0;
                upload_cs_seen <= 1'b0;
            end

                if (write_toggle_sync[2] != write_toggle_seen) begin
                    write_toggle_seen <= write_toggle_sync[2];
                     



                    if (write_addr != REG_UPLOAD_CONTROL) begin
                        upload_select <= 1'b0;
                        upload_select_pending <= 1'b0;
                        upload_cs_seen <= 1'b0;
                    end
                     


                    if(!frame_job_busy_i || write_addr==REG_PWM || write_addr>=7'h65 || (write_addr>=7'h3a && write_addr<=7'h3f))case (write_addr)
                    REG_CONTROL: begin
                        capture_pulse_o <= write_data[0];
                        resume_pulse_o <= write_data[1];
                        send_pulse_o <= write_data[2];
                        stream_pulse_o <= write_data[3];
                        if (write_data[3]) begin
                            stream_host_select_o <= write_data[5];
                            stream_raw_select_o <= write_data[6];stream_preview_select_o <= write_data[7];
                        end
                         



                        if (write_data[4])
                            stream_select_pending <= 1'b1;
                    end
                     

                    REG_ALGORITHM: algorithm_flags <= write_data & 8'h7f;
                    REG_PWM: pwm_o <= write_data;
                    7'h2c: if(!stream_busy_i && !dump_busy_i && !upload_writer_active_i && write_data[7]==0 && write_data[2:0]<=4 && write_data[4:3]<=2 && write_data[6:5]<=2)begin
                        camera_profile_o<=write_data[6:0];camera_profile_write_o<=1;
                    end
                    7'h16: pending_task_cookie[7:0] <= write_data;
                    7'h17: pending_task_cookie[15:8] <= write_data;
                    7'h18: pending_task_cookie[23:16] <= write_data;
                    7'h19: pending_task_cookie[31:24] <= write_data;
                    REG_SCRATCH: scratch <= write_data;
                    REG_SCAN_MODE: begin
                        scan_write_value_o <= write_data[1:0];
                        scan_write_pulse_o <= 1'b1;
                    end
                    REG_RESOLUTION: begin
                        resolution_write_value_o <= write_data[1:0];
                        resolution_write_pulse_o <= 1'b1;
                    end
                    REG_UPLOAD_CONTROL: begin
                        if (write_data[0]) begin
                            upload_begin_pulse_o <= 1'b1;
                            upload_begin_mode_o <= write_data[3:2];
                            upload_begin_1080_o <= write_data[6:5];
                            upload_algorithm_flags_o <= algorithm_flags;
                            upload_select <= 1'b0;
                            upload_select_pending <= 1'b0;
                            upload_cs_seen <= 1'b0;
                        end
                        if (write_data[1] && !stream_select)
                            upload_select_pending <= 1'b1;
                    end
                    default: begin
                        if(write_addr==7'h4c && write_data[0])task_cookie<=pending_task_cookie;
                        if(write_addr==7'h4b && !stream_select && !upload_select)begin
                            if(write_data==1 || write_data==2)student_pending<=write_data[1:0];
                        end
                        if(write_addr[6] || write_addr>=7'h3a)begin
                            student_write_pulse_o<=1;
                            student_write_address_o<=write_addr;
                            student_write_data_o<=write_data;
                        end
                    end
                endcase
            end
        end
    end
endmodule
