//
// File : csi_driver.sv
//
// Created:
//          by HDL Designers Team
//          of Electronics Design Center "OhT"
//          www.overhitech.com
//
//
// File Description:
//
//% Sequencer-драйвер пакетов CSI
//

`ifndef __CSI_DRIVER_SV__
    `define __CSI_DRIVER_SV__

class driver_c extends uvm_sequencer#(packet_item_c);
    
    uvm_seq_item_pull_port#(vivo_core_pkg::pxl_item_c)        seq_item_port; //not used, but required for VIVO
    uvm_seq_item_pull_port#(vivo_core_pkg::frame_item_c)    frame_item_port;
    uvm_analysis_port#(packet_item_c) aport;

    img_gen_pkg::agent_base_c   p_agent;
    config_c   cfg;

    event   boa;  // begin of active area event
    event   eoa;  // end of active area event
    
    //------------------------------------------------------------------------------------------------------------------
    // UVM automation macros
    //------------------------------------------------------------------------------------------------------------------
    
    `uvm_component_utils_begin(csi_pkg::driver_c)
        `uvm_field_object(p_agent, UVM_ALL_ON | UVM_NOCOMPARE)
        `uvm_field_object  (cfg, UVM_ALL_ON | UVM_NOCOMPARE)
    `uvm_component_utils_end

    //------------------------------------------------------------------------------------------------------------------
    // constructor
    //------------------------------------------------------------------------------------------------------------------
  
    function new (string name = "csi_driver", uvm_component parent = null);
        super.new(name, parent);
        uvm_report_info("LOG", $sformatf("CSI packet sequencer / fake driver (driver_c) has been created with name '%s'", name), UVM_HIGH);
    endfunction : new

    //------------------------------------------------------------------------------------------------------------------
    // build routine
    //------------------------------------------------------------------------------------------------------------------

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        aport = new("aport", this);
        seq_item_port = new("seq_item_port", this);
        frame_item_port = new("frame_item_port", this);
    endfunction : build_phase

    //------------------------------------------------------------------------------------------------------------------
    // configuration update function
    //------------------------------------------------------------------------------------------------------------------

    virtual function void cfg_update();
        if (cfg == null)
            uvm_report_fatal("CFGERR", $sformatf("Can't update configuration. Pointer is empty. (%s)", get_full_name()));
        cfg.cfg_update();
    endfunction

    //------------------------------------------------------------------------------------------------------------------
    // add aport functionality
    //------------------------------------------------------------------------------------------------------------------
  
    function void send_request(uvm_sequence_base sequence_ptr, uvm_sequence_item t, bit rerandomize = 0);
        packet_item_c packet_item;
        if (!$cast(packet_item, t))
            uvm_report_fatal("CASTERR", "Can't cast");
        super.send_request(sequence_ptr, t, rerandomize);
        aport.write(packet_item);
    endfunction : send_request
    
endclass: driver_c
    
`endif // __CSI_DRIVER_SV__