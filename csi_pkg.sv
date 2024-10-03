//
// File : csi_pkg.sv
//
// Created:
//          by HDL Designers Team
//          of Electronics Design Center "OhT"
//          www.overhitech.com
//
//
// File Description:
//
//% Package верификационных компонентов CSI-2 интерфейса
//

`ifndef __CSI_PKG_SV__
    `define __CSI_PKG_SV__

package csi_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    `include "csi_types.svh"
    `include "csi_packet_item.sv"
    `include "csi_config.sv"
    `include "csi_driver.sv"
    `include "csi_packet_seq_lib.sv"
    `include "csi_monitor.sv"
    
    `include "csi_ext_config.sv"
    `include "csi_mltran_item.sv"
    `include "csi_mix_sqr.sv"
    `include "csi_mix_seq_lib.sv"
    `include "csi_mltran_sqr.sv"
    `include "csi_mltran_seq_lib.sv"
    `include "csi_ext_driver.sv"
    `include "csi_ext_monitor.sv"
    `include "csi_mltran2packet.sv"
    `include "csi_packet_sorter.sv"
    `include "csi_ext_agent.sv"
    
    `include "csi_dpc_config.sv"
    `include "csi_dphy_checker.sv"
    
    `include "csi_test_monitor.sv"
    `include "csi_test_agent.sv"

    function string version();
    return {"\n", "CSI_VC_VERSION: ", "3.6",
            "\n", "CSI_VC_DATE: "   , "2021-05-27"};
    endfunction

endpackage : csi_pkg

`endif // __CSI_PKG_SV__
