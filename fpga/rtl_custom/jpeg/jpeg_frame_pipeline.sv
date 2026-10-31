`timescale 1ns/1ps
 


module jpeg_frame_pipeline (
    input wire clk,jpeg_fast_clk,rst_n,start_i,
    input wire [10:0] width_i,height_i,
    input wire [1:0] scan_mode_i,frame_mode_i,
    input wire [7:0] bw_margin_i,algorithm_flags_i,
    input wire canonical_input_i,raw_output_i,preview_i,
    input wire preview_direct_i,
    input wire [31:0] preview_base_i,
    output wire dump_start_o,dump_direct_o,
    output wire [31:0] dump_base_o,dump_size_o,
    input wire dump_busy_i,dump_done_i,dump_valid_i,
    input wire [7:0] dump_data_i,output wire dump_ready_o,
    output wire [31:0] araddr_o,awaddr_o,
    output wire arvalid_o,awvalid_o,wvalid_o,
    input wire arready_i,awready_i,wready_i,
    output wire [127:0] wdata_o,output wire [15:0] wstrb_o,
    input wire rvalid_i,bvalid_i,input wire [127:0] rdata_i,
    input wire [1:0] rresp_i,bresp_i,output wire rready_o,bready_o,
    input wire spi_sclk_i,spi_cs_n_i,stream_enable_i,
    output wire spi_miso_o,claim_o,ready_o,
    output wire [21:0] jpeg_size_o,output wire [7:0] diag_status_o
);
    reg [1:0] phase;reg direct_preview;reg [31:0] preview_base;
    reg [10:0] width,height;reg raw_output,preview,preview_fast;
     

    wire [10:0] encode_width=preview_fast ? (width>>2) : preview ? (width>>1) : width;
    wire [10:0] encode_height=preview_fast ? (height>>2) : preview ? (height>>1) : height;
    reg encode_start,encode_seen,error;
    wire preprocessing=phase==1;
    wire encoding=phase==2;
    wire pipeline_start=start_i && phase==0;
    wire direct_start=preview_i && !raw_output_i && preview_direct_i;
    wire processor_start=pipeline_start && !direct_start;
    wire proc_dump_start,proc_dump_ready,proc_claim,word_valid,word_last,word_ready;
    wire [127:0] word_data;
    wire bw_start,bw_valid,bw_gray_enable,bw_response_ready,bw_ready,bw_result_valid;
    wire [15:0] bw_pixel,bw_result;
    wire [7:0] bw_gray,bw_offset;
    frame_pixel_processor u_processor (
        .clk(clk),.rst_n(rst_n),.start_i(processor_start),.width_i(width_i),.height_i(height_i),
        .scan_mode_i(scan_mode_i),.frame_mode_i(frame_mode_i),.bw_margin_i(bw_margin_i),
        .algorithm_flags_i(algorithm_flags_i),.bypass_spatial_i(canonical_input_i),
        .dump_start_o(proc_dump_start),.dump_data_i(dump_data_i),
        .dump_valid_i(dump_valid_i && preprocessing),.dump_ready_o(proc_dump_ready),.claim_o(proc_claim),
        .word_data_o(word_data),.word_valid_o(word_valid),.word_last_o(word_last),.word_ready_i(word_ready),
        .bw_frame_start_o(bw_start),.bw_request_valid_o(bw_valid),.bw_request_pixel_o(bw_pixel),
        .bw_request_gray_enable_o(bw_gray_enable),.bw_request_gray_o(bw_gray),.bw_request_offset_o(bw_offset),
        .bw_response_ready_o(bw_response_ready),.bw_request_ready_i(bw_ready),
        .bw_response_valid_i(bw_result_valid),.bw_response_pixel_i(bw_result)
    );
    wire bw_mem_request,bw_mem_write,bw_mem_error;
    wire [31:0] bw_mem_address;
    wire [127:0] bw_mem_data;
    wire [15:0] bw_mem_strobe;
    wire request_ready,request_response,request_error;
    wire [127:0] request_data;
    reg request_owner_bw,request_last;
    reg [31:0] store_offset;
     


    reg [7:0] preview_word;
    reg preview_odd_row;
    reg [63:0] preview_half;
    wire [63:0] preview_sample={word_data[111:96],word_data[79:64],word_data[47:32],word_data[15:0]};
    wire preview_skip=preview && (preview_odd_row || !preview_word[0]);
    wire [127:0] store_data=preview ? {preview_sample,preview_half} : word_data;
    scan_bw_ddr_engine u_bw (
        .clk(clk),.rst_n(rst_n),.frame_start_i(bw_start),.frame_width_i(width_i),.frame_height_i(height_i),
        .pixel_valid_i(bw_valid),.pixel_ready_o(bw_ready),.pixel_i(bw_pixel),.offset_i(bw_offset),
        .gray_override_enable_i(bw_gray_enable),.gray_override_i(bw_gray),
        .pixel_valid_o(bw_result_valid),.pixel_ready_i(bw_response_ready),.pixel_o(bw_result),
        .memory_request_o(bw_mem_request),.memory_write_o(bw_mem_write),.memory_address_o(bw_mem_address),
        .memory_data_o(bw_mem_data),.memory_strobe_o(bw_mem_strobe),
        .memory_ready_i(request_ready && preprocessing),
        .memory_response_i(request_response && request_owner_bw),.memory_error_i(request_error),
        .memory_response_data_i(request_data),.error_o(bw_mem_error)
    );
    wire pre_request=preprocessing && (bw_mem_request || (word_valid && !preview_skip));
    assign word_ready=preprocessing && !bw_mem_request && (preview_skip || request_ready);
    wire [31:0] pre_araddr,pre_awaddr;
    wire pre_arvalid,pre_awvalid,pre_wvalid,pre_rready,pre_bready;
    wire [127:0] pre_wdata;
    wire [15:0] pre_wstrb;
    axi_single_request u_preprocess_memory (
        .clk(clk),.rst_n(rst_n),.request_i(pre_request),
        .write_i(bw_mem_request ? bw_mem_write : 1'b1),
        .address_i(bw_mem_request ? bw_mem_address : 32'h0280_0000+store_offset),
        .data_i(bw_mem_request ? bw_mem_data : store_data),
        .strobe_i(bw_mem_request ? bw_mem_strobe : 16'hffff),
        .ready_o(request_ready),.response_o(request_response),.error_o(request_error),.response_data_o(request_data),
        .araddr_o(pre_araddr),.awaddr_o(pre_awaddr),.arvalid_o(pre_arvalid),.awvalid_o(pre_awvalid),.wvalid_o(pre_wvalid),
        .arready_i(arready_i && preprocessing),.awready_i(awready_i && preprocessing),.wready_i(wready_i && preprocessing),
        .wdata_o(pre_wdata),.wstrb_o(pre_wstrb),.rvalid_i(rvalid_i && preprocessing),.bvalid_i(bvalid_i && preprocessing),
        .rdata_i(rdata_i),.rresp_i(rresp_i),.bresp_i(bresp_i),.rready_o(pre_rready),.bready_o(pre_bready)
    );
    wire enc_start_dump,enc_direct,enc_dump_ready,enc_claim,enc_ready,enc_axi_active,enc_axi_error;
    wire [31:0] enc_dump_base,enc_dump_size,enc_awaddr;
    wire [127:0] enc_wdata;
    wire [15:0] enc_wstrb;
    wire enc_awvalid,enc_wvalid;
    wire [7:0] enc_diag;
    wire mcu_busy,mcu_done,mcu_error,mcu_valid,mcu_rready,mcu_arvalid;
    wire [31:0] mcu_araddr;
    wire [7:0] mcu_data;
    jpeg_mcu_reader u_mcu_reader (
        .clk(clk),.rst_n(rst_n),.start_i(enc_start_dump && !enc_direct),.width_i(preview && !direct_preview ? width>>1 : width),.height_i(preview && !direct_preview ? height>>1 : height),.half_scale_i(preview_fast || direct_preview),
        .source_camera_i(direct_preview),.camera_base_i(preview_base),
        .busy_o(mcu_busy),.done_o(mcu_done),.error_o(mcu_error),.araddr_o(mcu_araddr),.arvalid_o(mcu_arvalid),
        .arready_i(arready_i && encoding),.rdata_i(rdata_i),.rvalid_i(rvalid_i && encoding),.rresp_i(rresp_i),
        .rready_o(mcu_rready),.data_o(mcu_data),.valid_o(mcu_valid),.ready_i(enc_dump_ready && !enc_direct)
    );
    wire [11:0] padded_height=({1'b0,encode_height}+12'd15)&12'hff0;
    wire [21:0] padded_bytes=(encode_width*padded_height)<<1;
    jpeg_stream_transport u_transport (
        .clk(clk),.jpeg_fast_clk(jpeg_fast_clk),.rst_n(rst_n),.start_i(encode_start),
        .raw_output_i(raw_output),
        .frame_width_i({1'b0,encode_width}),.frame_height_i({1'b0,encode_height}),.frame_payload_bytes_i(raw_output ? ((width*height)<<1) : padded_bytes),
        .scan_mode_i(2'd0),.frame_mode_i(frame_mode_i),.host_source_i(1'b1),.bw_margin_i(8'd0),
        .dump_start_o(enc_start_dump),.dump_direct_o(enc_direct),.dump_base_o(enc_dump_base),.dump_size_o(enc_dump_size),
        .dump_busy_i(enc_direct ? dump_busy_i : mcu_busy),.dump_data_i(enc_direct ? dump_data_i : mcu_data),
        .dump_valid_i(enc_direct ? dump_valid_i : mcu_valid),.dump_ready_o(enc_dump_ready),
        .dump_done_i(enc_direct ? dump_done_i : mcu_done),
        .axi_awaddr_o(enc_awaddr),.axi_awlen_o(),.axi_awvalid_o(enc_awvalid),.axi_awready_i(awready_i && encoding),
        .axi_wdata_o(enc_wdata),.axi_wstrb_o(enc_wstrb),.axi_wlast_o(),.axi_wvalid_o(enc_wvalid),.axi_wready_i(wready_i && encoding),
        .axi_bvalid_i(bvalid_i && encoding),.axi_bresp_i(bresp_i),.axi_active_o(enc_axi_active),.axi_error_o(enc_axi_error),
        .spi_sclk_i(spi_sclk_i),.spi_cs_n_i(spi_cs_n_i),.stream_enable_i(stream_enable_i),
        .spi_miso_o(spi_miso_o),.claim_o(enc_claim),.ready_o(enc_ready),.jpeg_size_o(jpeg_size_o),.diag_status_o(enc_diag)
    );
    assign claim_o=phase!=0;
    assign ready_o=encoding && enc_ready && !error && !enc_axi_error;
    assign diag_status_o={error|enc_axi_error,ready_o,enc_diag[5:0]};
    assign dump_start_o=preprocessing ? proc_dump_start : enc_start_dump && enc_direct;
    assign dump_direct_o=encoding && enc_direct;
    assign dump_base_o=enc_dump_base;
    assign dump_size_o=preprocessing ? (width*height)<<1 : enc_dump_size;
    assign dump_ready_o=preprocessing ? proc_dump_ready : enc_direct && enc_dump_ready;
    assign araddr_o=encoding ? mcu_araddr : pre_araddr;
    assign arvalid_o=encoding ? mcu_arvalid : pre_arvalid;
    assign rready_o=encoding ? mcu_rready : pre_rready;
    assign awaddr_o=encoding ? enc_awaddr : pre_awaddr;
    assign awvalid_o=encoding ? enc_awvalid : pre_awvalid;
    assign wdata_o=encoding ? enc_wdata : pre_wdata;
    assign wstrb_o=encoding ? enc_wstrb : pre_wstrb;
    assign wvalid_o=encoding ? enc_wvalid : pre_wvalid;
    assign bready_o=encoding ? 1'b1 : pre_bready;
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            direct_preview<=0;preview_base<=0;phase<=0;width<=0;height<=0;raw_output<=0;preview<=0;preview_fast<=0;encode_start<=0;encode_seen<=0;error<=0;
            request_owner_bw<=0;request_last<=0;store_offset<=0;preview_word<=0;preview_odd_row<=0;preview_half<=0;
        end else begin
            encode_start<=0;
            if(pipeline_start)begin
                direct_preview<=direct_start;preview_base<=preview_base_i;encode_start<=direct_start;
                preview_word<=0;preview_odd_row<=0;preview_half<=0;
                phase<=direct_start ? 2 : 1;width<=width_i;height<=height_i;raw_output<=raw_output_i && !preview_i;preview<=preview_i;preview_fast<=preview_i && raw_output_i;encode_seen<=0;error<=0;store_offset<=0;
            end
            if(preprocessing && preview && word_valid && word_ready)begin
                if(!preview_odd_row && !preview_word[0])preview_half<=preview_sample;
                if(preview_word==((width>>3)-1))begin preview_word<=0;preview_odd_row<=!preview_odd_row;end
                else preview_word<=preview_word+1'b1;
            end
             
            if(preprocessing && preview && !proc_claim && request_ready && store_offset!=0 && !error)begin phase<=2;encode_start<=1;end
            if(pre_request && request_ready)begin
                request_owner_bw<=bw_mem_request;request_last<=!bw_mem_request && word_last;
                if(!bw_mem_request)store_offset<=store_offset+16;
            end
            if(request_response && preprocessing)begin
                if(request_error)error<=1;
                if(!preview && !request_owner_bw && request_last && !request_error && !error)begin phase<=2;encode_start<=1;end
            end
            if(bw_mem_error || mcu_error || enc_axi_error)error<=1;
            if(encoding && enc_claim)encode_seen<=1;
            if(encoding && encode_seen && !enc_claim)phase<=0;
        end
    end
endmodule
