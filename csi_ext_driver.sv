//
// File : csi_ext_driver.sv
//
// Created:
//          by HDL Designers Team
//          of Electronics Design Center "OhT"
//          www.overhitech.com
//
//
// File Description:
//
//% Драйвер внешнего агента CSI-2
//

`ifndef __CSI_EXT_DRIVER_SV__
    `define __CSI_EXT_DRIVER_SV__

typedef class ext_agent_base_c;
    
//----------------------------------------------------------------------------------------------------------------------
// CSI driver
//----------------------------------------------------------------------------------------------------------------------

class ext_driver_c#(int LANES_MAX = 4)
        extends uvm_driver#(mltran_item_c#(LANES_MAX));
    
`timescale 1ns/1ps
    
    ext_config_c cfg;
    ext_agent_base_c   p_agent;

    //------------------------------------------------------------------------------------------------------------------
    // Ports
    //------------------------------------------------------------------------------------------------------------------
    
    virtual oht_vivo_csi_ppi_if#(LANES_MAX).driver_mp vif;
    
    //------------------------------------------------------------------------------------------------------------------
    // Signal data
    //------------------------------------------------------------------------------------------------------------------
    
    //For CLK-DATA HS mode synchronizing
    clk_state_t clk_state    = CLK_LP; // 0 = ulps, 1 = lp, 2 = hs
    bit clk_busy     = 0; //flag for switching clk lane (too lazy to google for mutex)
    
    //constants
    const byte sync_sequence = 8'b10111000;
    const bit[0:7] esc_cmd_ULPS = 8'b00011110;
    
    
    //------------------------------------------------------------------------------------------------------------------
    // UVM automation macros
    //------------------------------------------------------------------------------------------------------------------

    `uvm_component_param_utils_begin(csi_pkg::ext_driver_c#(LANES_MAX))
        `uvm_field_object      (cfg    , UVM_ALL_ON | UVM_NOCOMPARE)
    `uvm_component_utils_end

    //------------------------------------------------------------------------------------------------------------------
    // constructor
    //------------------------------------------------------------------------------------------------------------------

    function new (string name = "csi_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    //------------------------------------------------------------------------------------------------------------------
    // build routine
    //------------------------------------------------------------------------------------------------------------------

    function void build_phase (uvm_phase phase);
        super.build_phase(phase);
        // config interface
        if(!uvm_config_db#(virtual oht_vivo_csi_ppi_if#(LANES_MAX).driver_mp)::get(this, "", "vif", vif))
            uvm_report_fatal("NOVIF", {"virtual interface must be set for: ", get_type_name(), ".vif"});
    endfunction : build_phase

    //------------------------------------------------------------------------------------------------------------------
    // configuration update function
    //------------------------------------------------------------------------------------------------------------------

    function void cfg_update();
        if (cfg == null)
            uvm_report_fatal("CFGERR", $sformatf("Can't update configuration. Pointer is empty. (%s)", get_full_name()));
        cfg.cfg_update();
    endfunction

    //------------------------------------------------------------------------------------------------------------------
    // run driver
    //------------------------------------------------------------------------------------------------------------------

    task update_passive; //update config for monitor
        uvm_report_info("DISP", "CameraLink driver is PASSIVE, but still updating...", UVM_HIGH);
        forever begin  // wait for enabled
            if (!cfg.enabled)
                cfg_update();
            #1;
        end
    endtask: update_passive
    
    virtual task run_phase(uvm_phase phase);
        byte hs_buffer [LANES_MAX-1:0];
        bit was_last = 0;
        
        if (cfg == null)
            uvm_report_fatal("NOCFG", {"Configuration must be set for: ", get_type_name(), ".cfg"});
        cfg_update();

        if (cfg.is_active == UVM_PASSIVE) begin
            fork
                update_passive();
            join_none
            return;
        end
        
        //check cfg params
        if (cfg.lanes_used > LANES_MAX)
            uvm_report_fatal("CSI_EXT_DRV", $sformatf("Used lanes number (%d) is larger than MAX (parameter): %d!", cfg.lanes_used, LANES_MAX));
            
        uvm_report_info("DISP", "CSI external driver is ACTIVE", UVM_MEDIUM);
        
        //reset
        stop_if();
        //init if
        #100ns;
        init_if();

        //if clock is continuous, we can switch to hs
        if (cfg.continuous_clock && clk_state == CLK_LP) //triggers always, but let it be
            dphy_clk_switch_hs();
        
        while (!was_last) begin
            forever begin  // wait for enabled
                cfg_update();
                if (cfg.enabled)
                    break;
                @(posedge vif.refclk); // wait for last bit to be driven
                //don't reset interface!
            end
            
            //start all lanes
            dphy_data_sot();
            //get transaction
            seq_item_port.get_next_item(req);
            uvm_report_info("CSI_EXT_DRV", $sformatf("%s has received the following transaction:\n%s",
                        get_name(), req.sprint()), UVM_HIGH);
            for (int i = 0; i < req.length; ++i) begin
                for (int lane = 0; lane < cfg.lanes_used; ++lane)
                    hs_buffer[lane] = req.data[lane][i];
                data_hs(hs_buffer);
            end
            was_last = req.is_last;//set islast
            //send EoT to all lanes
            dphy_data_eot();
            //check ULPS flag
            if (req.ulps_after && !was_last) begin
                fork
                    dphy_data_ulps_enter();
                    if (cfg.en_clk_ulps) begin
                        if (cfg.continuous_clock)
                            dphy_clk_switch_lp();
                        dphy_clk_ulps_enter();
                    end
                join
                #cfg.t_ulps;
                fork
                    if (cfg.en_clk_ulps) begin
                        dphy_clk_ulps_exit();
                        if (cfg.continuous_clock)
                            dphy_clk_switch_hs();
                    end
                    dphy_data_ulps_exit();
                join
            end
            //after EoT ended - free item
            seq_item_port.item_done();
        end
        //if clock is continuous, we can switch to lp
        if (cfg.continuous_clock && clk_state == CLK_HS) //triggers always, but let it be
            dphy_clk_switch_lp();
        if (clk_state != CLK_ULPS) //or maybe even to ULPS?
            fork
                dphy_data_ulps_enter();
                if (cfg.en_clk_ulps)
                    dphy_clk_ulps_enter();
            join
        uvm_report_info("CSI_EXT_DRV", $sformatf("%s got 'is_last', stopping...", get_name()), UVM_MEDIUM);
        stop_if();
        uvm_report_info("CSI_EXT_DRV", $sformatf("%s is stopped.", get_name()), UVM_MEDIUM);
    endtask : run_phase

    task init_if();
        vif.usrstdby    <= #(cfg.t_data_delay * cfg.t_ui) 0;
        vif.pd_pll        <= #(cfg.t_data_delay * cfg.t_ui) 0;
        //LP (async)
        clk_lp(1, 1);
        data_lp(1, 1);
        //HS (sync)
        @(posedge vif.txhsbyteclk) begin
            vif.clk_txhsgate <= 1;
            vif.txdata <= 0;
        end
        //wait for pll lock
        wait(vif.lock);
    endtask: init_if

    task stop_if();
        vif.usrstdby     <= #(cfg.t_data_delay * cfg.t_ui) 1;
        vif.pd_pll         <= #(cfg.t_data_delay * cfg.t_ui) 1;
    endtask: stop_if

    //------------------------------------------------------------------------------------------------------------------
    // CLK lane
    //------------------------------------------------------------------------------------------------------------------
    
    //LP(dp, dn)
    task clk_lp (bit dp, bit dn);
        vif.clk_txlpen     <= #(cfg.t_data_delay * cfg.t_ui) 1;
        vif.clk_txhsen     <= #(cfg.t_data_delay * cfg.t_ui) 0;
        vif.clk_txlpp     <= #(cfg.t_data_delay * cfg.t_ui) dp;
        vif.clk_txlpn     <= #(cfg.t_data_delay * cfg.t_ui) dn;
    endtask: clk_lp
    
    //HS(enable)
    task clk_hs (bit enable);
        vif.clk_txlpen     <= #(cfg.t_data_delay * cfg.t_ui) 0;
        vif.clk_txhsen     <= #(cfg.t_data_delay * cfg.t_ui) 1;        
        @(posedge vif.txhsbyteclk)
            vif.clk_txhsgate <= !enable;
    endtask: clk_hs
    
    //start of HS clock
    task dphy_clk_switch_hs ();
        clk_busy = 1;
        //starting from LP 11
        if (clk_state == CLK_ULPS)
            dphy_clk_ulps_exit();
        //LP01
        clk_lp(0, 1);
        #cfg.t_lpx;
        //LP00
        clk_lp(0, 0);
        #cfg.t_clk_prepare;
        //HS - 0
        clk_hs(0);
        #cfg.t_clk_zero;
        //HS - clk-pre setup period
        clk_hs(1);
        #cfg.t_clk_pre;
        //setting flagss
        clk_state = CLK_HS;
        clk_busy = 0;
        uvm_report_info("CSI_EXT_DRV", "CLK: HS mode", UVM_MEDIUM);
    endtask: dphy_clk_switch_hs
    
    //end of HS clock
    task dphy_clk_switch_lp ();
        clk_busy = 1;
        //starting from HS-active
        #cfg.t_clk_post;
        //zero for trail
        clk_state = CLK_LP;
        uvm_report_info("CSI_EXT_DRV", "CLK: LP mode", UVM_MEDIUM);
        clk_hs(0);
        #cfg.t_clk_trail;
            /*
             * Teot is strange; looks like a max value for Trail
            //Disabling hs - LP00
            clk_lp(0, 0);
            #(cfg.t_eot - cfg.t_clk_trail);
            */
        //LP11
        clk_lp(1, 1);
        #cfg.t_hs_exit;
        //setting flags
        clk_busy = 0;
    endtask: dphy_clk_switch_lp
    
    //ULPS-entry
    task dphy_clk_ulps_enter ();
        clk_busy = 1;
        //check
        if (clk_state == CLK_HS)
            dphy_clk_switch_lp;
        //unique CLK procedure
        clk_lp(1, 0);
        #cfg.t_lpx;
        //ULPS
        clk_lp(0, 0);
        clk_state = CLK_ULPS;
        clk_busy = 0;
        uvm_report_info("CSI_EXT_DRV", "CLK: ULPS entered", UVM_MEDIUM);
    endtask: dphy_clk_ulps_enter
    
    //ULPS-exit
    task dphy_clk_ulps_exit ();
        clk_busy = 1;
        //wakeup
        clk_lp(1, 0);
        #cfg.t_wakeup;
        clk_lp(1, 1);
        //unnecessary: wait for Tlpx (other functions DO NOT wait after start)
        #cfg.t_lpx;
        clk_state = CLK_LP;
        clk_busy = 0;
        uvm_report_info("CSI_EXT_DRV", "CLK: ULPS exited, LP mode", UVM_MEDIUM);
    endtask: dphy_clk_ulps_exit

    //------------------------------------------------------------------------------------------------------------------
    // DATA lanes
    //------------------------------------------------------------------------------------------------------------------
    
    //LP(dp, dn)
    task data_lp (bit dp, bit dn);
        vif.d0_txlpen     <= #(cfg.t_data_delay * cfg.t_ui) 1;
        vif.d0_txhsen     <= #(cfg.t_data_delay * cfg.t_ui) 0;
        for (int lane = 0; lane < cfg.lanes_used; ++lane) begin
            vif.d_txlpp    [lane]     <= #(cfg.t_data_delay * cfg.t_ui) dp;
            vif.d_txlpn    [lane]     <= #(cfg.t_data_delay * cfg.t_ui) dn;
        end
    endtask: data_lp
    
    //HS(data)
    task data_hs (byte data [LANES_MAX-1:0]); //active lanes - to drive !last_bit on NON-active lanes...
        vif.d0_txlpen     <= #(cfg.t_data_delay * cfg.t_ui) 0;
        vif.d0_txhsen     <= #(cfg.t_data_delay * cfg.t_ui) 1;
        
        uvm_report_info("CSI_EXT_DRV", $sformatf("Driving data: L0 = %x || L1 = %x || L2 = %x || L3 = %x", data[0], data[1], data[2], data[3]), UVM_HIGH);
        
        @(posedge vif.txhsbyteclk);
        for (int lane = 0; lane < cfg.lanes_used; ++lane)
            for (int bi = 0; bi < 8; ++bi)
                vif.txdata[lane + bi * cfg.lanes_used] <= data[lane][bi];
    endtask: data_hs
    
    //start of transmission - ONLY after HS clk
    task dphy_data_sot ();
        //check clock lane
        uvm_report_info("CSI_EXT_DRV", "DATA Lanes - waiting for HS CLK", UVM_HIGH);
        if (!cfg.continuous_clock && clk_state != CLK_HS)
            dphy_clk_switch_hs();
        uvm_report_info("CSI_EXT_DRV", "DATA Lanes - switching to HS...", UVM_HIGH);
        //starting from LP 11
        //LP01
        data_lp(0, 1);
        #cfg.t_lpx;
        //LP00
        data_lp(0, 0);
        #cfg.t_hs_prepare;
        //HS - 0
        data_hs('{ 4{0} });
        uvm_report_info("CSI_EXT_DRV", "DATA Lanes - HS start", UVM_HIGH);
        #cfg.t_hs_zero;
        //HS - starting sequence (reversed to LSB))
        data_hs('{ 4{sync_sequence} });
        uvm_report_info("CSI_EXT_DRV", "DATA Lanes - HS mode", UVM_MEDIUM);
    endtask: dphy_data_sot
    
    //end of transmission
    task dphy_data_eot ();
        byte hs_buffer [LANES_MAX-1:0];
        
        //flip last state
        uvm_report_info("CSI_EXT_DRV", "DATA Lanes - driving HS-trail", UVM_HIGH);
        for (int lane = 0; lane < cfg.lanes_used; ++lane)
            hs_buffer[lane] = '{8{!req.lastbit[lane]}};
        data_hs(hs_buffer); //all lanes -> !lasthsbit
        #cfg.t_hs_trail;
        //LP11
        data_lp(1, 1);
        uvm_report_info("CSI_EXT_DRV", "DATA Lanes - LP mode", UVM_MEDIUM);
        
        fork
            if (!cfg.continuous_clock)
                dphy_clk_switch_lp();
            //wait for exit time
            #cfg.t_hs_exit;
        join
    endtask: dphy_data_eot
    
    //Spaced one-hot (one bit transmission)
    task dphy_lp_soh (bit b);
        data_lp(b, !b);
        #cfg.t_lpx;
        data_lp(0, 0);
        #cfg.t_lpx;
    endtask: dphy_lp_soh
    
    //ULPS-entry
    task dphy_escape_cmd (bit [0:7] cmd);
        //EM entry procedure
        dphy_lp_soh(1);
        dphy_lp_soh(0);
        //command
        uvm_report_info("CSI_EXT_DRV", $sformatf("Sending escape mode command: %b", cmd), UVM_MEDIUM);
        for (int i = 0; i < 8; ++i)
            dphy_lp_soh(cmd[i]);
        //do not exit, wait for command continuing
    endtask: dphy_escape_cmd
    
    //ULPS-entry
    task dphy_data_ulps_enter ();
        //send command to enter ULPS
        dphy_escape_cmd(esc_cmd_ULPS);
        //continue driving LP00
        data_lp(0, 0); //unnecessary (already in 00 after escape), but... let it be here
        uvm_report_info("CSI_EXT_DRV", "DATA Lanes: ULPS entered", UVM_MEDIUM);
    endtask: dphy_data_ulps_enter
    
    //ULPS-exit
    task dphy_data_ulps_exit ();
        //wakeup
        data_lp(1, 0);
        #cfg.t_wakeup;
        data_lp(1, 1);
        //unnecessary: wait for Tlpx (other functions DO NOT wait after start)
        #cfg.t_lpx;
        uvm_report_info("CSI_EXT_DRV", "DATA Lanes: ULPS exited, LP mode", UVM_MEDIUM);
    endtask: dphy_data_ulps_exit

endclass : ext_driver_c

`endif // __CSI_EXT_DRIVER_SV__
