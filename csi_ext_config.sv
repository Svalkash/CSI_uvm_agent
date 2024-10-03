//
// File : csi_ext_config.sv
//
// Created:
//          by HDL Designers Team
//          of Electronics Design Center "OhT"
//          www.overhitech.com
//
//
// File Description:
//
//% Конфигурация внешнего агента CSI интерфейса
//

`ifndef __CSI_EXT_CONFIG_SV__
    `define __CSI_EXT_CONFIG_SV__
    
    `define max2(v1, v2) ((v1) > (v2) ? (v1) : (v2))
    `define min2(v1, v2) ((v1) > (v2) ? (v2) : (v1))

    //----------------------------------------------------------------------------------------------------------------------
    // CSI configuration
    //----------------------------------------------------------------------------------------------------------------------

    class ext_config_c extends uvm_object;

        //------------------------------------------------------------------------------------------------------------------
        // Parameters
        //------------------------------------------------------------------------------------------------------------------

        uvm_active_passive_enum    is_active;
        bit enabled = 0;

        int lanes_used = 4;
        int vchan_used = 4; //virtual channels

        //------------------------------------------------------------------------------------------------------------------
        // Driver-specific
        //------------------------------------------------------------------------------------------------------------------

        bit continuous_clock = 1; //if 1, clock will not stop between data packets
    
        bit ulps_after_frame = 0;
        bit en_clk_ulps = 1; //if on, clk will go to ULPS too
    
        //------------------------------------------------------------------------------------------------------------------
        // Monitor-specific
        //------------------------------------------------------------------------------------------------------------------
    
        bit strictEscapeCheck = 1; //if 0, unknown command will trigger wait of LP11, without errors

        //------------------------------------------------------------------------------------------------------------------
        // Timings (ns)
        //------------------------------------------------------------------------------------------------------------------
    
        int    data_rate        = 1000; //Mbps
        realtime t_ui        = 1us / data_rate;
    
        //TX
        const int t_data_delay = 20; //all provided data and clock gate is delayed for 20 UI (2.5 clocks). Must delay other signals for the same
    
        int    t_lpx            = 60;
        int    t_hs_prepare    = 65;
        int    t_hs_zero        = 100;
        int    t_hs_trail        = 80;
     
        //int    t_eot            = 90;
        int    t_hs_exit        = 120;
        int    t_wakeup        = 1_100_000;
        int    t_ulps            = 2_000_000; //non-standard, determines ULPS duration 
    
        int    t_clk_prepare    = 70;
        int    t_clk_zero        = 260;
        int    t_clk_pre        = 16;
        int    t_clk_post        = 140;
        int    t_clk_trail        = 80;
    
        //RX
        int    t_d_term_en        = 20;
        int    t_hs_settle        = 110;
        int    t_hs_skip        = 45;
    
        int    t_clk_settle    = 200;
        int    t_clk_term_en    = 30;
        int    t_clk_miss        = 40;

        //------------------------------------------------------------------------------------------------------------------
        // Timing restrictions
        //------------------------------------------------------------------------------------------------------------------
    
        realtime t_ui_max                    = 12.5ns;
    
        //TX
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
    
        //RX
        realtime    t_d_term_en_max            = 35ns    + 4 * t_ui;
        realtime    t_hs_settle_min            = 85ns    + 6 * t_ui;
        realtime    t_hs_settle_max            = 145ns    + 10* t_ui; 
        realtime    t_hs_skip_min            = 40ns;
        realtime    t_hs_skip_max            = 50ns    + 4 * t_ui;
    
        realtime    t_clk_settle_min        = 95ns;
        realtime    t_clk_settle_max        = 350ns;
        realtime    t_clk_term_en_max        = 38ns;
        realtime    t_clk_miss_max            = 60ns;
    
        //------------------------------------------------------------------------------------------------------------------
        // UVM automation macros
        //------------------------------------------------------------------------------------------------------------------

        `uvm_object_param_utils_begin(csi_pkg::ext_config_c)
        `uvm_field_enum (uvm_active_passive_enum, is_active, UVM_ALL_ON)
        `uvm_field_int     (enabled,             UVM_ALL_ON | UVM_DEC)
        `uvm_field_int    (vchan_used,        UVM_ALL_ON | UVM_DEC)
        `uvm_field_int    (lanes_used,        UVM_ALL_ON | UVM_DEC)
        `uvm_field_int    (data_rate,            UVM_ALL_ON | UVM_DEC)
        //driver
        `uvm_field_int    (continuous_clock,    UVM_ALL_ON | UVM_BIN)
        `uvm_field_int    (ulps_after_frame,    UVM_ALL_ON | UVM_BIN)
        `uvm_field_int    (en_clk_ulps,        UVM_ALL_ON | UVM_BIN)
        `uvm_field_int    (t_lpx,                UVM_ALL_ON | UVM_DEC)
        `uvm_field_int    (t_hs_prepare,        UVM_ALL_ON | UVM_DEC)
        `uvm_field_int    (t_hs_zero,            UVM_ALL_ON | UVM_DEC)
        `uvm_field_int    (t_hs_trail,        UVM_ALL_ON | UVM_DEC)
        `uvm_field_int    (t_hs_exit,            UVM_ALL_ON | UVM_DEC)
        `uvm_field_int    (t_wakeup,            UVM_ALL_ON | UVM_DEC)
        `uvm_field_int    (t_clk_prepare,        UVM_ALL_ON | UVM_DEC)
        `uvm_field_int    (t_clk_zero,        UVM_ALL_ON | UVM_DEC)
        `uvm_field_int    (t_clk_pre,            UVM_ALL_ON | UVM_DEC)
        `uvm_field_int    (t_clk_post,        UVM_ALL_ON | UVM_DEC)
        `uvm_field_int    (t_clk_trail,        UVM_ALL_ON | UVM_DEC)
        `uvm_field_int    (t_ulps,            UVM_ALL_ON | UVM_DEC)
        //monitor
        `uvm_field_int    (strictEscapeCheck,    UVM_ALL_ON | UVM_BIN)
        `uvm_field_int    (t_d_term_en,        UVM_ALL_ON | UVM_DEC)
        `uvm_field_int    (t_hs_settle,        UVM_ALL_ON | UVM_DEC)
        `uvm_field_int    (t_hs_skip,            UVM_ALL_ON | UVM_DEC)
        `uvm_field_int    (t_clk_settle,        UVM_ALL_ON | UVM_DEC)
        `uvm_field_int    (t_clk_term_en,        UVM_ALL_ON | UVM_DEC)
        `uvm_field_int    (t_clk_miss,        UVM_ALL_ON | UVM_DEC)
        `uvm_object_utils_end

        //------------------------------------------------------------------------------------------------------------------
        // constructor
        //------------------------------------------------------------------------------------------------------------------

        function new (string name = "csi_ext_config");
            super.new(name);
        endfunction : new

    
        //------------------------------------------------------------------------------------------------------------------
        // Update configuration function
        //------------------------------------------------------------------------------------------------------------------
    
        //Returns 0 if current config is good, 1 if there's any errors
        function int check_cfg();        
            //Timing - both
            if (t_ui > t_ui_max)
                uvm_report_warning("CSICFGCHECK", $sformatf("Time T_UI (%0d) does not correspond to MIPI D-PHY specification", t_ui));
        
            //Timings - driver
            if (is_active == UVM_ACTIVE) begin
                if (t_lpx < t_lpx_min)
                    uvm_report_warning("CSICFGCHECK", $sformatf("Time T_LPX (%0d) does not correspond to MIPI D-PHY specification", t_lpx));
                //if (t_eot > t_eot_max)
                //    uvm_report_warning("CSICFGCHECK", $sformatf("Time T_EOT (%0d) does not correspond to MIPI D-PHY specification", t_eot));
                if (t_hs_trail > t_eot_max)
                    uvm_report_warning("CSICFGCHECK", $sformatf("Time T_EOT (T_HS_TRAIL) (%0d) does not correspond to MIPI D-PHY specification", t_hs_trail));
                if (t_clk_trail > t_eot_max)
                    uvm_report_warning("CSICFGCHECK", $sformatf("Time T_EOT (T_CLK_TRAIL) (%0d) does not correspond to MIPI D-PHY specification", t_clk_trail));
                if (t_hs_exit < t_hs_exit_min)
                    uvm_report_warning("CSICFGCHECK", $sformatf("Time T_HS-exit (%0d) does not correspond to MIPI D-PHY specification", t_hs_exit));
                if (t_wakeup < t_wakeup_min)
                    uvm_report_warning("CSICFGCHECK", $sformatf("Time T_WAKEUP (%0d) does not correspond to MIPI D-PHY specification", t_wakeup));
        
                if (t_hs_prepare < t_hs_prepare_min || t_hs_prepare > t_hs_prepare_max)
                    uvm_report_warning("CSICFGCHECK", $sformatf("Time T_HS-prepare (%0d) does not correspond to MIPI D-PHY specification", t_hs_prepare));
                if (t_hs_prepare + t_hs_zero < t_hs_preparezero_min)
                    uvm_report_warning("CSICFGCHECK", $sformatf("Time [T_HS-prepare + T_HS-zero] (%0d+%0d) does not correspond to MIPI D-PHY specification", t_hs_prepare, t_hs_zero));
                if (t_hs_trail < t_hs_trail_min)
                    uvm_report_warning("CSICFGCHECK", $sformatf("Time T_HS-trail (%0d) does not correspond to MIPI D-PHY specification", t_hs_trail));
        
                if (t_clk_prepare < t_clk_prepare_min || t_clk_prepare > t_clk_prepare_max)
                    uvm_report_warning("CSICFGCHECK", $sformatf("Time T_CLK-prepare (%0d) does not correspond to MIPI D-PHY specification", t_clk_prepare));
                if (t_clk_prepare + t_clk_zero < t_clk_preparezero_min)
                    uvm_report_warning("CSICFGCHECK", $sformatf("Time [T_CLK-prepare + T_CLK-zero] (%0d+%0d) does not correspond to MIPI D-PHY specification", t_clk_prepare, t_clk_zero));
                if (t_clk_pre < t_clk_pre_min)
                    uvm_report_warning("CSICFGCHECK", $sformatf("Time T_CLK-pre (%0d) does not correspond to MIPI D-PHY specification", t_clk_pre));
                if (t_clk_post < t_clk_post_min)
                    uvm_report_warning("CSICFGCHECK", $sformatf("Time T_CLK-post (%0d) does not correspond to MIPI D-PHY specification", t_clk_post));
                if (t_clk_trail < t_clk_trail_min)
                    uvm_report_warning("CSICFGCHECK", $sformatf("Time T_CLK-trail (%0d) does not correspond to MIPI D-PHY specification", t_clk_trail));
            end
        
            //Timings - monitor
            if (is_active == UVM_PASSIVE) begin            
                if (t_d_term_en > t_d_term_en_max)
                    uvm_report_warning("CSICFGCHECK", $sformatf("Time T_D-term-en (%0d) does not correspond to MIPI D-PHY specification", t_d_term_en));
                if (t_hs_settle < t_hs_settle_min || t_hs_settle > t_hs_settle_max)
                    uvm_report_warning("CSICFGCHECK", $sformatf("Time T_HS-settle (%0d) does not correspond to MIPI D-PHY specification", t_hs_settle));
                if (t_hs_skip < t_hs_skip_min || t_hs_skip > t_hs_skip_max)
                    uvm_report_warning("CSICFGCHECK", $sformatf("Time T_HS-skip (%0d) does not correspond to MIPI D-PHY specification", t_hs_skip));
            
                if (t_clk_term_en > t_clk_term_en_max)
                    uvm_report_warning("CSICFGCHECK", $sformatf("Time T_CLK-term-en (%0d) does not correspond to MIPI D-PHY specification", t_d_term_en));
                if (t_clk_settle < t_clk_settle_min || t_clk_settle > t_clk_settle_max)
                    uvm_report_warning("CSICFGCHECK", $sformatf("Time T_CLK-settle (%0d) does not correspond to MIPI D-PHY specification", t_clk_settle));
                if (t_clk_miss > t_clk_miss_max)
                    uvm_report_warning("CSICFGCHECK", $sformatf("Time T_CLK-miss (%0d) does not correspond to MIPI D-PHY specification", t_clk_miss));
            end
            return 0;
        endfunction: check_cfg
    
    virtual function void cfg_update();
        //recalculate min-max values based on t_ui
        if (data_rate <= 0)
            uvm_report_fatal("CSICFGCHECK", $sformatf("Invalid data rate: %d!", data_rate));
        
        t_ui                    = 1us / data_rate;
        //TX
        t_hs_prepare_min        = 40ns    + 4 * t_ui;
        t_hs_prepare_max        = 85ns    + 6 * t_ui;
        t_hs_preparezero_min    = 145ns    + 10* t_ui;
        t_hs_trail_min            = `max2(8 * t_ui, 60ns + 4 * t_ui); //n==1 in timings: no reverse mode?
        t_eot_max                = 105ns    + 12* t_ui;
        t_clk_pre_min            =           8 * t_ui;
        t_clk_post_min            = 60ns    + 52* t_ui;
        //RX
        t_d_term_en_max            = 35ns    + 4 * t_ui;
        t_hs_settle_min            = 85ns    + 6 * t_ui;
        t_hs_settle_max            = 145ns    + 10* t_ui; 
        t_hs_skip_max            = 50ns    + 4 * t_ui;
        //check other params
        if (check_cfg())
            uvm_report_fatal("CSICFGERR", "Configuration check didn't passed.");
    endfunction: cfg_update
    
    endclass : ext_config_c

`endif // __CSI_EXT_CONFIG_SV__
