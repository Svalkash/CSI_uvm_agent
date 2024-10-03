//
// File : csi_mltran_seq_lib.sv
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

`ifndef __CSI_MLTRAN_SEQ_LIB_SV__
    `define __CSI_MLTRAN_SEQ_LIB_SV__
    
//----------------------------------------------------------------------------------------------------------------------
// packet base sequence
//----------------------------------------------------------------------------------------------------------------------

class mltran_base_seq_c#(int LANES_MAX = 4) extends uvm_sequence#(csi_pkg::mltran_item_c#(LANES_MAX));

    //------------------------------------------------------------------------------------------------------------------
    // sequence variables
    //------------------------------------------------------------------------------------------------------------------
    
    int mlt_lane = 0; //current lane
    int mlt_pos = 0; //current position

    //------------------------------------------------------------------------------------------------------------------
    // UVM automation macros
    //------------------------------------------------------------------------------------------------------------------

    `uvm_object_param_utils(csi_pkg::mltran_base_seq_c#(LANES_MAX))
    `uvm_declare_p_sequencer(csi_pkg::mltran_sqr_c#(LANES_MAX))

    //------------------------------------------------------------------------------------------------------------------
    // constructor
    //------------------------------------------------------------------------------------------------------------------

    function new(string name="mltran_base_seq");
        super.new(name);
    endfunction

    //------------------------------------------------------------------------------------------------------------------
    // sequence body
    //------------------------------------------------------------------------------------------------------------------

    task body ();
        bit was_last = 0; //last transaction from ALL sources
        packet_item_c packet_item;
        int packet_len, mltran_len;
        
        `ifdef UVM_VERSION_1_2
            uvm_phase starting_phase = get_starting_phase();
        `endif
        // raise objection if started as a root sequence
        if (starting_phase != null)
            starting_phase.raise_objection(this);
        
        
        uvm_report_info("LOG", $sformatf("CSI packet-to-mltran sequence has started on '%s'.", p_sequencer.get_name()), UVM_HIGH);
        if (p_sequencer.cfg == null)
            uvm_report_fatal("NOCFG", {"Configuration must be set for: ", p_sequencer.get_type_name(), ".p_sequencer.cfg"});
        
        while (!was_last) begin
            p_sequencer.packet_item_port.get_next_item(packet_item);
            uvm_report_info("CSI_MLTRAN", $sformatf("%s has received the following packet:\n%s",
                        get_name(), packet_item.sprint()), UVM_HIGH);
            req = csi_pkg::mltran_item_c#(LANES_MAX)::type_id::create($sformatf("mltran_'%s'", packet_item.get_name()));
            start_item(req);
            //calc length
            packet_len = packet_item.is_long() ? (4 + packet_item.wordCount + 2) : 4; //header, data, crc
            mltran_len = packet_len / 4 + (packet_len % p_sequencer.cfg.lanes_used == 0 ? 0 : 1); //round to lanes num and divide
            req.set_length(mltran_len);
            //reset counters
            mlt_lane = 0;
            mlt_pos = 0;
            //fill data
            fill_mltran(packet_item.get_dataID());
            fill_mltran(packet_item.wordCount[7:0]);
            fill_mltran(packet_item.wordCount[15:8]);
            fill_mltran(packet_item.ecc);
            if (packet_item.is_long()) begin
                for (int wi = 0; wi < packet_item.wordCount; ++wi)
                    fill_mltran(packet_item.data[wi]);
                fill_mltran(packet_item.crc[7:0]);
                fill_mltran(packet_item.crc[15:8]);
            end
            //fill unused data
            if (mlt_pos < mltran_len) //if mltran is not full - need to add 1-3 bytes to fill residual lanes
                for (int li = mlt_lane; li < p_sequencer.cfg.lanes_used; ++li)
                    req.data[li][mlt_pos] = '{ 8{!req.lastbit[li]} }; //without setting lastbit - it IS lastbit
            //going to ULPS right after EoF.. works bad with many channels 
            req.ulps_after = (p_sequencer.cfg.ulps_after_frame && packet_item.get_packetType() == SP_frameEnd);
            req.is_last = packet_item.is_last; //mark islast
            was_last = packet_item.is_last; //mark islast
            finish_item(req);
            p_sequencer.packet_item_port.item_done();
        end
        uvm_report_info("CSI_MLTRAN", $sformatf("%s got 'is_last', stopping...", p_sequencer.get_name()), UVM_MEDIUM);

        // drop objection if started as a root sequence
        if (starting_phase != null)
            starting_phase.drop_objection(this);
    endtask
    
    function void fill_mltran(byte data);
        uvm_report_info("CSI_MLTRAN", $sformatf("data %x, last %b, lane %d, pos %d", data, data[7], mlt_lane, mlt_pos), UVM_FULL);
        req.data[mlt_lane][mlt_pos] = data;
        //mark lastbit for selected lane
        req.lastbit[mlt_lane] = data[7];
        //increase
        mlt_lane = (mlt_lane + 1) % p_sequencer.cfg.lanes_used;
        if (mlt_lane == 0)
            ++mlt_pos;
    endfunction: fill_mltran
    
endclass: mltran_base_seq_c
    
`endif // __CSI_MLTRAN_SEQ_LIB_SV__