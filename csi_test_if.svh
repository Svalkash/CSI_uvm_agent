//
// File : csi_test_if.svh
//
// Created:
//          by HDL Designers Team
//          of Electronics Design Center "OhT"
//          www.overhitech.com
//
//
// File Description:
//
//% Интерфейс CSI TEST (for Lattice IP connecting)
//

`ifndef __CSI_TEST_IF_SVH__
    `define __CSI_TEST_IF_SVH__    
    
//----------------------------------------------------------------------------------------------------------------------
// CSI PPI-TX interface
//----------------------------------------------------------------------------------------------------------------------

interface oht_vivo_csi_test_if (input clk_lp_ctrl_i);

    //------------------------------------------------------------------------------------------------------------------
    // Pin declaration
    //------------------------------------------------------------------------------------------------------------------
    

        //logic ports
        logic                                   clk_byte_fr_i;
        //logic                                   clk_lp_ctrl_i;
        logic                                   reset_byte_fr_n_i;
        logic                                   reset_byte_n_i;
        logic                                   reset_lp_n_i;
        logic                                   reset_n_i;
        logic                                   pll_lock_i;
        logic                                   pd_dphy_i;
        
        // output clocks
        logic                             clk_byte_o;
        logic                             clk_byte_hs_o;

        ///// outputs to fabric. for low power signalling
        logic                             cd_d0_o;
        logic                             lp_d0_rx_p_o;
        logic                             lp_d0_rx_n_o;
        logic                             lp_d1_rx_p_o;
        logic                             lp_d1_rx_n_o;
        logic                             lp_d2_rx_p_o;
        logic                             lp_d2_rx_n_o;
        logic                             lp_d3_rx_p_o;
        logic                             lp_d3_rx_n_o;

        // start of parser_on -------
        logic [4*8-1:0]          bd_o;
        logic                                 payload_en_o;
        logic [4*8-1:0] payload_o;

        logic                             sp_en_o;
        logic                             lp_en_o;
        logic                             lp_av_en_o;
        logic [5:0]                       dt_o;
        logic [1:0]                       vc_o;
        logic [15:0]                      wc_o;
        logic [7:0]                       ecc_o;

        logic [5:0]                       ref_dt_i;

        // debug/misc signals
        logic                             hs_d_en_o;
        logic                             hs_sync_o;
        logic                             term_clk_en_o;
        logic [1:0]                       lp_hs_state_clk_o;
        logic [1:0]                       lp_hs_state_d_o;
    
        
        assign clk_byte_fr_i = clk_byte_hs_o;
    
        clocking monitor_cb @(posedge clk_byte_hs_o);
            default input #1step;
            input sp_en_o, lp_en_o, lp_av_en_o, dt_o, vc_o, wc_o, ecc_o, bd_o, payload_en_o, payload_o;
            output ref_dt_i;
        endclocking
        
        modport monitor_mp ( clocking monitor_cb,
                output reset_byte_fr_n_i,
                output reset_byte_n_i,
                output reset_lp_n_i,
                output reset_n_i,
                output pd_dphy_i,
                output pll_lock_i,
                output ref_dt_i);
        
endinterface

`endif // __CSI_TEST_IF_SVH__