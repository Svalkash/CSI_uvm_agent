//
// File : csi_dphy_checker.sv
//
// Created:
//          by HDL Designers Team
//          of Electronics Design Center "OhT"
//          www.overhitech.com
//
//
// File Description:
//
//% Чекер CSI
//

`ifndef __CSI_DPHY_CHECKER_SV__
    `define __CSI_DPHY_CHECKER_SV__
    
`define TCHECK_MIN(T_NAME, VAL, LANE) begin \
    if (VAL < cfg.``T_NAME``_min) \
        uvm_report_error("CSI_DPC_TIMING_ERR", $sformatf("[LANE: %0s] Timing error (%s = %t)! Min = %t", `"LANE`", `"T_NAME`", VAL, cfg.``T_NAME``_min)); \
end
    
`define TCHECK_MAX(T_NAME, VAL, LANE) begin \
    if (VAL > cfg.``T_NAME``_max) \
        uvm_report_error("CSI_DPC_TIMING_ERR", $sformatf("[LANE: %0s] Timing error (%s = %t)! Max = %t", `"LANE`", `"T_NAME`", VAL, cfg.``T_NAME``_max)); \
end
    
`define TCHECK_MINMAX(T_NAME, VAL, LANE) begin \
    if (VAL < cfg.``T_NAME``_min || VAL > cfg.``T_NAME``_max) \
        uvm_report_error("CSI_DPC_TIMING_ERR", $sformatf("[LANE: %0s] Timing error (%s = %t)! Min = %t, Max = %d.", `"LANE`", `"T_NAME`", VAL, cfg.``T_NAME``_min, cfg.``T_NAME``_max)); \
end

