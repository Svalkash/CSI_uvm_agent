//
// File : csi_packet_seq_lib.sv
//
// Created:
//          by HDL Designers Team
//          of Electronics Design Center "OhT"
//          www.overhitech.com
//
//
// File Description:
//
//% Библиотека тестовых последовательностей CSI
//

`ifndef __CSI_PACKET_SEQ_LIB_SV__
    `define __CSI_PACKET_SEQ_LIB_SV__
    
`include "csi_packet_item.sv"
`include "csi_driver.sv"
    
//----------------------------------------------------------------------------------------------------------------------
// packet base sequence
//----------------------------------------------------------------------------------------------------------------------

class packet_base_seq_c extends uvm_sequence#(csi_pkg::packet_item_c);
    
    //------------------------------------------------------------------------------------------------------------------
    // sequence variables
    //------------------------------------------------------------------------------------------------------------------

    int csi_frame_n = 1;

    //------------------------------------------------------------------------------------------------------------------
    // UVM automation macros
    //------------------------------------------------------------------------------------------------------------------

    `uvm_object_utils(csi_pkg::packet_base_seq_c)
    `uvm_declare_p_sequencer(csi_pkg::driver_c)

    //------------------------------------------------------------------------------------------------------------------
    // constructor
    //------------------------------------------------------------------------------------------------------------------

    function new(string name="packet_base_seq");
        super.new(name);
    endfunction

    //------------------------------------------------------------------------------------------------------------------
    // sequence body
    //------------------------------------------------------------------------------------------------------------------

    task update_passive; //update config for monitor
        uvm_report_info("DISP", "CSI packet sequencer is PASSIVE, but still updating...", UVM_MEDIUM);
        forever begin  // wait for enabled
            if (!p_sequencer.cfg.enabled)
                p_sequencer.cfg_update();
            #1;
        end
    endtask: update_passive
    
    virtual task body ();
        vivo_core_pkg::frame_item_c frame_item;
        int field_num;
        
        `ifdef UVM_VERSION_1_2
            uvm_phase starting_phase = get_starting_phase();
        `endif
        // raise objection if started as a root sequence
        if (starting_phase != null)
            starting_phase.raise_objection(this);
        
        uvm_report_info("CSI_PACK", $sformatf("CSI packet sequence has started on '%s'.", p_sequencer.get_name()), UVM_MEDIUM);
    
        if (p_sequencer.cfg == null)
            uvm_report_fatal("NOCFG", {"Configuration must be set for: ", p_sequencer.get_type_name(), ".p_sequencer.cfg"});
        p_sequencer.cfg_update();
        //checked on test side
        if (p_sequencer.cfg.is_active == UVM_PASSIVE) begin
            fork
                update_passive();
            join_none
            return;
        end
        uvm_report_info("DISP", "CSI packet sequencer is ACTIVE", UVM_MEDIUM);
        
        do begin
            p_sequencer.cfg_update();
            //do not wait for enabled: if sequence is launched, we are ALREADY enabled
            /*
            forever begin  // wait for enabled
                p_sequencer.cfg_update();
                if (p_sequencer.cfg.enabled)
                    break;
                #1; // just wait
            end
            */
            
            p_sequencer.frame_item_port.get_next_item(frame_item); //get next frame
            uvm_report_info("CSI_PACK", $sformatf("CSI packet sequencer has received the following frame:\n%s", frame_item.sprint), UVM_MEDIUM);
            ->p_sequencer.boa;
            field_num = (frame_item.interlaced) ? 2 : 1; 
            for (int field = 0; field < field_num; ++field) //if interlaced, send SEVERAL frames
                sendFrame(frame_item, field);
            ->p_sequencer.eoa;
            p_sequencer.frame_item_port.item_done();
        end
        while (!req.is_last);
        uvm_report_info("CSI_PACK", $sformatf("%s got 'is_last', stopping...", p_sequencer.get_name()), UVM_MEDIUM);

        // drop objection if started as a root sequence
        if (starting_phase != null)
            starting_phase.drop_objection(this);
    endtask

    //---------------------------------------------------------------------------------------------------------------------
    // sending 1 field ('frame' in CSI terms) / 1 frame
    //---------------------------------------------------------------------------------------------------------------------

    task sendFrame (vivo_core_pkg::frame_item_c frame_item, int field = 0);
        bit last_field = 0;
        
        if (p_sequencer.cfg.frame_n_period == 0)
            csi_frame_n = 0;
        
        sendPacket_short("packet_frameStart", SP_frameStart, csi_frame_n);
        
        for (int line = 1; line <= frame_item.height; ++line) begin //line number starts from 1 in CSI
            //if interlaced, skip other fields
            if (frame_item.interlaced == 1 && (line % 2 == field))
                continue;
            if (frame_item.interlaced == 2 && ((line + 1) % 2 == field))
                continue;
            //send LS
            if (p_sequencer.cfg.sendLineSE)
                sendPacket_short("packet_lineStart", SP_lineStart, line);
            //line itself
            sendPacket_line(frame_item, line);
            //send LE
            if (p_sequencer.cfg.sendLineSE)
                sendPacket_short("packet_lineEnd", SP_lineEnd, line);
        end
        
        last_field = (frame_item.interlaced) ? (frame_item.is_last && field == 1) : frame_item.is_last;
        sendPacket_short("packet_frameEnd", SP_frameEnd, csi_frame_n, last_field); //if it's last frame / field, send 'last' packet
        //increase frame ID (ignore sent, CSI has its own)
        if (p_sequencer.cfg.frame_n_period != 0)
            csi_frame_n = csi_frame_n % p_sequencer.cfg.frame_n_period + 1; //frame number starts from 1 in CSI
    endtask: sendFrame
    
    task sendPacket_short(string name = "csi_packet", packetType_t packetType = P_invalid, shortint wordCount = 0, bit is_last = 0);
        req = csi_pkg::packet_item_c::type_id::create(name);
        start_item(req);
        //'new' copy, but for using with "create"
        req.set_dataType(packetType);
        //channel ID will be set later
        req.set_wordCount(wordCount);
        req.is_last = is_last;
        //ecc recalced inside
        finish_item(req);
    endtask: sendPacket_short
    
    //src - source for bits, len - bit length, di - data index, dbi - data bit index
    function void setBits(int src, int len, ref int di, ref int dbi);
        for (int pbi = 0; pbi < len; ++pbi) begin //pbi = pixel bit index
            req.data[di][dbi] = src[pbi];
            ++dbi;
            if (dbi == 8) begin
                ++di;
                dbi = 0;
            end
        end
    endfunction: setBits
    
    task sendPacket_line(vivo_core_pkg::frame_item_c frame_item, int line);
        int di = 0, bi = 0; //data index, bit index
        shortint comp_data_tmp;
        
        req = csi_pkg::packet_item_c::type_id::create("packet_data");
        start_item(req);
        //'new' copy, but for using with "create"
        req.set_dataType(p_sequencer.cfg.dataFormat);
        req.is_last = 0;
        //channel ID will be set later
        //set length
        req.set_pixel_length(frame_item.width, line); //recalc length
        
        case(p_sequencer.cfg.dataFormat)
            LP_dataYUV420_8,
            LP_dataYUV420_8_CSRS: begin
                if (line % 2) begin
                    for (int wi = 0; wi < frame_item.width / 2; ++wi) begin //word index
                        setBits(frame_item.get_comp_data(vivo_core_pkg::comp_Y, wi * 2, line - 1, vivo_core_pkg::scheme_YUV), 8, di, bi);
                        setBits(frame_item.get_comp_data(vivo_core_pkg::comp_Y, wi * 2 + 1, line - 1, vivo_core_pkg::scheme_YUV), 8, di, bi);
                    end
                end
                else begin
                    for (int wi = 0; wi < frame_item.width / 2; ++wi) begin //word index
                        setBits(frame_item.get_comp_data(vivo_core_pkg::comp_U, wi * 2, line - 1, vivo_core_pkg::scheme_YUV), 8, di, bi);
                        setBits(frame_item.get_comp_data(vivo_core_pkg::comp_Y, wi * 2, line - 1, vivo_core_pkg::scheme_YUV), 8, di, bi);
                        setBits(frame_item.get_comp_data(vivo_core_pkg::comp_V, wi * 2, line - 1, vivo_core_pkg::scheme_YUV), 8, di, bi);
                        setBits(frame_item.get_comp_data(vivo_core_pkg::comp_Y, wi * 2 + 1, line - 1, vivo_core_pkg::scheme_YUV), 8, di, bi);
                    end
                end
            end
            LP_dataYUV420_10,
            LP_dataYUV420_10_CSRS: begin
                if (line % 2) begin
                    for (int wi = 0; wi < frame_item.width / 4; ++wi) begin //word index
                        for (int bi = 0; bi < 2; ++bi) begin //byte index
                            for (int pi = 0; pi < 4; ++pi) begin //pixel index
                                comp_data_tmp = frame_item.get_comp_data(vivo_core_pkg::comp_Y, wi * 4 + pi, line - 1, vivo_core_pkg::scheme_YUV);
                                case (bi)
                                    0: setBits(comp_data_tmp[9:2], 8, di, bi);
                                    1: setBits(comp_data_tmp[1:0], 2, di, bi);
                                endcase
                            end // pi
                        end // bi
                    end // wi
                end
                else begin
                    for (int wi = 0; wi < (frame_item.width / 4) * 2; ++wi) begin //word index
                        for (int bi = 0; bi < 2; ++bi) begin //byte index
                            for (int ci = 0; ci < 4; ++ci) begin //component index
                                case(ci)
                                    0: comp_data_tmp = frame_item.get_comp_data(vivo_core_pkg::comp_U, wi * 2, line - 1, vivo_core_pkg::scheme_YUV);
                                    1: comp_data_tmp = frame_item.get_comp_data(vivo_core_pkg::comp_Y, wi * 2, line - 1, vivo_core_pkg::scheme_YUV);
                                    2: comp_data_tmp = frame_item.get_comp_data(vivo_core_pkg::comp_V, wi * 2, line - 1, vivo_core_pkg::scheme_YUV);
                                    3: comp_data_tmp = frame_item.get_comp_data(vivo_core_pkg::comp_Y, wi * 2 + 1, line - 1, vivo_core_pkg::scheme_YUV);
                                endcase
                                case(bi)
                                    0: setBits(comp_data_tmp[9:2], 8, di, bi);
                                    1: setBits(comp_data_tmp[1:0], 2, di, bi);
                                endcase
                            end // ci
                        end  // bi
                    end // wi
                end // else
            end
            LP_dataLegacyYUV420_8: begin
                for (int wi = 0; wi < frame_item.width / 2; ++wi) begin //word index
                    if (line % 2)
                        setBits(frame_item.get_comp_data(vivo_core_pkg::comp_U, wi * 2, line - 1, vivo_core_pkg::scheme_YUV), 8, di, bi);
                    else
                        setBits(frame_item.get_comp_data(vivo_core_pkg::comp_V, wi * 2, line - 1, vivo_core_pkg::scheme_YUV), 8, di, bi);
                    setBits(frame_item.get_comp_data(vivo_core_pkg::comp_Y, wi * 2, line - 1, vivo_core_pkg::scheme_YUV), 8, di, bi);
                    setBits(frame_item.get_comp_data(vivo_core_pkg::comp_Y, wi * 2 + 1, line - 1, vivo_core_pkg::scheme_YUV), 8, di, bi);
                end
            end
            LP_dataYUV422_8: begin
                for (int wi = 0; wi < frame_item.width / 2; ++wi) begin //word index
                    setBits(frame_item.get_comp_data(vivo_core_pkg::comp_U, wi * 2, line - 1, vivo_core_pkg::scheme_YUV), 8, di, bi);
                    setBits(frame_item.get_comp_data(vivo_core_pkg::comp_Y, wi * 2, line - 1, vivo_core_pkg::scheme_YUV), 8, di, bi);
                    setBits(frame_item.get_comp_data(vivo_core_pkg::comp_V, wi * 2, line - 1, vivo_core_pkg::scheme_YUV), 8, di, bi);
                    setBits(frame_item.get_comp_data(vivo_core_pkg::comp_Y, wi * 2 + 1, line - 1, vivo_core_pkg::scheme_YUV), 8, di, bi);
                end
            end
            LP_dataYUV420_10,
            LP_dataYUV420_10_CSRS: begin
                for (int wi = 0; wi < frame_item.width / 2; ++wi) begin //word index
                    for (int bi = 0; bi < 2; ++bi) begin //byte index
                        for (int ci = 0; ci < 4; ++ci) begin //component index
                            case(ci)
                                0: comp_data_tmp = frame_item.get_comp_data(vivo_core_pkg::comp_U, wi * 2, line - 1, vivo_core_pkg::scheme_YUV);
                                1: comp_data_tmp = frame_item.get_comp_data(vivo_core_pkg::comp_Y, wi * 2, line - 1, vivo_core_pkg::scheme_YUV);
                                2: comp_data_tmp = frame_item.get_comp_data(vivo_core_pkg::comp_V, wi * 2, line - 1, vivo_core_pkg::scheme_YUV);
                                3: comp_data_tmp = frame_item.get_comp_data(vivo_core_pkg::comp_Y, wi * 2 + 1, line - 1, vivo_core_pkg::scheme_YUV);
                            endcase
                            case(bi)
                                0: setBits(comp_data_tmp[9:2], 8, di, bi);
                                1: setBits(comp_data_tmp[1:0], 2, di, bi);
                            endcase
                        end // ci
                    end  // bi
                end // wi
            end
            LP_dataRGB444: begin
                for (int pos_x = 0; pos_x < frame_item.width; ++pos_x) begin
                    setBits(1, 1, di, bi);
                    setBits(frame_item.get_comp_data(vivo_core_pkg::comp_B, pos_x, line - 1, vivo_core_pkg::scheme_RGB), 4, di, bi);
                    setBits(2'b10, 2, di, bi);
                    setBits(frame_item.get_comp_data(vivo_core_pkg::comp_G, pos_x, line - 1, vivo_core_pkg::scheme_RGB), 4, di, bi);
                    setBits(1, 1, di, bi);
                    setBits(frame_item.get_comp_data(vivo_core_pkg::comp_R, pos_x, line - 1, vivo_core_pkg::scheme_RGB), 4, di, bi);
                end
            end
            LP_dataRGB555: begin
                for (int pos_x = 0; pos_x < frame_item.width; ++pos_x) begin
                    setBits(frame_item.get_comp_data(vivo_core_pkg::comp_B, pos_x, line - 1, vivo_core_pkg::scheme_RGB), 5, di, bi);
                    setBits(0, 1, di, bi);
                    setBits(frame_item.get_comp_data(vivo_core_pkg::comp_G, pos_x, line - 1, vivo_core_pkg::scheme_RGB), 5, di, bi);
                    setBits(frame_item.get_comp_data(vivo_core_pkg::comp_R, pos_x, line - 1, vivo_core_pkg::scheme_RGB), 5, di, bi);
                end
            end
            LP_dataRGB565: begin
                for (int pos_x = 0; pos_x < frame_item.width; ++pos_x) begin
                    setBits(frame_item.get_comp_data(vivo_core_pkg::comp_B, pos_x, line - 1, vivo_core_pkg::scheme_RGB), 5, di, bi);
                    setBits(frame_item.get_comp_data(vivo_core_pkg::comp_G, pos_x, line - 1, vivo_core_pkg::scheme_RGB), 6, di, bi);
                    setBits(frame_item.get_comp_data(vivo_core_pkg::comp_R, pos_x, line - 1, vivo_core_pkg::scheme_RGB), 5, di, bi);
                end
            end
            LP_dataRGB666: begin
                for (int pos_x = 0; pos_x < frame_item.width; ++pos_x) begin
                    setBits(frame_item.get_comp_data(vivo_core_pkg::comp_B, pos_x, line - 1, vivo_core_pkg::scheme_RGB), 6, di, bi);
                    setBits(frame_item.get_comp_data(vivo_core_pkg::comp_G, pos_x, line - 1, vivo_core_pkg::scheme_RGB), 6, di, bi);
                    setBits(frame_item.get_comp_data(vivo_core_pkg::comp_R, pos_x, line - 1, vivo_core_pkg::scheme_RGB), 6, di, bi);
                end
            end
            LP_dataRGB888: begin
                for (int pos_x = 0; pos_x < frame_item.width; ++pos_x) begin
                    setBits(frame_item.get_comp_data(vivo_core_pkg::comp_B, pos_x, line - 1, vivo_core_pkg::scheme_RGB), 8, di, bi);
                    setBits(frame_item.get_comp_data(vivo_core_pkg::comp_G, pos_x, line - 1, vivo_core_pkg::scheme_RGB), 8, di, bi);
                    setBits(frame_item.get_comp_data(vivo_core_pkg::comp_R, pos_x, line - 1, vivo_core_pkg::scheme_RGB), 8, di, bi);
                end
            end
            LP_dataRAW6: begin
                for (int pos_x = 0; pos_x < frame_item.width; ++pos_x) begin
                    setBits(frame_item.get_comp_data(vivo_core_pkg::comp_Y, pos_x, line - 1, vivo_core_pkg::scheme_MONO), 6, di, bi);
                end
            end
            LP_dataRAW7: begin
                for (int pos_x = 0; pos_x < frame_item.width; ++pos_x) begin
                    setBits(frame_item.get_comp_data(vivo_core_pkg::comp_Y, pos_x, line - 1, vivo_core_pkg::scheme_MONO), 7, di, bi);
                end
            end
            LP_dataRAW8: begin
                for (int pos_x = 0; pos_x < frame_item.width; ++pos_x) begin
                    setBits(frame_item.get_comp_data(vivo_core_pkg::comp_Y, pos_x, line - 1, vivo_core_pkg::scheme_MONO), 8, di, bi);
                end
            end
            LP_dataRAW10: begin
                for (int wi = 0; wi < frame_item.width / 4; ++wi) begin //word index
                    for (int bi = 0; bi < 2; ++bi) begin //byte index
                        for (int pi = 0; pi < 4; ++pi) begin //pixel index
                            comp_data_tmp = frame_item.get_comp_data(vivo_core_pkg::comp_Y, wi * 4 + pi, line - 1, vivo_core_pkg::scheme_MONO);
                            case (bi)
                                0: setBits(comp_data_tmp[9:2], 8, di, bi);
                                1: setBits(comp_data_tmp[1:0], 2, di, bi);
                            endcase
                        end // pi
                    end // bi
                end // wi
            end
            LP_dataRAW12: begin
                for (int wi = 0; wi < frame_item.width / 2; ++wi) begin //word index
                    for (int bi = 0; bi < 2; ++bi) begin //byte index
                        for (int pi = 0; pi < 2; ++pi) begin //pixel index
                            comp_data_tmp = frame_item.get_comp_data(vivo_core_pkg::comp_Y, wi * 2 + pi, line - 1, vivo_core_pkg::scheme_MONO);
                            case (bi)
                                0: setBits(comp_data_tmp[11:4], 8, di, bi);
                                1: setBits(comp_data_tmp[3:0], 4, di, bi);
                            endcase
                        end // pi
                    end // bi
                end // wi
            end
            LP_dataRAW14: begin
                for (int wi = 0; wi < frame_item.width / 4; ++wi) begin //word index
                    for (int bi = 0; bi < 2; ++bi) begin //byte index
                        for (int pi = 0; pi < 4; ++pi) begin //pixel index
                            comp_data_tmp = frame_item.get_comp_data(vivo_core_pkg::comp_Y, wi * 4 + pi, line - 1, vivo_core_pkg::scheme_MONO);
                            case (bi)
                                0: setBits(comp_data_tmp[13:6], 8, di, bi);
                                1: setBits(comp_data_tmp[5:0], 6, di, bi);
                            endcase
                        end // pi
                    end // bi
                end // wi
            end
            default: uvm_report_error("CSI_UNKNOWN", $sformatf("Unknown frame format: %d", p_sequencer.cfg.dataFormat));
        endcase
        req.recalc_crc(); //recalc CRC for new data
        //send it, it's ready
        finish_item(req);
    endtask: sendPacket_line
        
endclass : packet_base_seq_c

//----------------------------------------------------------------------------------------------------------------------
// passive sequence (update ONLY, even don't check active)
//----------------------------------------------------------------------------------------------------------------------

class passive_update_seq_c extends packet_base_seq_c;

    //------------------------------------------------------------------------------------------------------------------
    // UVM automation macros
    //------------------------------------------------------------------------------------------------------------------

    `uvm_object_utils(csi_pkg::passive_update_seq_c)
    `uvm_declare_p_sequencer(csi_pkg::driver_c)

    //------------------------------------------------------------------------------------------------------------------
    // constructor
    //------------------------------------------------------------------------------------------------------------------

    function new(string name="passive_update_seq_c");
        super.new(name);
    endfunction
    
    virtual task body ();
        `ifdef UVM_VERSION_1_2
            uvm_phase starting_phase = get_starting_phase();
        `endif
        // raise objection if started as a root sequence
        if (starting_phase != null)
            starting_phase.raise_objection(this);
        
        uvm_report_info("CSI_PACK", $sformatf("CSI passive update sequence has started on '%s'.", p_sequencer.get_name()), UVM_MEDIUM);
    
        if (p_sequencer.cfg == null)
            uvm_report_fatal("NOCFG", {"Configuration must be set for: ", p_sequencer.get_type_name(), ".p_sequencer.cfg"});
        p_sequencer.cfg_update();
        //checked on test side
        fork
            update_passive();
        join_none

        // drop objection if started as a root sequence
        if (starting_phase != null)
            starting_phase.drop_objection(this);
    endtask
endclass : passive_update_seq_c


`endif // __CSI_PACKET_SEQ_LIB_SV__