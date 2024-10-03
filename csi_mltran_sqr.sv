//
// File : csi_mltran_sqr.sv
//
// Created:
//          by HDL Designers Team
//          of Electronics Design Center "OhT"
//          www.overhitech.com
//
//
// File Description:
//
//% Sequencer multilane транзакций CSI
//

`ifndef __CSI_MLTRAN_SQR_SV__
    `define __CSI_MLTRAN_SQR_SV__

typedef class ext_agent_base_c;

class mltran_sqr_c#(int LANES_MAX = 4) extends uvm_sequencer#(mltran_item_c#(LANES_MAX));
    
    uvm_seq_item_pull_port#(packet_item_c)             packet_item_port;

    ext_agent_base_c   p_agent;
    ext_config_c   cfg;
    
    //------------------------------------------------------------------------------------------------------------------
    // UVM automation macros
    //------------------------------------------------------------------------------------------------------------------
    
    `uvm_component_param_utils_begin(csi_pkg::mltran_sqr_c#(LANES_MAX))
        `uvm_field_object    (p_agent, UVM_ALL_ON | UVM_NOCOMPARE)
        `uvm_field_object      (cfg    , UVM_ALL_ON | UVM_NOCOMPARE)
    `uvm_component_utils_end

    //------------------------------------------------------------------------------------------------------------------
    // constructor
    //------------------------------------------------------------------------------------------------------------------
  
    function new (string name = "csi_mltran_sqr", uvm_component parent = null);
        super.new(name, parent);
        uvm_report_info("LOG", $sformatf("CSI multi-lane transaction sequencer has been created with name '%s'", name), UVM_HIGH);
    endfunction : new

    //------------------------------------------------------------------------------------------------------------------
    // build routine
    //------------------------------------------------------------------------------------------------------------------

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        packet_item_port = new("packet_item_port", this);
    endfunction : build_phase
    
endclass: mltran_sqr_c
    
`endif // __CSI_MLTRAN_SQR_SV__