`define abs(v1) ((v1) >= 0 ? v1 : -v1)

class dphy_checker_c#(int CSI_LANES_MAX = 4) extends uvm_component;
    
    `timescale 1ns/1ps
    
    //------------------------------------------------------------------------------------------------------------------
    // Ports 
    //------------------------------------------------------------------------------------------------------------------
    
    dpc_config_c#(CSI_LANES_MAX) cfg;
    
    virtual oht_vivo_csi_bidir_if#(CSI_LANES_MAX).checker_mp vif;

    //------------------------------------------------------------------------------------------------------------------
    // Signal data
    //------------------------------------------------------------------------------------------------------------------
    
    txState_t data_state[CSI_LANES_MAX-1:0] = '{ default: TX_Stop };
    txState_t clk_state = TX_Stop;
    
    //last change
    realtime data_changed[CSI_LANES_MAX-1:0] = '{ default: 0 };
    realtime clk_changed = 0;
    
    //between previous change and last change
    realtime data_stable[CSI_LANES_MAX-1:0] = '{ default: 0 };
    realtime clk_stable = 0;
    
    //marks for CLK-DATA sync
    realtime t_clk_post_start = 0;
    realtime t_clk_pre_start = 0;
    
    bit[0:7] escapeCmd[CSI_LANES_MAX-1:0];
    bit[0:7] syncSeqRec[CSI_LANES_MAX-1:0]; //received sync sequence
    
    const bit[7:0] sync_sequence = 8'b10111000;
    const bit[0:7] esc_cmd_ULPS = 8'b00011110;
    
    //------------------------------------------------------------------------------------------------------------------
    // UVM automation macros
    //------------------------------------------------------------------------------------------------------------------

    `uvm_component_utils_begin(csi_pkg::dphy_checker_c#(CSI_LANES_MAX))
        `uvm_field_object  (cfg, UVM_ALL_ON | UVM_NOCOMPARE)
    `uvm_component_utils_end

    //------------------------------------------------------------------------------------------------------------------
    // constructor
    //------------------------------------------------------------------------------------------------------------------

    function new (string name = "csi_dphy_checker", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    //------------------------------------------------------------------------------------------------------------------
    // build routine
    //------------------------------------------------------------------------------------------------------------------

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (cfg == null)
            uvm_report_fatal("CFGERR", $sformatf("Configuration is not defined for '%s'", get_full_name()));
        // config interface
        if(!uvm_config_db#(virtual oht_vivo_csi_bidir_if#(CSI_LANES_MAX).checker_mp)::get(this, "", "vif", vif))
            uvm_report_fatal("NOVIF", {"virtual interface must be set for: ", get_type_name(), ".vif"});
        //set timeformat
        $timeformat(-9, 3, "ns", 10);
    endfunction: build_phase

    //------------------------------------------------------------------------------------------------------------------
    // configuration update function
    //------------------------------------------------------------------------------------------------------------------

    virtual function void cfg_update();
        if (cfg == null)
            uvm_report_fatal("CFGERR", $sformatf("Can't update configuration. Pointer is empty. (%s)", get_full_name()));
        cfg.cfg_update();
    endfunction

    //------------------------------------------------------------------------------------------------------------------
    // run
    //------------------------------------------------------------------------------------------------------------------
    
    virtual task run_phase(uvm_phase phase);
        if (cfg == null)
            uvm_report_fatal("NOCFG", {"Configuration must be set for: ", get_type_name(), ".cfg"});
        cfg_update();
        forever begin
            wait(cfg.enabled);
            uvm_report_info("DISP", "CSI D-PHY checker is started.", UVM_HIGH);
            fork
                dphy_clkSM();
            join_none
            for (int li = 0; li < cfg.lanes; ++li)
                fork
                    automatic int lane = li;
                    dphy_dataSM(lane);
                join_none
            wait(!cfg.enabled);
            disable fork;
            uvm_report_info("DISP", "CSI D-PHY checker is stopped.", UVM_HIGH);
        end
    endtask : run_phase

    //------------------------------------------------------------------------------------------------------------------
    // CLK lane
    //------------------------------------------------------------------------------------------------------------------
    
    //event will NOT trigger if LP00/11 translates to HS 00/11. But that should not be possible.
    task dphy_clk_waitChange();
        @(vif.clk_p or vif.clk_n);
        clk_stable = $realtime - clk_changed;
        clk_changed = $realtime;
    endtask: dphy_clk_waitChange
    
    //cool error handler
    task dphy_clkSM_error(txState_t txState);
        uvm_report_error("CSI_DPC_CLKSM_ERR", $sformatf("%s: invalid transition (p/n: %0b %0b)!", txState, vif.clk_p, vif.clk_n));
        while ({vif.clk_p, vif.clk_n} != {1'b1, 1'b1})
            dphy_clk_waitChange(); //error recovery
        clk_state = TX_Stop;
    endtask: dphy_clkSM_error
    
    task dphy_clkSM();
        realtime preparezero_sum = 0;
        
        //wait for starting STOP state :)
        do begin
            dphy_clk_waitChange();
        end
        while ({vif.clk_p, vif.clk_n} != {1'b1, 1'b1});
        //start SM
        forever
            case(clk_state)
                TX_Stop: begin
                    uvm_report_info("CSI_DPC_CLKSM_LOG", "CLK: TX_Stop", UVM_HIGH);
                    dphy_clk_waitChange();
                    `TCHECK_MIN(t_lpx, clk_stable, CLK)
                    case({vif.clk_p, vif.clk_n})
                        {1'b0, 1'b1}: clk_state = TX_HS_Rqst;
                        {1'b1, 1'b0}: clk_state = TX_ULPS_Rqst;
                        default: dphy_clkSM_error(clk_state);
                    endcase
                end
                TX_HS_Rqst: begin
                    uvm_report_info("CSI_DPC_CLKSM_LOG", "CLK: TX_HS_Rqst", UVM_HIGH);
                    dphy_clk_waitChange();
                    `TCHECK_MIN(t_lpx, clk_stable, CLK)
                    case({vif.clk_p, vif.clk_n})
                        {1'b0, 1'b0}: clk_state = TX_HS_Prpr;
                        default: dphy_clkSM_error(clk_state);
                    endcase
                end
                TX_HS_Prpr: begin
                    uvm_report_info("CSI_DPC_CLKSM_LOG", "CLK: TX_HS_Prpr", UVM_HIGH);
                    dphy_clk_waitChange();
                    case({vif.clk_p, vif.clk_n})
                        {1'b0, 1'b1}: begin
                            preparezero_sum = clk_stable;
                            `TCHECK_MINMAX(t_clk_prepare, clk_stable, CLK)
                            clk_state = TX_HS_Go;
                        end
                        default: dphy_clkSM_error(clk_state);
                    endcase
                end
                TX_HS_Go: begin
                    uvm_report_info("CSI_DPC_CLKSM_LOG", "CLK: TX_HS_Go", UVM_HIGH);
                    dphy_clk_waitChange();
                    case({vif.clk_p, vif.clk_n})
                        {1'b1, 1'b0}: begin
                            preparezero_sum += clk_stable;
                            `TCHECK_MIN(t_clk_preparezero, preparezero_sum, CLK)
                            t_clk_pre_start = $realtime; //clock is started, mark for DATA
                            clk_state = TX_HS_1;
                        end
                        default: dphy_clkSM_error(clk_state);
                    endcase
                end
                TX_HS_0: begin
                    uvm_report_info("CSI_DPC_CLKSM_LOG", "CLK: TX_HS_0/Trail", UVM_HIGH);
                    dphy_clk_waitChange();
                    case({vif.clk_p, vif.clk_n})
                        {1'b1, 1'b0}: begin
                            `TCHECK_MAX(t_ui, clk_stable, CLK)
                            if (cfg.strictTuiCheck && (clk_stable < 0.85 * cfg.t_ui || clk_stable > 1.15 * cfg.t_ui))
                                uvm_report_error("CSI_DPC_TIMING_ERR",
                                        $sformatf("STRICT UI CHECK: [LANE: CLK] Timing error (%s = %t)! Defined (in config) = %t", "t_ui", clk_stable, cfg.t_ui));
                            clk_state = TX_HS_1;
                        end
                        {1'b1, 1'b1}: begin
                            `TCHECK_MIN(t_clk_trail, clk_stable, CLK) //check CLK_trail length
                            `TCHECK_MAX(t_eot, clk_stable, CLK)
                            for (int lane = 0; lane < cfg.lanes; ++lane)
                                if (data_state[lane] inside { TX_HS_Rqst, TX_HS_Prpr, TX_HS_Go, TX_HS_Sync, TX_HS_0, TX_HS_1 })
                                    uvm_report_error("CSI_DPC_CLKSM_ERR", "HS CLK disabled while some data lanes were in HS");
                                `TCHECK_MIN(t_clk_post, ($realtime - clk_stable) - t_clk_post_start, CLK) //LAST hs transition - last data lane going LP
                            clk_state = TX_Stop;
                            //check HS_Exit
                            fork
                                begin
                                    @(clk_state); //triggers on next state (signal) change
                                    `TCHECK_MIN(t_hs_exit, clk_stable, CLK) //stable stop duration
                                end
                            join_none
                        end
                        default: dphy_clkSM_error(clk_state);
                    endcase
                end
                TX_HS_1: begin
                    uvm_report_info("CSI_DPC_CLKSM_LOG", "CLK: TX_HS_1/Trail", UVM_HIGH);
                    dphy_clk_waitChange();
                    //no "trail" option: CLK trail MUST be 0
                    case({vif.clk_p, vif.clk_n})
                        {1'b0, 1'b1}: begin
                            `TCHECK_MAX(t_ui, clk_stable, CLK)
                            if (cfg.strictTuiCheck && `abs(clk_stable - cfg.t_ui) > (cfg.skew_dev_percent_max / 100.0) * cfg.t_ui)
                                uvm_report_error("CSI_DPC_TIMING_ERR",
                                        $sformatf("STRICT UI CHECK: Timing error (%s = %t)! Defined (in config) = %t", "t_ui", clk_stable, cfg.t_ui));
                            clk_state = TX_HS_0;
                        end
                        default: dphy_clkSM_error(clk_state);
                    endcase
                end
                TX_ULPS_Rqst: begin
                    uvm_report_info("CSI_DPC_CLKSM_LOG", "CLK: TX_ULPS_Rqst", UVM_HIGH);
                    dphy_clk_waitChange();
                    `TCHECK_MIN(t_lpx, clk_stable, CLK)
                    case({vif.clk_p, vif.clk_n})
                        {1'b0, 1'b0}: clk_state = TX_ULPS;
                        default: dphy_clkSM_error(clk_state);
                    endcase
                end
                TX_ULPS: begin
                    uvm_report_info("CSI_DPC_CLKSM_LOG", "CLK: TX_ULPS", UVM_HIGH);
                    dphy_clk_waitChange();
                    //don't check anything
                    case({vif.clk_p, vif.clk_n})
                        {1'b1, 1'b0}: clk_state = TX_ULPS_Exit;
                        default: dphy_clkSM_error(clk_state);
                    endcase
                end
                TX_ULPS_Exit: begin
                    uvm_report_info("CSI_DPC_CLKSM_LOG", "CLK: TX_ULPS_Exit", UVM_HIGH);
                    dphy_clk_waitChange();
                    `TCHECK_MIN(t_wakeup, clk_stable, CLK)
                    case({vif.clk_p, vif.clk_n})
                        {1'b1, 1'b1}: clk_state = TX_Stop;
                        default: dphy_clkSM_error(clk_state);
                    endcase
                end
                default: uvm_report_error("CSI_DPC_CLKSM_ERR", "Invalid clock SM state!");
            endcase
    endtask: dphy_clkSM

    //------------------------------------------------------------------------------------------------------------------
    // DATA lanes
    //------------------------------------------------------------------------------------------------------------------
    
    //event will NOT trigger if LP00/11 translates to HS 00/11. But that should not be possible.
    task dphy_data_waitChange(int lane);
        @(vif.data_p[lane] or vif.data_n[lane]);
        data_stable[lane] = $realtime - data_changed[lane];
        data_changed[lane] = $realtime;
    endtask: dphy_data_waitChange
    
    //event will NOT trigger if LP00/11 translates to HS 00/11. But that should not be possible.
    task dphy_data_getHSbit(int lane);
        bit dataSwitched = 0;
        
        fork
            begin: dphy_data_getHSbit_waitChange
                dphy_data_waitChange(lane);
                dataSwitched = 1;
                if (!({vif.data_p[lane], vif.data_n[lane]} inside {{1'b0, 1'b1}, {1'b1, 1'b0}})) //illegal bit or LP transition, don't check timing
                    disable dphy_data_getHSbit_legalBit;
            end: dphy_data_getHSbit_waitChange
            begin: dphy_data_getHSbit_legalBit
                @(clk_state); //before CLK state change, time (clk_changed/stable) will be changed already
                if (!dataSwitched)
                    disable dphy_data_getHSbit_waitChange;
                else begin
                    automatic realtime skew_dev = data_changed[lane] - (clk_changed - clk_stable / 2);
                    //check data skew
                    if (`abs(skew_dev) > (cfg.skew_dev_percent_max / 100.0) * clk_stable)
                        uvm_report_error("CSI_DPC_TIMING_ERR", $sformatf("[LANE: %0d] Timing error (%s = %t)! Max deviation = %t%%; t_ui (instant) = %t",
                                    lane, "HS data skew", skew_dev, cfg.skew_dev_percent_max, clk_stable));
                end
            end: dphy_data_getHSbit_legalBit
        join
        /*Now we are:
         * Legal transition - after next HS clock transition (where data is sampled on RX)
         * Illegal - right after change
         * */
    endtask: dphy_data_getHSbit
    
    //cool error handler
    task dphy_dataSM_error(int lane, txState_t txState);
        uvm_report_error("CSI_DPC_DATASM_ERR", $sformatf("[LANE %0d] %s: invalid transition (p/n: %0b %0b)!", lane, txState, vif.data_p[lane], vif.data_n[lane]));
        while ({vif.clk_p, vif.clk_n} != {1'b1, 1'b1})
            dphy_data_waitChange(lane); //error recovery
        data_state[lane] = TX_Stop;
    endtask: dphy_dataSM_error
    
    
    task dphy_dataSM (int lane);
        automatic realtime preparezero_sum = 0; //not needed?
        
        //wait for starting STOP state :)
        do
            dphy_data_waitChange(lane);
        while ({vif.data_p, vif.data_n} != {1'b1, 1'b1});
        //start SM
        forever
            case(data_state[lane])
                TX_Stop: begin
                    uvm_report_info("CSI_DPC_DATASM_LOG", $sformatf("[LANE %0d] DATA: TX_Stop", lane), UVM_HIGH);
                    dphy_data_waitChange(lane);
                    `TCHECK_MIN(t_lpx, data_stable[lane], lane)
                    case({vif.data_p[lane], vif.data_n[lane]})
                        {1'b0, 1'b1}: begin
                            data_state[lane] = TX_HS_Rqst;
                            if (!(clk_state inside { TX_HS_0, TX_HS_1 }))
                                uvm_report_error("CSI_DPC_DATASM_ERR", "TX_HS_Rqst on DATA lanes before HS CLK!");
                            else `TCHECK_MIN(t_clk_pre, $realtime - t_clk_pre_start, CLK)
                        end
                        {1'b1, 1'b0}: data_state[lane] = TX_LP_Rqst;
                        default: dphy_dataSM_error(lane, data_state[lane]);
                    endcase
                end
                TX_HS_Rqst: begin
                    uvm_report_info("CSI_DPC_DATASM_LOG", $sformatf("[LANE %0d] DATA: TX_HS_Rqst", lane), UVM_HIGH);
                    dphy_data_waitChange(lane);
                    `TCHECK_MIN(t_lpx, data_stable[lane], lane)
                    case({vif.data_p[lane], vif.data_n[lane]})
                        {1'b0, 1'b0}: data_state[lane] = TX_HS_Prpr;
                        default: dphy_dataSM_error(lane, data_state[lane]);
                    endcase
                end
                TX_HS_Prpr: begin
                    uvm_report_info("CSI_DPC_DATASM_LOG", $sformatf("[LANE %0d] DATA: TX_HS_Prpr", lane), UVM_HIGH);
                    dphy_data_waitChange(lane);
                    case({vif.data_p[lane], vif.data_n[lane]})
                        {1'b0, 1'b1}: begin
                            preparezero_sum = data_stable[lane];
                            `TCHECK_MINMAX(t_hs_prepare, data_stable[lane], lane)
                            data_state[lane] = TX_HS_Go;
                        end
                        default: dphy_dataSM_error(lane, data_state[lane]);
                    endcase
                end
                TX_HS_Go: begin
                    uvm_report_info("CSI_DPC_DATASM_LOG", $sformatf("[LANE %0d] DATA: TX_HS_Go", lane), UVM_HIGH);
                    while ({vif.data_p[lane], vif.data_n[lane]} == {1'b0, 1'b1}) //until 1 or error
                        dphy_data_getHSbit(lane);
                    case({vif.data_p[lane], vif.data_n[lane]})
                        {1'b1, 1'b0}: begin
                            preparezero_sum += data_stable[lane];
                            `TCHECK_MIN(t_hs_preparezero, preparezero_sum, lane)
                            data_state[lane] = TX_HS_Sync;
                        end
                        default: dphy_dataSM_error(lane, data_state[lane]);
                    endcase
                end
                TX_HS_Sync: begin
                    uvm_report_info("CSI_DPC_DATASM_LOG", $sformatf("[LANE %0d] DATA: TX_HS_Sync", lane), UVM_HIGH);
                    getSyncSeq(lane);
                    //check and select new state
                    if (syncSeqRec[lane] != sync_sequence) begin
                        uvm_report_error("CSI_DPC_DATASM_ERR", "Wrong sync sequence! Waiting for TX_Stop...");
                        while ({vif.clk_p, vif.clk_n} != {1'b1, 1'b1})
                            dphy_data_waitChange(lane); //error recovery
                        data_state[lane] = TX_Stop;
                    end
                    else
                        data_state[lane] = (syncSeqRec[lane][7]) ? TX_HS_1 : TX_HS_0;
                end
                TX_HS_0: begin
                    uvm_report_info("CSI_DPC_DATASM_LOG", $sformatf("[LANE %0d] DATA: TX_HS_0/Trail", lane), UVM_HIGH);
                    dphy_data_getHSbit(lane);
                    case({vif.data_p[lane], vif.data_n[lane]})
                        {1'b0, 1'b1}: /* remains in TX_HS_0*/;
                        {1'b1, 1'b0}: clk_state = TX_HS_1;
                        {1'b1, 1'b1}: begin
                            automatic bit allLinesLP = 1;
                            
                            `TCHECK_MIN(t_hs_trail, data_stable[lane], lane) //check trail length
                            `TCHECK_MAX(t_eot, data_stable[lane], lane)
                            
                            clk_state = TX_Stop; //do it HERE - it is checked in next lines
                            
                            //if all lanes in LP, set start point for clk-post check
                            for (int li = 0; li < cfg.lanes; ++li)
                                if (data_state[li] inside { TX_HS_Rqst, TX_HS_Prpr, TX_HS_Go, TX_HS_Sync, TX_HS_0, TX_HS_1 })
                                    allLinesLP = 0;
                            if (allLinesLP)
                                t_clk_post_start = $realtime;
                            
                            //check HS_Exit
                            fork
                                begin
                                    @(clk_state); //triggers on next state (signal) change
                                    `TCHECK_MIN(t_hs_exit, clk_stable, lane) //stable stop duration
                                end
                            join_none
                        end
                        default: dphy_dataSM_error(lane, data_state[lane]);
                    endcase
                end
                TX_HS_1: begin
                    uvm_report_info("CSI_DPC_DATASM_LOG", $sformatf("[LANE %0d] DATA: TX_HS_1/Trail", lane), UVM_HIGH);
                    dphy_data_getHSbit(lane);
                    case({vif.data_p[lane], vif.data_n[lane]})
                        {1'b0, 1'b1}: clk_state = TX_HS_0;
                        {1'b1, 1'b0}: /* remains in TX_HS_1*/;
                        {1'b1, 1'b1}: begin
                            automatic bit allLinesLP = 1;
                            
                            `TCHECK_MIN(t_hs_trail, data_stable[lane], lane) //check trail length
                            `TCHECK_MAX(t_eot, data_stable[lane], lane)
                            
                            clk_state = TX_Stop; //do it HERE - it is checked in next lines
                            
                            //if all lanes in LP, set start point for clk-post check
                            for (int li = 0; li < cfg.lanes; ++li)
                                if (data_state[li] inside { TX_HS_Rqst, TX_HS_Prpr, TX_HS_Go, TX_HS_Sync, TX_HS_0, TX_HS_1 })
                                    allLinesLP = 0;
                            if (allLinesLP)
                                t_clk_post_start = $realtime;
                            
                            //check HS_Exit
                            fork
                                begin
                                    @(clk_state); //triggers on next state (signal) change
                                    `TCHECK_MIN(t_hs_exit, clk_stable, lane) //stable stop duration
                                end
                            join_none
                        end
                        default: dphy_dataSM_error(lane, data_state[lane]);
                    endcase
                end
                TX_LP_Rqst: begin
                    uvm_report_info("CSI_DPC_DATASM_LOG", $sformatf("[LANE %0d] DATA: TX_LP_Rqst", lane), UVM_HIGH);
                    dphy_data_waitChange(lane);
                    `TCHECK_MIN(t_lpx, data_stable[lane], lane)
                    case({vif.data_p[lane], vif.data_n[lane]})
                        {1'b0, 1'b0}: data_state[lane] = TX_LP_Yield;
                        default: dphy_dataSM_error(lane, data_state[lane]);
                    endcase
                end
                TX_LP_Yield: begin
                    uvm_report_info("CSI_DPC_DATASM_LOG", $sformatf("[LANE %0d] DATA: TX_LP_Yield", lane), UVM_HIGH);
                    dphy_data_waitChange(lane);
                    `TCHECK_MIN(t_lpx, data_stable[lane], lane)
                    case({vif.data_p[lane], vif.data_n[lane]})
                        {1'b0, 1'b1}: data_state[lane] = TX_Esc_Rqst;
                        default: dphy_dataSM_error(lane, data_state[lane]);
                    endcase
                end
                TX_Esc_Rqst: begin
                    uvm_report_info("CSI_DPC_DATASM_LOG", $sformatf("[LANE %0d] DATA: TX_Esc_Rqst", lane), UVM_HIGH);
                    dphy_data_waitChange(lane);
                    `TCHECK_MIN(t_lpx, data_stable[lane], lane)
                    case({vif.data_p[lane], vif.data_n[lane]})
                        {1'b0, 1'b0}: data_state[lane] = TX_Esc_Go;
                        default: dphy_dataSM_error(lane, data_state[lane]);
                    endcase
                end
                TX_Esc_Go: begin
                    uvm_report_info("CSI_DPC_DATASM_LOG", $sformatf("[LANE %0d] DATA: TX_Esc_Go", lane), UVM_HIGH);
                    dphy_data_waitChange(lane);
                    `TCHECK_MIN(t_lpx, data_stable[lane], lane)
                    case({vif.data_p[lane], vif.data_n[lane]})
                        {1'b0, 1'b1},
                        {1'b1, 1'b0}: data_state[lane] = TX_Esc_Cmd;
                        default: dphy_dataSM_error(lane, data_state[lane]);
                    endcase
                end
                TX_Esc_Cmd: begin
                    uvm_report_info("CSI_DPC_DATASM_LOG", $sformatf("[LANE %0d] DATA: TX_Esc_Cmd", lane), UVM_HIGH);
                    getEscapeCmd(lane);
                    case(escapeCmd[lane])
                        esc_cmd_ULPS: data_state[lane] = TX_ULPS;
                        default: begin
                            if (cfg.strictEscapeCheck)
                                uvm_report_error("CSI_DPC_ESC_UNKNCMD", $sformatf("Unknown Escape Mode command received: %b! Waiting for TX_Stop...", escapeCmd[lane]));
                            else
                                uvm_report_warning("CSI_DPC_ESC_UNKNCMD", $sformatf("Received Escape Mode command is unsupported: %b! Waiting for TX_Stop...", escapeCmd[lane]));
                            //wait for LP11 (STOP), ignore others
                            while ({vif.clk_p, vif.clk_n} != {1'b1, 1'b1})
                                dphy_data_waitChange(lane); //error recovery
                            uvm_report_info("CSI_DPC_ESC_UNKNCMD", $sformatf("Got TX_Stop - recovered.", escapeCmd[lane]), UVM_LOW);
                        end
                    endcase
                end
                TX_ULPS: begin
                    uvm_report_info("CSI_DPC_DATASM_LOG", $sformatf("[LANE %0d] DATA: TX_ULPS", lane), UVM_HIGH);
                    @(vif.data_p[lane] or vif.data_n[lane]);
                    //no checks here
                    case({vif.data_p[lane], vif.data_n[lane]})
                        {1'b1, 1'b0}: data_state[lane] = TX_Mark;
                        default: dphy_dataSM_error(lane, data_state[lane]);
                    endcase
                end
                TX_Mark: begin
                    uvm_report_info("CSI_DPC_DATASM_LOG", $sformatf("[LANE %0d] DATA: TX_Mark", lane), UVM_HIGH);
                    @(vif.data_p[lane] or vif.data_n[lane]);
                    `TCHECK_MIN(t_wakeup, data_stable[lane], lane)
                    case({vif.data_p[lane], vif.data_n[lane]})
                        {1'b1, 1'b1}: data_state[lane] = TX_Stop;
                        default: dphy_dataSM_error(lane, data_state[lane]);
                    endcase
                end
                default: uvm_report_error("CSI_DPC_DATASM_ERR", "Invalid data SM state!");
            endcase
    endtask: dphy_dataSM
    
    task getSyncSeq(int lane);
        for (int bi = 1; bi < 8; ++bi) begin
            dphy_data_getHSbit(lane);
            case({vif.data_p[lane], vif.data_n[lane]})
                {1'b1, 1'b0},
                {1'b0, 1'b1}:
                    syncSeqRec[lane][bi] = (vif.data_p[lane] == 1) ? 1 : 0;
                default: dphy_dataSM_error(lane, data_state[lane]);
            endcase
        end
    endtask: getSyncSeq
    
    task getEscapeCmd(int lane);
        for (int i = 0; i < 8; ++i) begin
            //one-hot
            if (i > 0) begin //first time it's done in RX_Esc_Go
                dphy_data_waitChange(lane);
                `TCHECK_MIN(t_lpx, data_stable[lane], lane)
            end
            case({vif.data_p[lane], vif.data_n[lane]})
                {1'b0, 1'b1}: escapeCmd[lane][i] = 0;
                {1'b1, 1'b0}: escapeCmd[lane][i] = 1;
                default: dphy_dataSM_error(lane, data_state[lane]);
            endcase
            //space
            dphy_data_waitChange(lane);
            `TCHECK_MIN(t_lpx, data_stable[lane], lane)
            if ({vif.data_p[lane], vif.data_n[lane]} != {1'b0, 1'b0})
                uvm_report_error("CSI_DPC_DATASM_ERR", $sformatf("[LANE %0d] TX_Esc_Cmd: Space is not 00 (LP: %0d %0d)!", lane, vif.data_p[lane], vif.data_n[lane]));
        end
    endtask: getEscapeCmd

endclass : dphy_checker_c

`endif //__CSI_DPHY_CHECKER_SV__
