//
// File : csi_test_monitor.sv
//
// Created:
//          by HDL Designers Team
//          of Electronics Design Center "OhT"
//          www.overhitech.com
//
//
// File Description:
//
//% Тестовый монитор CSI для работы с IP CSI
//

`ifndef __CSI_TEST_MONITOR_SV__
    `define __CSI_TEST_MONITOR_SV__

typedef class test_agent_base_c;
    

class test_monitor_c#(int LANES_MAX = 4) extends uvm_monitor;
`timescale 1ns/1ps

    virtual oht_vivo_csi_test_if.monitor_mp vif;
 
    ext_config_c        cfg;
    test_agent_base_c    p_agent;
    
    uvm_analysis_port#(packet_item_c)   packet_aport;
    
    //------------------------------------------------------------------------------------------------------------------
    // UVM automation macros
    //------------------------------------------------------------------------------------------------------------------
    
    `uvm_component_param_utils_begin(csi_pkg::test_monitor_c#(LANES_MAX))
        `uvm_field_object  (p_agent, UVM_ALL_ON | UVM_NOCOMPARE)
        `uvm_field_object  (cfg, UVM_ALL_ON | UVM_NOCOMPARE)
    `uvm_component_utils_end

    //------------------------------------------------------------------------------------------------------------------
    // constructor
    //------------------------------------------------------------------------------------------------------------------

    function new (string name = "csi_test_monitor", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    //------------------------------------------------------------------------------------------------------------------
    // build routine
    //------------------------------------------------------------------------------------------------------------------

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // create aport
        packet_aport = new("packet_aport", this);
        // config interface
        if(!uvm_config_db#(virtual oht_vivo_csi_test_if.monitor_mp)::get(this, "", "vif", vif))
            uvm_report_fatal("NOVIF", {"virtual interface must be set for: ", get_type_name(), ".vif"});
    endfunction: build_phase

    //------------------------------------------------------------------------------------------------------------------
    // run
    //------------------------------------------------------------------------------------------------------------------
    
    virtual task run_phase(uvm_phase phase);
        packet_item_c packet_item;
        
        if (cfg.is_active == UVM_ACTIVE)
            return;
        uvm_report_info("DISP", "CSI test monitor is PASSIVE", UVM_MEDIUM);
        
        
        stop_if();
        wait(cfg.enabled);
        init_if();
        
        forever begin
            
            while  (!(vif.monitor_cb.lp_en_o === 0 && vif.monitor_cb.sp_en_o === 0)) //wait for packet spacing
                @(vif.monitor_cb);
            while  (!(vif.monitor_cb.lp_en_o === 1 || vif.monitor_cb.sp_en_o === 1))
                @(vif.monitor_cb);
            uvm_report_info("LOG", $sformatf("lp %d, sp %d", vif.monitor_cb.lp_en_o, vif.monitor_cb.sp_en_o), UVM_FULL);
            
            packet_item = packet_item_c::type_id::create("reconstructed_packet");
            //reconstruct packet, manually set all fields
            packet_item.dataType = vif.monitor_cb.dt_o;
            packet_item.channelID = vif.monitor_cb.vc_o;
            packet_item.wordCount = vif.monitor_cb.wc_o;
            packet_item.ecc = vif.monitor_cb.ecc_o;
            if (vif.monitor_cb.lp_en_o) begin
                automatic int pcnt = 0;
                //start
                packet_item.data = new[packet_item.wordCount];
                do begin
                    @(vif.monitor_cb);
                    for (int lane = 0; pcnt < packet_item.wordCount && lane < LANES_MAX; ++lane) begin
                        for (int bi = 0; bi < 8; ++bi)
                            packet_item.data[pcnt][bi] = vif.monitor_cb.payload_o[lane*8+bi];
                        ++pcnt;
                    end
                end
                while (vif.monitor_cb.payload_en_o);
            end
            packet_item.recalc_crc();
            uvm_report_info("LOG", $sformatf("Received packet:\n%s", packet_item.sprint()), UVM_HIGH);
            packet_aport.write(packet_item);
        end
    endtask : run_phase

    //------------------------------------------------------------------------------------------------------------------
    // Init function
    //------------------------------------------------------------------------------------------------------------------
    
    task init_if();
        vif.ref_dt_i           <= 'ha2;
        
        vif.reset_lp_n_i       <= 1;
        vif.reset_byte_fr_n_i  <= 1;
        vif.reset_byte_n_i     <= 1;
        vif.reset_n_i          <= 1;
        vif.pd_dphy_i          <= 0;
    endtask: init_if
    
    task stop_if();            
        vif.pll_lock_i         <= 0;
        vif.reset_lp_n_i       <= 0;
        vif.reset_byte_fr_n_i  <= 0;
        vif.reset_byte_n_i     <= 0;
        vif.reset_n_i          <= 0;
        vif.pd_dphy_i          <= 1;
    endtask: stop_if

endclass : test_monitor_c

`endif //__CSI_TEST_MONITOR_SV__
