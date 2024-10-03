//
// File : csi_test_agent.sv
//
// Created:
//          by HDL Designers Team
//          of Electronics Design Center "OhT"
//          www.overhitech.com
//
//
// File Description:
//
//% Test agent CSI
//

`ifndef __CSI_TEST_AGENT_SV__
    `define __CSI_TEST_AGENT_SV__

//----------------------------------------------------------------------------------------------------------------------
// Base agent class
//----------------------------------------------------------------------------------------------------------------------

class test_agent_base_c extends uvm_agent;
    
    ext_config_c  cfg;
    
    //------------------------------------------------------------------------------------------------------------------
    // ports
    //------------------------------------------------------------------------------------------------------------------

    uvm_analysis_port#(packet_item_c) monitor_aport [];
    
    //------------------------------------------------------------------------------------------------------------------
    // UVM automation macros
    //------------------------------------------------------------------------------------------------------------------

    `uvm_component_utils_begin(csi_pkg::test_agent_base_c)
        `uvm_field_object  (cfg, UVM_ALL_ON | UVM_NOCOMPARE)
    `uvm_component_utils_end

    //------------------------------------------------------------------------------------------------------------------
    // constructor
    //------------------------------------------------------------------------------------------------------------------

    function new (string name, uvm_component parent);
        super.new(name, parent);
    endfunction : new
    //------------------------------------------------------------------------------------------------------------------
    // build routine
    //------------------------------------------------------------------------------------------------------------------

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (cfg == null)
            uvm_report_fatal("CFGERR", $sformatf("Configuration is not defined for '%s'", get_full_name()));
    endfunction : build_phase

endclass : test_agent_base_c
    
//----------------------------------------------------------------------------------------------------------------------
// Agent class
//----------------------------------------------------------------------------------------------------------------------

class test_agent_c#(int LANES_MAX = 4, int VCHAN_MAX = 4) extends test_agent_base_c;
    
    //------------------------------------------------------------------------------------------------------------------
    // components
    //------------------------------------------------------------------------------------------------------------------
    
    test_monitor_c#(LANES_MAX)         monitor;
    packet_sorter_c#(VCHAN_MAX)        packet_sorter;
    
    //------------------------------------------------------------------------------------------------------------------
    // UVM automation macros
    //------------------------------------------------------------------------------------------------------------------

    `uvm_component_param_utils(csi_pkg::test_agent_c#(LANES_MAX, VCHAN_MAX))

    //------------------------------------------------------------------------------------------------------------------
    // constructor
    //------------------------------------------------------------------------------------------------------------------

    function new (string name, uvm_component parent);
        super.new(name, parent);
        monitor_aport = new[VCHAN_MAX];
    endfunction : new

    //------------------------------------------------------------------------------------------------------------------
    // build routine
    //------------------------------------------------------------------------------------------------------------------

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        //some loading here?
        
        begin
            //monitor parts
            monitor = test_monitor_c#(LANES_MAX)::type_id::create($sformatf("%s_monitor", get_name()), this);
            packet_sorter = packet_sorter_c#(VCHAN_MAX)::type_id::create("packet_sorter", this);
            //monitor ports
            foreach(monitor_aport[i])
                monitor_aport[i] = new($sformatf("monitor_aport_%0d", i), this);
        end
        //spread cfg & agent pointers on all subcomponents
        uvm_config_db#(uvm_object)::set(this, "*", "cfg", cfg);
        uvm_config_db#(uvm_object)::set(this, "*", "p_agent", this);
    endfunction : build_phase

    //------------------------------------------------------------------------------------------------------------------
    // connect routine
    //------------------------------------------------------------------------------------------------------------------

    virtual function void connect_phase(uvm_phase phase);
        begin
            //monitor parts
            monitor.packet_aport.connect(packet_sorter.analysis_export);
            //monitor ports
            foreach(monitor_aport[i])
                packet_sorter.packet_aport[i].connect(monitor_aport[i]);
        end
    endfunction : connect_phase

endclass : test_agent_c

`endif // __CSI_TEST_AGENT_SV__
