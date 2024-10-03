//
// File : csi_dpc_config.sv
//
// Created:
//          by HDL Designers Team
//          of Electronics Design Center "OhT"
//          www.overhitech.com
//
//
// File Description:
//
//% Конфигурация чекера DPHY
//

`ifndef __CSI_DPC_CONFIG_SV__
    `define __CSI_DPC_CONFIG_SV__

`define max2(v1, v2) ((v1) > (v2) ? (v1) : (v2))
`define min2(v1, v2) ((v1) > (v2) ? (v2) : (v1))

//----------------------------------------------------------------------------------------------------------------------
// CSI configuration
//----------------------------------------------------------------------------------------------------------------------

class dpc_config_c#(int CSI_LANES_MAX = 4) extends vivo_cfg_pkg::cfg_base_c;
    //parameters are a little useless, but good for checking X > Xmax
`timescale 1ns/1ps

    //------------------------------------------------------------------------------------------------------------------
    // Parameters
    //------------------------------------------------------------------------------------------------------------------

    bit enabled = 0;
    int lanes = 4;
    bit strictEscapeCheck = 1; //if 0, unknown command will trigger wait of LP11, without errors
    bit strictTuiCheck = 1; //if 1, UI period will be checked with 0.15 possible deviation

    //------------------------------------------------------------------------------------------------------------------
    // Timings (ns)
    //------------------------------------------------------------------------------------------------------------------

    int    data_rate        = 1000; //Mbps
    realtime t_ui        = 1us / data_rate;

    //------------------------------------------------------------------------------------------------------------------
    // Timing restrictions
    //------------------------------------------------------------------------------------------------------------------

    realtime t_ui_max                    = 12.5ns;

    //TX
    int         skew_dev_percent_max    = 15;

    realtime    t_lpx_min                = 50ns;
    realtime    t_hs_prepare_min        = 40ns    + 4 * t_ui;
    realtime    t_hs_prepare_max        = 85ns    + 6 * t_ui;
    realtime    t_hs_preparezero_min    = 145ns    + 10* t_ui;
    realtime    t_hs_trail_min            = `max2(8 * t_ui, 60ns + 4 * t_ui); //n==1 in timings: no reverse mode?

    realtime    t_eot_max                = 105ns    + 12* t_ui;
    realtime    t_hs_exit_min            = 100ns;
    realtime    t_wakeup_min            = 1ms;

    realtime    t_clk_prepare_min        = 38ns;
    realtime    t_clk_prepare_max        = 95ns;
    realtime    t_clk_preparezero_min    = 300ns;
    realtime    t_clk_pre_min            =           8 * t_ui;
    realtime    t_clk_post_min            = 60ns    + 52* t_ui;
    realtime    t_clk_trail_min            = 60ns;

    //------------------------------------------------------------------------------------------------------------------
    // UVM automation macros
    //------------------------------------------------------------------------------------------------------------------

    `uvm_object_param_utils_begin(csi_pkg::dpc_config_c#(CSI_LANES_MAX))
        `uvm_field_int    (enabled,            UVM_ALL_ON | UVM_BIN)
        `uvm_field_int    (lanes,                UVM_ALL_ON | UVM_DEC)
        `uvm_field_int    (strictEscapeCheck,    UVM_ALL_ON | UVM_BIN)
        `uvm_field_int    (strictTuiCheck,        UVM_ALL_ON | UVM_BIN)
        `uvm_field_int    (data_rate,            UVM_ALL_ON | UVM_DEC)
        `uvm_field_int    (skew_dev_percent_max,UVM_ALL_ON | UVM_DEC)
    `uvm_object_utils_end

    //------------------------------------------------------------------------------------------------------------------
    // constructor
    //------------------------------------------------------------------------------------------------------------------

    function new (string name = "csi_config");
        super.new(name);
    endfunction : new


    //------------------------------------------------------------------------------------------------------------------
    // Update configuration function
    //------------------------------------------------------------------------------------------------------------------

    //Returns 0 if current config is good, 1 if there's any errors
    function int check_cfg();
        if (lanes > CSI_LANES_MAX) begin
            uvm_report_error("CSIDPCCFGCHECK", $sformatf("Lane number (%d) is larger than MAX (parameter): %d!", lanes, CSI_LANES_MAX));
            return 1;
        end

        //Timing - both
        if (t_ui > t_ui_max)
            uvm_report_warning("CSICFGCHECK", $sformatf("Time T_UI (%0d) does not correspond to MIPI D-PHY specification", t_ui));
        return 0;
    endfunction: check_cfg


     function void cfg_update();
        //recalculate min-max values based on t_ui
        if (data_rate <= 0)
            uvm_report_fatal("CSIDPCCFGCHECK", $sformatf("Invalid data rate: %d!", data_rate));

        t_ui                    = 1us / data_rate;
        //TX
        skew_dev_percent_max    =           0.15 * t_ui;
        t_hs_prepare_min        = 40ns    + 4 * t_ui;
        t_hs_prepare_max        = 85ns    + 6 * t_ui;
        t_hs_preparezero_min    = 145ns    + 10* t_ui;
        t_hs_trail_min            = `max2(8 * t_ui, 60ns + 4 * t_ui); //n==1 in timings: no reverse mode?
        t_eot_max                = 105ns    + 12* t_ui;
        t_clk_pre_min            =           8 * t_ui;
        t_clk_post_min            = 60ns    + 52* t_ui;
        //check other params
        if (check_cfg())
            uvm_report_fatal("CSIDPCCFGERR", "Configuration check didn't passed.");
    endfunction: cfg_update

    //------------------------------------------------------------------------------------------------------------------
    // vd_mode2params function
    //------------------------------------------------------------------------------------------------------------------

    function vivo_cfg_pkg::cfg_params_t vd_mode2params(vivo_cfg_pkg::cfg_vd_mode_t vd_mode);
        //do nothing
        vd_mode2params = new[0];
    endfunction : vd_mode2params

    //------------------------------------------------------------------------------------------------------------------
    // get new frame_item
    //------------------------------------------------------------------------------------------------------------------

    function vivo_core_pkg::frame_item_c get_frame_item(string name = "dvi_d_frame_item", bit field = 0);
        uvm_report_fatal("CSIDPCCFGERR", $sformatf("Attempt to get frame item from checker."));
        return null;
    endfunction

endclass : dpc_config_c

`endif // __CSI_DPC_CONFIG_SV__
