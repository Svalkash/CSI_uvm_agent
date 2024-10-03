//
// File : csi_ppi_if.svh
//
// Created:
//          by HDL Designers Team
//          of Electronics Design Center "OhT"
//          www.overhitech.com
//
//
// File Description:
//
//% Интерфейс CSi-PPI
//

`ifndef __CSI_PPI_IF_SVH__
    `define __CSI_PPI_IF_SVH__

`include "vivo_env_structural_defines.svh"    
    

`define LANE_TX(NUM) \
        logic d``NUM``_txlpn; \
        logic d``NUM``_txlpp; \
        assign d``NUM``_txlpn     = d_txlpn[NUM]; \
        assign d``NUM``_txlpp     = d_txlpp[NUM];
    
    
//----------------------------------------------------------------------------------------------------------------------
// CSI PPI-TX interface
//----------------------------------------------------------------------------------------------------------------------

interface oht_vivo_csi_ppi_if#(int LANE_N = `OHT_VIVO_CSI_LANES_MAX) (input refclk);

    //------------------------------------------------------------------------------------------------------------------
    // Pin declaration
    //------------------------------------------------------------------------------------------------------------------
    
    logic usrstdby;
    
    //TX
    logic                 clk_txhsen;
    logic                 clk_txhsgate;
    logic                 clk_txlpen;
    logic                 clk_txlpn;
    logic                 clk_txlpp;
    logic                 pd_pll;
    logic[LANE_N*8-1:0]    txdata;
    logic                 lock;
    logic                 txhsbyteclk;
    
    //RX
    logic                 clk_rxhsen;
    logic                 clk_rxlpen;
    logic                 clk_cd;
    logic                 clk_rxlpn;
    logic                 clk_rxlpp;
    logic                 clkhsbyte;
    logic                 rxhsbyteclk;
    logic[LANE_N*8-1:0] q;
    
    //single signals - TX
    logic                 d0_txhsen;
    logic                 d0_txlpen;
    
    //signal groups for lanes - TX
    logic                 d_txlpn     [`OHT_VIVO_CSI_LANES_MAX-1:0];
    logic                 d_txlpp        [`OHT_VIVO_CSI_LANES_MAX-1:0];
    
    //single signals - RX
    logic                 d0_hsdeseren;
    logic                 d0_rxhsen;
    logic                 d0_rxlpen;
    logic                 d0_cd;
    logic                 d0_rxlpn;
    logic                 d0_rxlpp;
    
    //------------------------------------------------------------------------------------------------------------------
    // Lane-specific signals and assignments
    //------------------------------------------------------------------------------------------------------------------
    
    `LANE_TX(0)
    
    generate if (`OHT_VIVO_CSI_LANES_MAX > 1)
            `LANE_TX(1)
    endgenerate
    
    generate if (`OHT_VIVO_CSI_LANES_MAX > 2)
            `LANE_TX(2)
    endgenerate
    
    generate if (`OHT_VIVO_CSI_LANES_MAX > 3)
            `LANE_TX(3)
    endgenerate
    
    //------------------------------------------------------------------------------------------------------------------
    // Modports
    //------------------------------------------------------------------------------------------------------------------

    modport driver_mp (
            output    clk_txlpen,
            output    clk_txlpp,
            output    clk_txlpn,
            
            output    clk_txhsen,
            input    txhsbyteclk,
            output    clk_txhsgate, //sync to txhsbyteclk
            
            output     d0_txhsen,
            output     d0_txlpen,
            output     d_txlpp,
            output     d_txlpn,
            
            output    txdata, //sync to txhsbyteclk
            
            output     usrstdby,
            output     pd_pll,
            
            input     refclk,
            input     lock);
    
    modport monitor_mp (
            input     clkhsbyte,
            
            output    clk_rxlpen,
            input     clk_rxlpp,
            input     clk_rxlpn,
            
            output    d0_hsdeseren, //MIXED CLOCKING!!
            output     clk_rxhsen,
            input     rxhsbyteclk,
            
            output     d0_rxlpen,
            input     d0_rxlpn,
            input     d0_rxlpp,
            
            output     d0_rxhsen,
            input     q, //sync to rxhsbyteclk
            
            input     clk_cd,
            input    d0_cd,
            
            output     usrstdby);
    
endinterface

`endif // __CSI_PPI_IF_SVH__