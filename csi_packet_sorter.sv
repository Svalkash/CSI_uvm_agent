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
//% Сортировщик пакетов с монитора по выходам
//

`ifndef __CSI_PACKET_SORTER_SV__
    `define __CSI_PACKET_SORTER_SV__

typedef class ext_agent_base_c;
    

class packet_sorter_c#(int VCHAN_MAX = 4) extends uvm_subscriber#(packet_item_c);
 
    ext_agent_base_c    p_agent;
    ext_config_c        cfg;
    
    uvm_analysis_port#(packet_item_c) packet_aport [VCHAN_MAX-1:0];
    
    //------------------------------------------------------------------------------------------------------------------
    // UVM automation macros
    //------------------------------------------------------------------------------------------------------------------
    
    `uvm_component_param_utils_begin(csi_pkg::packet_sorter_c#(VCHAN_MAX))
        `uvm_field_object  (p_agent, UVM_ALL_ON | UVM_NOCOMPARE)
        `uvm_field_object  (cfg, UVM_ALL_ON | UVM_NOCOMPARE)
    `uvm_component_utils_end

    //------------------------------------------------------------------------------------------------------------------
    // constructor
    //------------------------------------------------------------------------------------------------------------------

    function new (string name = "csi_packet_sorter", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    //------------------------------------------------------------------------------------------------------------------
    // build routine
    //------------------------------------------------------------------------------------------------------------------

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        foreach(packet_aport[i])
            packet_aport[i] = new($sformatf("packet_aport_%0d", i), this);
    endfunction: build_phase

    //------------------------------------------------------------------------------------------------------------------
    // write function
    //------------------------------------------------------------------------------------------------------------------

    function void write (packet_item_c t);
        int vcid = t.channelID;
        uvm_report_info("CSI_SORTER", $sformatf("CSI packet reconstructor has received the following packet:\n%s", t.sprint), UVM_HIGH);
        
        //check VChan ID
        if (vcid >= cfg.vchan_used)
            uvm_report_error("CSI_BIGVCID", $sformatf("Too big virtual channel number: %0d!", vcid));
        //packet is fixed and good now... so just send it to the right direction :)
        packet_aport[vcid].write(t);
    endfunction: write
    
endclass: packet_sorter_c

`endif //__CSI_PACKET_SORTER_SV__
