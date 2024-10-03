//
// File : csi_mltran2packet.sv
//
// Created:
//          by HDL Designers Team
//          of Electronics Design Center "OhT"
//          www.overhitech.com
//
//
// File Description:
//
//% Subscriber, собирающий пакеты из mltran CSI
//

`ifndef __CSI_MLTRAN2PACKET_SV__
    `define __CSI_MLTRAN2PACKET_SV__

typedef class ext_agent_base_c;
    

class mltran2packet_c#(int LANES_MAX = 4) extends uvm_subscriber#(mltran_item_c#(LANES_MAX));
 
    ext_agent_base_c    p_agent;
    ext_config_c        cfg;
    
    uvm_analysis_port#(packet_item_c)   packet_aport;

    //------------------------------------------------------------------------------------------------------------------
    // Mltran data
    //------------------------------------------------------------------------------------------------------------------

    int new_len [LANES_MAX-1:0];
    uvm_queue#(byte) merged_q; //mixed deserialized bytes
    
    //------------------------------------------------------------------------------------------------------------------
    // UVM automation macros
    //------------------------------------------------------------------------------------------------------------------
    
    `uvm_component_param_utils_begin(csi_pkg::mltran2packet_c#(LANES_MAX))
        `uvm_field_object  (p_agent, UVM_ALL_ON | UVM_NOCOMPARE)
        `uvm_field_object  (cfg, UVM_ALL_ON | UVM_NOCOMPARE)
    `uvm_component_utils_end

    //------------------------------------------------------------------------------------------------------------------
    // constructor
    //------------------------------------------------------------------------------------------------------------------

    function new (string name = "csi_mltran2packet", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    //------------------------------------------------------------------------------------------------------------------
    // build routine
    //------------------------------------------------------------------------------------------------------------------

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        merged_q = new("bytes_queue_merged");
        packet_aport = new("packet_aport", this);
    endfunction: build_phase

    //------------------------------------------------------------------------------------------------------------------
    // write function
    //------------------------------------------------------------------------------------------------------------------

    function void write (mltran_item_c#(LANES_MAX) t);
        uvm_report_info("CSI_MLT2PKT", $sformatf("CSI packet reconstructor has received the following transaction:\n%s", t.sprint), UVM_HIGH);
        processTran(t);
    endfunction: write
    
    //removes last flipped bit from queue
    function void processTran(mltran_item_c#(LANES_MAX) rTran);
        packet_item_c packet_item;
        int mlt_pos = 0;
        
        removeTrail(rTran); //calc new length for each lane
        //check sizes
        for (int lane = 1; lane < cfg.lanes_used; ++lane)
            if (new_len[lane] > new_len[lane - 1] || new_len[lane] < new_len[0] - 1) begin
                //uvm_report_error("CSI_QSIZE", $sformatf("Big difference in number of bytes between lanes: 0 - %0d, 1 - %0d, 2 - %0d, 3 - %0d!",
                //        byte_q[0].size(), byte_q[1].size(), byte_q[2].size(), byte_q[3].size())); //make it warning
                uvm_report_error("CSI_QSIZE", "Big difference in number of bytes between lanes! Recovered length:");
                for (int lane = 0; lane < cfg.lanes_used; ++lane)
                    uvm_report_info("CSI_MLT2PKT", $sformatf("Lane %d: %d", lane, new_len[lane]), UVM_LOW);
                break;
            end
        
        ///merge queues
        for (int lane = 0; mlt_pos < new_len[lane]; mlt_pos += (lane + 1) / cfg.lanes_used, lane = (lane + 1) % cfg.lanes_used)
            merged_q.push_back(rTran.data[lane][mlt_pos]);
        //check queue size
        if (merged_q.size() < 4)
            uvm_report_error("CSI_QSIZE", "Total packet size is too small!");
        
        //recover packet
        packet_item = mlt2pkt(rTran);
        if (packet_item == null)
            uvm_report_info("CSI_MLT2PKT", "Packet rejected.", UVM_LOW);
        else
            packet_aport.write(packet_item);
    endfunction: processTran
    
    //removes last flipped bit from queue
    function void removeTrail(mltran_item_c#(LANES_MAX) rTran);
        int bits_skipped;
        byte last_unskipped;
        bit all_clear = 0;
            
        new_len = '{ default: rTran.length };
        for (int lane = 0; lane < cfg.lanes_used; ++lane) begin
            while (rTran.data[lane][new_len[lane] - 1] ==  '{ 8{!rTran.lastbit[lane]} })
                --new_len[lane];
            if (rTran.data[lane][new_len[lane] - 1][7] != rTran.lastbit[lane]) //if only PART of the byte is skipped - wrong deser.
                uvm_report_error("CSI_FLIPPEDBIT", $sformatf("Wrong deserealization: last bit is not flipped?: lane %0d, last byte %b!", lane, rTran.data[lane][new_len[lane] - 1])); //make it warning
        end
    endfunction: removeTrail
    
    function packet_item_c mlt2pkt(mltran_item_c#(LANES_MAX) rTran);
        int errcode = 0;
        
        mlt2pkt = packet_item_c::type_id::create("reconstructed_packet");
        //reconstruct packet, manually set all fields
        mlt2pkt.set_dataID(merged_q.pop_front());
        mlt2pkt.wordCount[7:0] = merged_q.pop_front();
        mlt2pkt.wordCount[15:8] = merged_q.pop_front();
        mlt2pkt.ecc = merged_q.pop_front();
        //correct header before anything
        errcode = mlt2pkt.ecc_correct();
        case(errcode)
            0: uvm_report_info("CSI_ECC", "No errors", UVM_FULL);
            1: uvm_report_warning("CSI_ECC_WRN", "1 error corrected");
            2:  begin
                uvm_report_error("CSI_ECC_ERR", "Header is corrupted! Rejecting packet...");
                return null;
            end
        endcase
        //now when header is cool
        if (mlt2pkt.is_long()) begin
            //check sizes
            if (mlt2pkt.wordCount + 2 != merged_q.size()) begin
                uvm_report_error("CSI_QSIZE", $sformatf("Packet size mismatch: word count (+2 CRC bytes) = %0d, byte queue size = %0d", mlt2pkt.wordCount + 2, merged_q.size())); //make it warning
                return null;
            end
            //start
            mlt2pkt.data = new[mlt2pkt.wordCount];
            foreach(mlt2pkt.data[i])
                mlt2pkt.data[i] = merged_q.pop_front();
            mlt2pkt.crc[7:0] = merged_q.pop_front();
            mlt2pkt.crc[15:8] = merged_q.pop_front();
            //check CRC
            if (!mlt2pkt.crc_check())
                uvm_report_info("CSI_CRC", "No errors", UVM_FULL);
            else begin
                uvm_report_error("CSI_CRC_ERR", $sformatf("CRC mismatch! Received: %0d, calculated: %0d", mlt2pkt.crc, mlt2pkt.crc16_ibm()));
                return null;
            end
        end
        else if (merged_q.size() > 0) begin
            uvm_report_error("CSI_QSIZE", $sformatf("Packet size mismatch: packet is SMALL, byte queue size = %0d", merged_q.size())); //make it warning
            return null;
        end
        uvm_report_info("LOG", $sformatf("Received packet:\n%s", mlt2pkt.sprint()), UVM_HIGH);
        //returning mlt2pkt
    endfunction: mlt2pkt

endclass : mltran2packet_c

`endif //__CSI_MLTRAN2PACKET_SV__
