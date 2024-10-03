//
// File : csi_ext_agent.sv
//
// Created:
//          by HDL Designers Team
//          of Electronics Design Center "OhT"
//          www.overhitech.com
//
//
// File Description:
//
//% Внешний агент CSI
//

`ifndef __CSI_EXT_AGENT_SV__
    `define __CSI_EXT_AGENT_SV__

//----------------------------------------------------------------------------------------------------------------------
// Base agent class
//----------------------------------------------------------------------------------------------------------------------

class ext_agent_base_c extends uvm_agent;
    
    ext_config_c  cfg;
    
    //------------------------------------------------------------------------------------------------------------------
    // ports
    //------------------------------------------------------------------------------------------------------------------

    //uvm_seq_item_pull_port#(packet_item_c) driver_port [];
    uvm_analysis_port#(packet_item_c) monitor_aport [];
    
    //------------------------------------------------------------------------------------------------------------------
    // UVM automation macros
    //------------------------------------------------------------------------------------------------------------------

    `uvm_component_utils_begin(csi_pkg::ext_agent_base_c)
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

endclass : ext_agent_base_c
    
//----------------------------------------------------------------------------------------------------------------------
// Agent class
//----------------------------------------------------------------------------------------------------------------------

class ext_agent_c#(int LANES_MAX = 4, int VCHAN_MAX = 4) extends ext_agent_base_c;
    
    //------------------------------------------------------------------------------------------------------------------
    // components
    //------------------------------------------------------------------------------------------------------------------
    
    mix_sqr_c#(VCHAN_MAX)             mix_sqr;
    mltran_sqr_c#(LANES_MAX)         mltran_sqr;
    ext_driver_c#(LANES_MAX)         driver;
    
    ext_monitor_c#(LANES_MAX)         monitor;
    mltran2packet_c#(LANES_MAX)        mltran2packet;
    packet_sorter_c#(VCHAN_MAX)        packet_sorter;
    
    //------------------------------------------------------------------------------------------------------------------
    // UVM automation macros
    //------------------------------------------------------------------------------------------------------------------

    `uvm_component_param_utils(csi_pkg::ext_agent_c#(LANES_MAX, VCHAN_MAX))

    //------------------------------------------------------------------------------------------------------------------
    // constructor
    //------------------------------------------------------------------------------------------------------------------

    function new (string name, uvm_component parent);
        super.new(name, parent);
        //driver_port = new[VCHAN_MAX];
        monitor_aport = new[VCHAN_MAX];
    endfunction : new

    //------------------------------------------------------------------------------------------------------------------
    // build routine
    //------------------------------------------------------------------------------------------------------------------

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        //some loading here?
        
        if (cfg.is_active == UVM_ACTIVE) begin
            //ports
            //foreach(driver_port[i])
            //    driver_port[i] = new($sformatf("driver_port_%0d", i), this);
            //sequencers
            mix_sqr = mix_sqr_c#(VCHAN_MAX)::type_id::create("mix_sqr", this);
            mltran_sqr = mltran_sqr_c#(LANES_MAX)::type_id::create("mltran_sqr", this);
            //driver
            driver = ext_driver_c#(LANES_MAX)::type_id::create($sformatf("%s_driver", get_name()), this);
        end
        else begin
            //monitor parts
            monitor = ext_monitor_c#(LANES_MAX)::type_id::create($sformatf("%s_monitor", get_name()), this);
            mltran2packet = mltran2packet_c#(LANES_MAX)::type_id::create("mltran2packet", this);
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
        if (cfg.is_active == UVM_ACTIVE) begin
            //ports
            //foreach(driver_port[i])
            //    driver_port[i].connect(mix_sqr.packet_item_port[i]);
            //sequences and drivers
            mltran_sqr.packet_item_port.connect(mix_sqr.seq_item_export);
            driver.seq_item_port.connect(mltran_sqr.seq_item_export);
        end
        else begin
            //monitor parts
            monitor.mltran_aport.connect(mltran2packet.analysis_export);
            mltran2packet.packet_aport.connect(packet_sorter.analysis_export);
            //monitor ports
            foreach(monitor_aport[i])
                packet_sorter.packet_aport[i].connect(monitor_aport[i]);
        end
    endfunction : connect_phase

    //------------------------------------------------------------------------------------------------------------------
    // run pixel base sequence
    //------------------------------------------------------------------------------------------------------------------

    virtual task run_phase(uvm_phase phase);
        if (check_cfg_params() || cfg.check_cfg())
            uvm_report_fatal("CSICFGERR", "Configuration check didn't passed.");
    endtask : run_phase
            
    //------------------------------------------------------------------------------------------------------------------
    // check config and parameters function
    //------------------------------------------------------------------------------------------------------------------
    
    function int check_cfg_params();
        if (cfg.lanes_used > LANES_MAX) begin
            uvm_report_error("CSI_CFGPARAMCHECK", $sformatf("Used lanes number (%d) is larger than MAX (parameter): %d!", cfg.lanes_used, LANES_MAX));
            return 1;
        end
        if (cfg.vchan_used > VCHAN_MAX) begin
            uvm_report_error("CSI_MIXER", $sformatf("Used virtual channels  number (%d) is larger than MAX (parameter): %d!", cfg.vchan_used, VCHAN_MAX));
            return 1;
        end
        return 0;
    endfunction: check_cfg_params

endclass : ext_agent_c

`endif // __CSI_EXT_AGENT_SV__
