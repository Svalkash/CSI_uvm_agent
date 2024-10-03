//
// File : csi_monitor.sv
//
// Created:
//          by HDL Designers Team
//          of Electronics Design Center "OhT"
//          www.overhitech.com
//
//
// File Description:
//
//% Монитор CSI
//

`ifndef __CSI_MlONITOR_SV__
    `define __CSI_MONITOR_SV__    

    class monitor_c extends uvm_subscriber#(packet_item_c);

        img_gen_pkg::agent_base_c p_agent;
        config_c   cfg;
    
        uvm_analysis_port#(vivo_core_pkg::frame_item_c) frame_aport;
        uvm_analysis_port#(vivo_core_pkg::pxl_item_c)   pxl_aport;

        packet_item_c packet_buf[];

        //------------------------------------------------------------------------------------------------------------------
        // Signal data
        //------------------------------------------------------------------------------------------------------------------
        
        cFLSE_state_t cFLSE_state = FL_NO; //0 - frame not started, 1 - check lineStart / frameEnd, 2 - check package, 3 - check lineEnd
        int line_n = 0; //line count for current frame
        int frame_n = 0; //current frame num
        packetType_t frameType;
    
        int rPack_vcid;
        //packetType_t rPack_dtype;

        vivo_core_pkg::pxl_item_c collected_pxl; //not needed: pixel is sent immediately
        vivo_core_pkg::frame_item_c collected_frame;
    
        //for frame/line number checking
        int frame_n_rec = 1; //current frame num - recovered
        int frame_n_period = -1;
        int frame_n_last = -1;
    
        int line_n_rec = 1; //line count for current frame - recovered from packets
        int line_n_start = -1;
        int line_n_end = -1;
        int line_n_fieldfirst = -1;
        int line_n_fieldcnt = -1;
        int line_n_last = -1;
        int line_n_period = -1; // interlaced frames are not supported for now
        bit first_line = -1;
    
        //------------------------------------------------------------------------------------------------------------------
        // UVM automation macros
        //------------------------------------------------------------------------------------------------------------------

        `uvm_component_utils_begin(csi_pkg::monitor_c)
        `uvm_field_object  (p_agent, UVM_ALL_ON | UVM_NOCOMPARE)
        `uvm_field_object  (cfg, UVM_ALL_ON | UVM_NOCOMPARE)
        `uvm_component_utils_end

        //------------------------------------------------------------------------------------------------------------------
        // constructor
        //------------------------------------------------------------------------------------------------------------------

        function new (string name = "csi_monitor", uvm_component parent = null);
            super.new(name, parent);
        endfunction : new

        //------------------------------------------------------------------------------------------------------------------
        // build routine
        //------------------------------------------------------------------------------------------------------------------

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            // create queues
            packet_buf = new[1];
            // create aports
            frame_aport = new("monitor_frame_aport", this);
            pxl_aport = new("monitor_pxl_aport", this);
        endfunction: build_phase

        //------------------------------------------------------------------------------------------------------------------
        // write function
        //------------------------------------------------------------------------------------------------------------------

        function void write (packet_item_c t);
            uvm_report_info("CSI_MON", $sformatf("CSI monitor has recieved the following packet:\n%s", t.sprint), UVM_MEDIUM);
            processPacket(t);
        endfunction : write 

        //------------------------------------------------------------------------------------------------------------------
        // Packet functions
        //------------------------------------------------------------------------------------------------------------------
    
        function void processPacket(packet_item_c rPack);
            packetType_t rPack_dtype = rPack.get_packetType();
        
            //check packet type
            if (checkPacket_FLSE(rPack))
                return;
            uvm_report_info("LOG", $sformatf("Received packet:\n%s", rPack.sprint()), UVM_HIGH);
            
            //work with the packet
            if (rPack.is_long())
                case(rPack_dtype)
                    LP_null: uvm_report_info("CSI_MON", $sformatf("Received null data"), UVM_HIGH);
                    LP_blank: uvm_report_info("CSI_MON", $sformatf("Received blank data"), UVM_HIGH);
                    LP_embedded:  uvm_report_info("CSI_MON", $sformatf("Received embedded data: %p", rPack.data), UVM_HIGH);
                    default: saveDataPacket(rPack); //function for ALL data packets;
                endcase        
            else
                case(rPack_dtype)
                    SP_frameStart: begin
                        frame_n_rec = rPack.wordCount; //recover number
                        uvm_report_info("CSI_MON", $sformatf("Frame Start - %0d", frame_n_rec), UVM_MEDIUM);
                        line_n = 1; //reset line number
                        //create frame, but it's empty without size data
                        if (line_n_period <= 1 || line_n_fieldcnt == line_n_period) begin
                            frame_n = (line_n_period > 1) ? frame_n + 1 : frame_n_rec; //interlaced or just first frame
                            collected_frame = vivo_core_pkg::frame_item_c::type_id::create($sformatf("csi_collected_frame_#%0d", frame_n), this);
                            collected_frame.idx = frame_n;
                        end
                
                        //check frame number
                        if (frame_n_last == -1)
                            frame_n_last = frame_n_rec;
                        else if (frame_n_rec == 0) begin
                            if (frame_n_last != 0)
                                uvm_report_error("CSI_FRAME_NUM_ORDER", $sformatf("Illegal frame order! Current - %0d, last - 0 (no info: must ALWAYS be zero)",
                                            frame_n_rec));
                        end
                        else begin
                            if (frame_n_rec != 1 && frame_n_last != frame_n_rec - 1
                                    || frame_n_rec == 1 && frame_n_period != -1 && frame_n_last != frame_n_period)
                                uvm_report_error("CSI_FRAME_NUM_ORDER", $sformatf("Illegal frame order! Current - %0d, last - %0d, period - %0d",
                                            frame_n_rec,frame_n_last, frame_n_period));
                            //remember new data
                            if (frame_n_rec == 1 && frame_n_last != -1)
                                frame_n_period = frame_n_last; //no error => nothing changes, error => recovery
                            frame_n_last = frame_n_rec;
                        end
                    end
            
                    SP_frameEnd: begin
                        uvm_report_info("CSI_MON", $sformatf("Frame End - %0d", rPack.wordCount), UVM_MEDIUM);
                        //check frame number from start packet = end packet - don't mind if flag checkOrder is not set
                        if (frame_n_rec != rPack.wordCount)
                            uvm_report_error("CSI_FE_NUM_MISMATCH", $sformatf("Frame End packet frame number mismatch: expected %0d, received %0d",
                                        frame_n_rec, rPack.wordCount));
                        if (line_n_period <= 1 || line_n_fieldcnt == line_n_period)
                            sendFrame();
                    end
            
                    SP_lineStart: begin
                        line_n_rec = rPack.wordCount;
                        uvm_report_info("CSI_MON", $sformatf("Line Start - %0d", line_n_rec), UVM_MEDIUM);
                        //check line number and recovered number
                        if (line_n != 1 && line_n_period >= 1 && line_n_rec != 0 && (line_n + (line_n_period - 1)) != line_n_rec)
                            uvm_report_error("CSI_LS_NUM_MISMATCH", $sformatf("Line Start packet line number mismatch: expected %0d, received %0d",
                                        line_n, line_n_rec));
                        //check if all periods are stable                
                        if (line_n_last == -1) begin
                            line_n = line_n_rec;
                            line_n_last = line_n_rec;
                            line_n_start = line_n_rec;
                            line_n_fieldfirst = line_n_rec;
                            line_n_fieldcnt = 1;
                        end
                        else if (line_n_rec == 0) begin
                            if (line_n_last != 0)
                                uvm_report_error("CSI_LINE_NUM_ORDER", $sformatf("Illegal line order! Current - %0d, last - 0 (no info: must ALWAYS be zero)", line_n_rec));
                            line_n_start = 0;
                            line_n_end = 0;
                            line_n_period = 0;
                            line_n_fieldfirst = 0;
                        end
                        else begin
                            if (line_n_period == -1)
                                line_n_period = line_n_rec - line_n_last;
                            if (line_n != 1 && line_n_period >= 1 && line_n_rec != 0)
                                line_n += (line_n_period - 1); //correct for current period
                            if (line_n != 1 && line_n_last != line_n_rec - line_n_period)
                                uvm_report_error("CSI_LINE_NUM_ORDER", $sformatf("Illegal line order! Current - %0d, last - %0d, period - %0d",
                                            line_n_rec, line_n_last, line_n_period));
                            else if (line_n == 1) begin
                                line_n = line_n_rec;
                                if (line_n_rec > line_n_period)
                                    uvm_report_error("CSI_LINE_NUM_ORDER", $sformatf("Illegal 'first' line number in field! Current - %0d, period - %0d",
                                                line_n_rec, line_n_period));
                                //check how much fields before new REAL frame
                                if (line_n_rec == line_n_fieldfirst)
                                    line_n_fieldcnt = 1;
                                else 
                                    ++line_n_fieldcnt;
                                if (line_n_fieldcnt > line_n_period)
                                    uvm_report_error("CSI_LINE_NUM_ORDER", $sformatf("Too much fields! Field cnt - %0d, line num period - %0d",
                                                line_n_fieldcnt, line_n_period));
                                //check field order
                                if (cfg.checkFieldOrder) begin
                                    if (line_n_rec != line_n_start % line_n_period + 1)
                                        uvm_report_error("CSI_LINE_NUM_ORDER", $sformatf("Illegal 'first' line number in field! Current - %0d, last - %0d, period - %0d",
                                                    line_n_rec, line_n_start, line_n_period));
                                    if (line_n_end > 0 && line_n_last != line_n_end + 1 && line_n_last != line_n_end - line_n_period + 1)
                                        uvm_report_error("CSI_LINE_NUM_ORDER", $sformatf("Illegal 'last' line number in field! Current - %0d, last - %0d, period - %0d",
                                                    line_n_last, line_n_end, line_n_period));
                                    line_n_start = line_n_rec;
                                    line_n_end = line_n_last;
                                end
                            end
                            //remember new data
                            line_n_last = line_n_rec;
                        end
                    end
            
                    SP_lineEnd: begin
                        uvm_report_info("CSI_MON", $sformatf("Line End - %0d", rPack.wordCount), UVM_MEDIUM);
                        //check line number
                        if (line_n_rec != rPack.wordCount)
                            uvm_report_error("CSI_LE_NUM_MISMATCH", $sformatf("Line End packet line number mismatch: expected %0d, received %0d",
                                        line_n_rec, rPack.wordCount));
                    end
                
                    default:
                        uvm_report_error("CSI_UNKNOWN", $sformatf("Unknown packet type: %0d", rPack_dtype));
                endcase
        endfunction: processPacket

    
        //checks if packet type is valid and returns it (or returns invalid_packet type)
        function int checkPacket_FLSE(packet_item_c rPack);
            packetType_t rPack_dtype = rPack.get_packetType();
            if (rPack.is_long()) //too lazy to write all types in EVERY case
                
                case(rPack_dtype)
                    LP_null, LP_blank: ;
                    LP_embedded:
                        case(cFLSE_state)
                            FL_NO: uvm_report_error("CSI_CFSE", $sformatf("Data out of frame! Packet type: %0d", rPack_dtype));
                            FL_FSLE, FL_LS, FL_DATA: ;
                        endcase//function for ALL data packets;
                    default:
                        case(cFLSE_state)
                            FL_NO:
                                uvm_report_error("CSI_CFSE", $sformatf("Data out of frame! Packet type: %0d", rPack_dtype));
                            FL_FSLE:
                                if (cfg.checkLineSE) uvm_report_error("CSI_CLSE", $sformatf("Data out of line! Packet type: %0d", rPack_dtype));
                                else begin
                                    cFLSE_state = FL_DATA;
                                    return 0;
                                end
                            FL_LS:
                            begin
                                cFLSE_state = FL_DATA;
                                return 0;
                            end
                            FL_DATA:
                                if (cfg.checkLineSE) uvm_report_error("CSI_CLSE", $sformatf("New line data without Line End! Packet type: %0d", rPack_dtype));
                                else begin
                                    cFLSE_state = FL_DATA;
                                    return 0;
                                end
                        endcase//function for ALL data packets;
                endcase
            else //short packet - work other options
            case(cFLSE_state)
                FL_NO:
                    case(rPack_dtype)
                        SP_frameStart:    begin
                            cFLSE_state = FL_FSLE;
                            return 0;
                        end
                        SP_frameEnd:    uvm_report_error("CSI_CFSE", $sformatf("Frame End without start! Packet type: %0d", rPack_dtype));
                        SP_lineStart,
                        SP_lineEnd:     uvm_report_error("CSI_CLSE", $sformatf("Line S/E out of frame! Packet type: %0d", rPack_dtype));
                        default:        uvm_report_error("CSI_UNKNOWN", $sformatf("Unknown packet type: %0d", rPack_dtype));
                    endcase
                FL_FSLE:
                    case(rPack_dtype)
                        SP_frameStart:    uvm_report_error("CSI_CFSE", $sformatf("Repeated Frame Start! Packet type: %0d", rPack_dtype));
                        SP_frameEnd:    begin
                            cFLSE_state = FL_NO;
                            return 0;
                        end
                        SP_lineStart:    begin
                            cFLSE_state = FL_LS;
                            return 0;
                        end
                        SP_lineEnd:     uvm_report_error("CSI_CLSE", $sformatf("Line End without Line Start! Packet type: %0d", rPack_dtype));
                        default:        uvm_report_error("CSI_UNKNOWN", $sformatf("Unknown packet type: %0d", rPack_dtype));
                    endcase
                FL_LS:
                    case(rPack_dtype)
                        SP_frameStart:    uvm_report_error("CSI_CFSE", $sformatf("Repeated Frame Start! Packet type: %0d", rPack_dtype));
                        SP_frameEnd:    uvm_report_error("CSI_CLSE", $sformatf("Frame End after Line Start (no data)! Packet type: %0d", rPack_dtype));
                        SP_lineStart:    uvm_report_error("CSI_CLSE", $sformatf("Repeated Line Start! Packet type: %0d", rPack_dtype));
                        SP_lineEnd:        uvm_report_error("CSI_CLSE", $sformatf("Line End without data! Packet type: %0d", rPack_dtype));
                        default:        uvm_report_error("CSI_UNKNOWN", $sformatf("Unknown packet type: %0d", rPack_dtype));
                    endcase
                FL_DATA:
                    case(rPack_dtype)
                        SP_frameStart:    uvm_report_error("CSI_CFSE", $sformatf("Repeated Frame Start! Packet type: %0d", rPack_dtype));
                        SP_frameEnd:    if (cfg.checkLineSE) uvm_report_error("CSI_CLSE", $sformatf("Frame End without Line End! Packet type: %0d", rPack_dtype));
                            else begin
                                cFLSE_state = FL_NO;
                                return 0;
                            end
                        SP_lineStart:    if (cfg.checkLineSE) uvm_report_error("CSI_CLSE", $sformatf("New Line Start without Line End! Packet type: %0d", rPack_dtype));
                            else begin
                                cFLSE_state = FL_LS;
                                return 0;
                            end
                        SP_lineEnd:        begin
                            cFLSE_state = FL_FSLE;
                            return 0;
                        end
                        default:        uvm_report_error("CSI_UNKNOWN", $sformatf("Unknown packet type: %0d", rPack_dtype));
                    endcase
                default: uvm_report_error("CSI_CFLSE", "Invalid FLSE state");
            endcase
            //if not returned, here's error probably
            return 1;
        endfunction: checkPacket_FLSE
    
    
        function void saveDataPacket(packet_item_c rPack);
            packetType_t rPack_dtype = rPack.get_packetType();
        
            //Integrity and type is checked
            //Need to compare important field with frame_item
            //And save it for later
            //uvm_report_info("CSI_MON", $sformatf("line_n_fieldfirst %d line_n %d", line_n_fieldfirst, line_n), UVM_MEDIUM);
        
            //check format AND length (line VS frame) and reject line if needed
            if (line_n_fieldfirst < 1 && line_n == 1 || line_n == line_n_fieldfirst) begin
                //assign data type
                frameType = rPack_dtype;
                //for checking
                collected_frame.col_scheme              = frameFormats[frameType].col_scheme;
                collected_frame.rgb_subpxl_scheme     = frameFormats[frameType].rgb_subpxl_scheme;
                collected_frame.chr_subsampling     = frameFormats[frameType].chr_subsampling;
                collected_frame.layer0_dwidth          = frameFormats[frameType].dwidth[0];
                collected_frame.layer1_dwidth          = frameFormats[frameType].dwidth[1];
                collected_frame.layer2_dwidth          = frameFormats[frameType].dwidth[2];
                //length - CASE inside
                collected_frame.width = rPack.get_pixel_length(line_n);
            end
            else begin
                if (frameType != rPack_dtype) begin
                    uvm_report_error("CSI_LINEMM_FORM", $sformatf("Line data format mismatch: frame = %x, line (%0d) = %x", frameType, line_n, rPack_dtype));
                    return;
                end
                //length - CASE inside
                if (collected_frame.width != rPack.get_pixel_length(line_n)) begin
                    uvm_report_error("CSI_LINEMM_LEN", $sformatf("Line length mismatch: frame = %0d, line (%0d) = %0d",
                                collected_frame.width, line_n, rPack.wordCount));
                    return;
                end
            end
            //now it's still useless, send entire packet to buffer
            if (packet_buf.size() < line_n)
                packet_buf = new[line_n](packet_buf);
            packet_buf[line_n - 1] = rPack; //changing nums, so they start from 0
            uvm_report_info("LOG", $sformatf("Data packet saved (line %0d)", line_n-1), UVM_MEDIUM);
            //increase line number/count
            ++line_n;
        endfunction: saveDataPacket
    
        //src - source for bits, len - bit length, di - data index, dbi - data bit index
        function int getBits(packet_item_c pack, int len, ref int di, ref int dbi);
            getBits = 0;
            for (int pbi = 0; pbi < len; ++pbi) begin //pbi = pixel bit index
                getBits[pbi] = pack.data[di][dbi];
                ++dbi;
                if (dbi == 8) begin
                    ++di;
                    dbi = 0;
                end
            end
        endfunction: getBits

        function void sendFrame();        
            packet_item_c qPack; //packet from queue
            int di = 0, bi = 0; //data index, bit index
            int t[8] = '{ default: 0 }; //temp storage for pixel data
        
            //set frame size
            collected_frame.height = packet_buf.size();
            collected_frame.interlaced = line_n_period > 1 ? (line_n_fieldfirst == 1 ? 1 : 2) : 0; //currently only 2 values supported in imgen
        
            //check size and cfg.size
            if (cfg.frame_w != 0 && collected_frame.width != cfg.frame_w
                    || cfg.frame_h != 0 && collected_frame.height != cfg.frame_h) begin
                uvm_report_error("CSI_FRAME_SIZE", $sformatf("Frame size mismatch: expected (%0d x %0d), received (%0d x %0d)",
                            cfg.frame_w, cfg.frame_h, collected_frame.width, collected_frame.height));
                return;
            end
            //check frame type and cfg
            if (cfg.dataFormat != P_invalid && frameType != cfg.dataFormat) begin
                uvm_report_error("CSI_FRAME_FORMAT", $sformatf("Frame format mismatch: expected %0s, received %0s",
                            cfg.dataFormat, frameType));
                return;
            end
            collected_frame.data_init();
            //extract all packets and create pxl_items
            foreach(packet_buf[pos_y]) begin
                //reset counters
                di = 0;
                bi = 0;
                //transfer all data to frame
                case(frameType)
                    LP_dataYUV420_8,
                    LP_dataYUV420_8_CSRS: begin
                        if ((pos_y + 1) % 2) begin
                            for (int wi = 0; wi < collected_frame.width / 2; ++wi) begin //word index
                                collected_frame.set_comp_data(vivo_core_pkg::comp_Y, wi * 2, pos_y, getBits(packet_buf[pos_y], 8, di, bi),
                                                                vivo_core_pkg::scheme_YUV, .caller_name(get_name()));
                                collected_frame.set_comp_data(vivo_core_pkg::comp_Y, wi * 2 + 1, pos_y, getBits(packet_buf[pos_y], 8, di, bi),
                                                                vivo_core_pkg::scheme_YUV, .caller_name(get_name()));
                            end
                        end
                        else begin
                            for (int wi = 0; wi < collected_frame.width / 2; ++wi) begin //word index
                                collected_frame.set_comp_data(vivo_core_pkg::comp_U, wi * 2, pos_y, getBits(packet_buf[pos_y], 8, di, bi),
                                                                vivo_core_pkg::scheme_YUV, .caller_name(get_name()));
                                collected_frame.set_comp_data(vivo_core_pkg::comp_Y, wi * 2, pos_y, getBits(packet_buf[pos_y], 8, di, bi),
                                                                vivo_core_pkg::scheme_YUV, .caller_name(get_name()));
                                collected_frame.set_comp_data(vivo_core_pkg::comp_V, wi * 2, pos_y, getBits(packet_buf[pos_y], 8, di, bi),
                                                                vivo_core_pkg::scheme_YUV, .caller_name(get_name()));
                                collected_frame.set_comp_data(vivo_core_pkg::comp_Y, wi * 2 + 1, pos_y, getBits(packet_buf[pos_y], 8, di, bi),
                                                                vivo_core_pkg::scheme_YUV, .caller_name(get_name()));
                            end
                        end
                    end
                    LP_dataYUV420_10,
                    LP_dataYUV420_10_CSRS: begin
                        t = '{ default: 0 };
                        if ((pos_y + 1) % 2) begin
                            for (int wi = 0; wi < collected_frame.width / 4; ++wi) begin //word index
                                for (int ti = 0; ti < 4; ++ti)
                                    t[ti][9:2] = getBits(packet_buf[pos_y], 8, di, bi);
                                for (int ti = 0; ti < 4; ++ti)
                                    t[ti][1:0] = getBits(packet_buf[pos_y], 2, di, bi);
                                for (int pi = 0; pi < 4; ++pi) //pixel index
                                    collected_frame.set_comp_data(vivo_core_pkg::comp_Y, wi * 4 + pi, pos_y, t[pi],
                                                                    vivo_core_pkg::scheme_YUV, .caller_name(get_name()));
                            end
                        end
                        else begin
                            for (int wi = 0; wi < collected_frame.width / 2; ++wi) begin //word index
                                for (int ti = 0; ti < 4; ++ti)
                                    t[ti][9:2] = getBits(packet_buf[pos_y], 8, di, bi);
                                for (int ti = 0; ti < 4; ++ti)
                                    t[ti][1:0] = getBits(packet_buf[pos_y], 2, di, bi);
                                collected_frame.set_comp_data(vivo_core_pkg::comp_U, wi * 2, pos_y, t[0],
                                                                vivo_core_pkg::scheme_YUV, .caller_name(get_name()));
                                collected_frame.set_comp_data(vivo_core_pkg::comp_Y, wi * 2, pos_y, t[1],
                                                                vivo_core_pkg::scheme_YUV, .caller_name(get_name()));
                                collected_frame.set_comp_data(vivo_core_pkg::comp_V, wi * 2, pos_y, t[2],
                                                                vivo_core_pkg::scheme_YUV, .caller_name(get_name()));
                                collected_frame.set_comp_data(vivo_core_pkg::comp_Y, wi * 2 + 1, pos_y, t[3],
                                                                vivo_core_pkg::scheme_YUV, .caller_name(get_name()));
                            end
                        end
                    end
                    LP_dataLegacyYUV420_8: begin
                        for (int wi = 0; wi < collected_frame.width / 2; ++wi) begin //word index
                            if ((pos_y + 1) % 2)
                                collected_frame.set_comp_data(vivo_core_pkg::comp_U, wi * 2, pos_y, getBits(packet_buf[pos_y], 8, di, bi),
                                                                vivo_core_pkg::scheme_YUV, .caller_name(get_name()));
                            else
                                collected_frame.set_comp_data(vivo_core_pkg::comp_V, wi * 2, pos_y, getBits(packet_buf[pos_y], 8, di, bi),
                                                                vivo_core_pkg::scheme_YUV, .caller_name(get_name()));
                            collected_frame.set_comp_data(vivo_core_pkg::comp_Y, wi * 2, pos_y, getBits(packet_buf[pos_y], 8, di, bi),
                                                                vivo_core_pkg::scheme_YUV, .caller_name(get_name()));
                            collected_frame.set_comp_data(vivo_core_pkg::comp_Y, wi * 2 + 1, pos_y, getBits(packet_buf[pos_y], 8, di, bi),
                                                                vivo_core_pkg::scheme_YUV, .caller_name(get_name()));
                        end
                    end
                    LP_dataYUV422_8: begin
                        for (int wi = 0; wi < collected_frame.width / 2; ++wi) begin //word index
                            collected_frame.set_comp_data(vivo_core_pkg::comp_U, wi * 2, pos_y, getBits(packet_buf[pos_y], 8, di, bi),
                                                            vivo_core_pkg::scheme_YUV, .caller_name(get_name()));
                            collected_frame.set_comp_data(vivo_core_pkg::comp_Y, wi * 2, pos_y, getBits(packet_buf[pos_y], 8, di, bi),
                                                            vivo_core_pkg::scheme_YUV, .caller_name(get_name()));
                            collected_frame.set_comp_data(vivo_core_pkg::comp_V, wi * 2, pos_y, getBits(packet_buf[pos_y], 8, di, bi),
                                                            vivo_core_pkg::scheme_YUV, .caller_name(get_name()));
                            collected_frame.set_comp_data(vivo_core_pkg::comp_Y, wi * 2 + 1, pos_y, getBits(packet_buf[pos_y], 8, di, bi),
                                                            vivo_core_pkg::scheme_YUV, .caller_name(get_name()));
                        end
                    end
                    LP_dataYUV422_10: begin
                        t = '{ default: 0 };
                        for (int wi = 0; wi < collected_frame.width / 2; ++wi) begin //word index
                            for (int ti = 0; ti < 4; ++ti)
                                t[ti][9:2] = getBits(packet_buf[pos_y], 8, di, bi);
                            for (int ti = 0; ti < 4; ++ti)
                                t[ti][1:0] = getBits(packet_buf[pos_y], 2, di, bi);
                            collected_frame.set_comp_data(vivo_core_pkg::comp_U, wi * 2, pos_y, t[0],
                                                            vivo_core_pkg::scheme_YUV, .caller_name(get_name()));
                            collected_frame.set_comp_data(vivo_core_pkg::comp_Y, wi * 2, pos_y, t[1],
                                                            vivo_core_pkg::scheme_YUV, .caller_name(get_name()));
                            collected_frame.set_comp_data(vivo_core_pkg::comp_V, wi * 2, pos_y, t[2],
                                                            vivo_core_pkg::scheme_YUV, .caller_name(get_name()));
                            collected_frame.set_comp_data(vivo_core_pkg::comp_Y, wi * 2 + 1, pos_y, t[3],
                                                            vivo_core_pkg::scheme_YUV, .caller_name(get_name()));
                        end
                    end
                    LP_dataRGB444: begin
                        for (int pos_x = 0; pos_x < collected_frame.width; ++pos_x) begin
                            //B
                            void'(getBits(packet_buf[pos_y], 1, di, bi));
                            collected_frame.set_comp_data(vivo_core_pkg::comp_B, pos_x, pos_y, getBits(packet_buf[pos_y], 4, di, bi),
                                                            vivo_core_pkg::scheme_RGB, .caller_name(get_name()));
                            //G
                            void'(getBits(packet_buf[pos_y], 2, di, bi));
                            collected_frame.set_comp_data(vivo_core_pkg::comp_G, pos_x, pos_y, getBits(packet_buf[pos_y], 4, di, bi),
                                                            vivo_core_pkg::scheme_RGB, .caller_name(get_name()));
                            //R
                            void'(getBits(packet_buf[pos_y], 1, di, bi));
                            collected_frame.set_comp_data(vivo_core_pkg::comp_R, pos_x, pos_y, getBits(packet_buf[pos_y], 4, di, bi),
                                                            vivo_core_pkg::scheme_RGB, .caller_name(get_name()));
                        end
                    end
                    LP_dataRGB555: begin
                        for (int pos_x = 0; pos_x < collected_frame.width; ++pos_x) begin
                            //B
                            collected_frame.set_comp_data(vivo_core_pkg::comp_B, pos_x, pos_y, getBits(packet_buf[pos_y], 5, di, bi),
                                                            vivo_core_pkg::scheme_RGB, .caller_name(get_name()));
                            //G
                            void'(getBits(packet_buf[pos_y], 1, di, bi));
                            collected_frame.set_comp_data(vivo_core_pkg::comp_G, pos_x, pos_y, getBits(packet_buf[pos_y], 5, di, bi),
                                                            vivo_core_pkg::scheme_RGB, .caller_name(get_name()));
                            //R
                            collected_frame.set_comp_data(vivo_core_pkg::comp_R, pos_x, pos_y, getBits(packet_buf[pos_y], 5, di, bi),
                                                            vivo_core_pkg::scheme_RGB, .caller_name(get_name()));
                        end
                    end
                    LP_dataRGB565: begin
                        for (int pos_x = 0; pos_x < collected_frame.width; ++pos_x) begin
                            //B
                            collected_frame.set_comp_data(vivo_core_pkg::comp_B, pos_x, pos_y, getBits(packet_buf[pos_y], 5, di, bi),
                                                            vivo_core_pkg::scheme_RGB, .caller_name(get_name()));
                            //G
                            collected_frame.set_comp_data(vivo_core_pkg::comp_G, pos_x, pos_y, getBits(packet_buf[pos_y], 6, di, bi),
                                                            vivo_core_pkg::scheme_RGB, .caller_name(get_name()));
                            //R
                            collected_frame.set_comp_data(vivo_core_pkg::comp_R, pos_x, pos_y, getBits(packet_buf[pos_y], 5, di, bi),
                                                            vivo_core_pkg::scheme_RGB, .caller_name(get_name()));
                        end
                    end
                    LP_dataRGB666: begin
                        for (int pos_x = 0; pos_x < collected_frame.width; ++pos_x) begin
                            //B
                            collected_frame.set_comp_data(vivo_core_pkg::comp_B, pos_x, pos_y, getBits(packet_buf[pos_y], 6, di, bi),
                                                            vivo_core_pkg::scheme_RGB, .caller_name(get_name()));
                            //G
                            collected_frame.set_comp_data(vivo_core_pkg::comp_G, pos_x, pos_y, getBits(packet_buf[pos_y], 6, di, bi),
                                                            vivo_core_pkg::scheme_RGB, .caller_name(get_name()));
                            //R
                            collected_frame.set_comp_data(vivo_core_pkg::comp_R, pos_x, pos_y, getBits(packet_buf[pos_y], 6, di, bi),
                                                            vivo_core_pkg::scheme_RGB, .caller_name(get_name()));
                        end
                    end
                    LP_dataRGB888: begin
                        for (int pos_x = 0; pos_x < collected_frame.width; ++pos_x) begin
                            collected_frame.set_comp_data(vivo_core_pkg::comp_B, pos_x, pos_y, getBits(packet_buf[pos_y], 8, di, bi),
                                                            vivo_core_pkg::scheme_RGB, .caller_name(get_name()));
                            collected_frame.set_comp_data(vivo_core_pkg::comp_G, pos_x, pos_y, getBits(packet_buf[pos_y], 8, di, bi),
                                                            vivo_core_pkg::scheme_RGB, .caller_name(get_name()));
                            collected_frame.set_comp_data(vivo_core_pkg::comp_R, pos_x, pos_y, getBits(packet_buf[pos_y], 8, di, bi),
                                                            vivo_core_pkg::scheme_RGB, .caller_name(get_name()));
                        end
                    end
                    LP_dataRAW6: begin
                        for (int pos_x = 0; pos_x < collected_frame.width; ++pos_x) begin
                            collected_frame.set_comp_data(vivo_core_pkg::comp_Y, pos_x, pos_y, getBits(packet_buf[pos_y], 6, di, bi),
                                                            vivo_core_pkg::scheme_MONO, .caller_name(get_name()));
                        end
                    end
                    LP_dataRAW7: begin
                        for (int pos_x = 0; pos_x < collected_frame.width; ++pos_x) begin
                            collected_frame.set_comp_data(vivo_core_pkg::comp_Y, pos_x, pos_y, getBits(packet_buf[pos_y], 7, di, bi),
                                                            vivo_core_pkg::scheme_MONO, .caller_name(get_name()));
                        end
                    end
                    LP_dataRAW8: begin
                        for (int pos_x = 0; pos_x < collected_frame.width; ++pos_x) begin
                            collected_frame.set_comp_data(vivo_core_pkg::comp_Y, pos_x, pos_y, getBits(packet_buf[pos_y], 8, di, bi),
                                                            vivo_core_pkg::scheme_MONO, .caller_name(get_name()));
                        end
                    end
                    LP_dataRAW10: begin
                        t = '{ default: 0 };
                        for (int wi = 0; wi < collected_frame.width / 4; ++wi) begin //word index
                            for (int pi = 0; pi < 4; ++pi) //pixel index
                                t[pi][9:2] = getBits(packet_buf[pos_y], 8, di, bi);
                            for (int pi = 0; pi < 4; ++pi) //pixel index
                                t[pi][1:0] = getBits(packet_buf[pos_y], 2, di, bi);
                            for (int pi = 0; pi < 4; ++pi) //pixel index
                                collected_frame.set_comp_data(vivo_core_pkg::comp_Y, wi * 4 + pi, pos_y, t[pi],
                                                                vivo_core_pkg::scheme_MONO, .caller_name(get_name()));
                        end
                    end
                    LP_dataRAW12: begin
                        t = '{ default: 0 };
                        for (int wi = 0; wi < collected_frame.width / 2; ++wi) begin //word index
                            for (int pi = 0; pi < 2; ++pi) //pixel index
                                t[pi][11:4] = getBits(packet_buf[pos_y], 8, di, bi);
                            for (int pi = 0; pi < 2; ++pi) //pixel index
                                t[pi][3:0] = getBits(packet_buf[pos_y], 4, di, bi);
                            for (int pi = 0; pi < 2; ++pi) //pixel index
                                collected_frame.set_comp_data(vivo_core_pkg::comp_Y, wi * 2 + pi, pos_y, t[pi],
                                                                vivo_core_pkg::scheme_MONO, .caller_name(get_name()));
                        end
                    end
                    LP_dataRAW14: begin
                        t = '{ default: 0 };
                        for (int wi = 0; wi < collected_frame.width / 4; ++wi) begin //word index
                            for (int pi = 0; pi < 4; ++pi) //pixel index
                                t[pi][13:6] = getBits(packet_buf[pos_y], 8, di, bi);
                            for (int pi = 0; pi < 4; ++pi) //pixel index
                                t[pi][5:0] = getBits(packet_buf[pos_y], 6, di, bi);
                            for (int pi = 0; pi < 4; ++pi) //pixel index
                                collected_frame.set_comp_data(vivo_core_pkg::comp_Y, wi * 4 + pi, pos_y, t[pi],
                                                                vivo_core_pkg::scheme_MONO, .caller_name(get_name()));
                        end
                    end
                    default: uvm_report_error("CSI_UNKNOWN", $sformatf("Unknown data format: %d", frameType));
                endcase
                //create new pxls
                for (int pos_x = 0; pos_x < collected_frame.width; ++pos_x) begin
                    collected_pxl = collected_frame.get_pxl_item($sformatf("csi_collected_pxl[%0d,%0d]", pos_x, pos_y));
                    collected_pxl.pos_x = pos_x;
                    collected_pxl.pos_y = pos_y;
                    collected_pxl.eol = (pos_x == collected_frame.width - 1);
                    collected_pxl.eof = collected_pxl.eol && (pos_y == collected_frame.height - 1);
                    collected_pxl.is_last = 0; // no way to determine last frame
                    //data is already in the frame
                    //pixel is ready - send it
                    uvm_report_info("LOG", $sformatf("%s has collected the following pixel:\n%s",
                                get_name(), collected_pxl.sprint()), UVM_HIGH);
                    pxl_aport.write(collected_pxl);
                end
            end
            //write frame now
            uvm_report_info("LOG", $sformatf("%s has collected the following frame:\n%s",
                        get_name(), collected_frame.sprint()), UVM_MEDIUM);
            frame_aport.write(collected_frame);
        endfunction: sendFrame

    endclass : monitor_c

`endif //__CSI_MONITOR_SV__
