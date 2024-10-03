//
// File : csi_mix_seq_lib.sv
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

`ifndef __CSI_MIX_SEQ_LIB_SV__
    `define __CSI_MIX_SEQ_LIB_SV__
    
//----------------------------------------------------------------------------------------------------------------------
// packet base sequence
//----------------------------------------------------------------------------------------------------------------------

class mix_base_seq_c#(int VCHAN_MAX = 4) extends uvm_sequence#(csi_pkg::packet_item_c);

    //------------------------------------------------------------------------------------------------------------------
    // UVM automation macros
    //------------------------------------------------------------------------------------------------------------------

    `uvm_object_param_utils(csi_pkg::mix_base_seq_c#(VCHAN_MAX))
    `uvm_declare_p_sequencer(csi_pkg::mix_sqr_c)

    //------------------------------------------------------------------------------------------------------------------
    // constructor
    //------------------------------------------------------------------------------------------------------------------

    function new(string name="mix_base_seq");
        super.new(name);
    endfunction

    //------------------------------------------------------------------------------------------------------------------
    // sequence body
    //------------------------------------------------------------------------------------------------------------------

    task body ();
        bit was_last[VCHAN_MAX-1:0] = '{ default:0 }; //last packets for every transaction
        packet_item_c packet_item;
        
        `ifdef UVM_VERSION_1_2
            uvm_phase starting_phase = get_starting_phase();
        `endif
        // raise objection if started as a root sequence
        if (starting_phase != null)
            starting_phase.raise_objection(this);
            
        uvm_report_info("LOG", $sformatf("CSI packet-mixing sequence has started on '%s'.", p_sequencer.get_name()), UVM_MEDIUM);
        if (p_sequencer.cfg == null)
            uvm_report_fatal("NOCFG", {"Configuration must be set for: ", p_sequencer.get_type_name(), ".p_sequencer.cfg"});

        while ($countones(was_last) < p_sequencer.cfg.vchan_used)
            for (int vcid = 0; vcid < p_sequencer.cfg.vchan_used; ++vcid)
                if (!was_last[vcid]) begin
                    p_sequencer.packet_item_port[vcid].get_next_item(packet_item);
                    uvm_report_info("CSI_MIX", $sformatf("%s has received the following transaction:\n%s",
                                get_name(), packet_item.sprint()), UVM_HIGH);
                    $cast(req, packet_item.clone());
                    start_item(req);
                    req.set_channelID(vcid); //assign VC number - recalc ECC inside
                    was_last[vcid] = packet_item.is_last; //check is_last
                    req.is_last = ($countones(was_last) == p_sequencer.cfg.vchan_used);
                    finish_item(req);
                    p_sequencer.packet_item_port[vcid].item_done();
                end
        uvm_report_info("CSI_MIX", $sformatf("%s got 'is_last', stopping...", p_sequencer.get_name()), UVM_MEDIUM);

        // drop objection if started as a root sequence
        if (starting_phase != null)
            starting_phase.drop_objection(this);
    endtask
    
endclass: mix_base_seq_c
    
`endif // __CSI_MLTRAN_SEQ_LIB_SV__