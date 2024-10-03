//
// File : dvi_d_driver.sv
//
// Created:
//          by HDL Designers Team
//          of Electronics Design Center "OhT"
//          www.overhitech.com
//
//
// File Description:
//
//% Структуры данных для CSI-2
//

`ifndef __CSI_TYPES_SVH__
    `define __CSI_TYPES_SVH__
    
//driver clock state
typedef enum { CLK_ULPS, CLK_LP, CLK_HS } clk_state_t;

//check frame/line start-end
typedef enum { FL_NO, FL_FSLE, FL_LS, FL_DATA } cFLSE_state_t;
    
// Monitor state
typedef enum { RX_Stop, RX_HS_Rqst, RX_HS_Prpr, RX_HS_Term, RX_HS_Run, RX_HS_Clk, RX_HS_End,
    RX_LP_Rqst, RX_LP_Yield, RX_Esc_Rqst, RX_Esc_Go, RX_Esc_Cmd, RX_Wait,
    RX_ULPS_Rqst, RX_ULPS, RX_ULPS_Exit} rxState_t;

// Driver (checker) state
typedef enum { TX_Stop, TX_HS_Rqst, TX_HS_Prpr, TX_HS_Go, TX_HS_Sync, TX_HS_0, TX_HS_1,
    TX_LP_Rqst, TX_LP_Yield, TX_Esc_Rqst, TX_Esc_Go, TX_Esc_Cmd, TX_Mark,
    TX_ULPS_Rqst, TX_ULPS, TX_ULPS_Exit} txState_t;
    
typedef enum bit [5:0] {
    SP_frameStart            = 6'h00,
    SP_frameEnd                = 6'h01,
    SP_lineStart            = 6'h02,
    SP_lineEnd                = 6'h03,
    LP_null                    = 6'h10,
    LP_blank                = 6'h11,
    LP_embedded                = 6'h12,
    LP_dataYUV420_8            = 6'h18,
    LP_dataYUV420_10        = 6'h19,
    LP_dataLegacyYUV420_8    = 6'h1A,
    LP_dataYUV420_8_CSRS    = 6'h1C,
    LP_dataYUV420_10_CSRS    = 6'h1D,
    LP_dataYUV422_8            = 6'h1E,
    LP_dataYUV422_10        = 6'h1F,
    LP_dataRGB444            = 6'h20,
    LP_dataRGB555            = 6'h21,
    LP_dataRGB565            = 6'h22,
    LP_dataRGB666            = 6'h23,
    LP_dataRGB888            = 6'h24,
    LP_dataRAW6                = 6'h28,
    LP_dataRAW7                = 6'h29,
    LP_dataRAW8                = 6'h2A,
    LP_dataRAW10            = 6'h2B,
    LP_dataRAW12            = 6'h2C,
    LP_dataRAW14            = 6'h2D,
    P_invalid                = 6'h3F
} packetType_t;
                         
typedef struct {
    vivo_core_pkg::col_scheme_t        col_scheme;
    vivo_core_pkg::chr_subsamp_t    chr_subsampling;
    vivo_core_pkg::rgb_subpxl_t        rgb_subpxl_scheme;
    int                             dwidth[3];
} frameFormat_t;
    
    
const frameFormat_t frameFormats [packetType_t] = '{
    
    LP_dataYUV420_8: '{
        col_scheme             : vivo_core_pkg::scheme_YUV,
        chr_subsampling        : vivo_core_pkg::subsamp_420,
        rgb_subpxl_scheme    : vivo_core_pkg::subpxl_UNDEFINED,
        dwidth                : '{ 8, 8, 8 }
    },
        
    LP_dataYUV420_10: '{
        col_scheme             : vivo_core_pkg::scheme_YUV,
        chr_subsampling        : vivo_core_pkg::subsamp_420,
        rgb_subpxl_scheme    : vivo_core_pkg::subpxl_UNDEFINED,
        dwidth                : '{ 10, 10, 10 }
    },
    
    LP_dataLegacyYUV420_8: '{
        col_scheme             : vivo_core_pkg::scheme_YUV,
        chr_subsampling        : vivo_core_pkg::subsamp_420,
        rgb_subpxl_scheme    : vivo_core_pkg::subpxl_UNDEFINED,
        dwidth                : '{ 8, 8, 8 }
    },
    
    LP_dataYUV420_8_CSRS: '{
        col_scheme             : vivo_core_pkg::scheme_YUV,
        chr_subsampling        : vivo_core_pkg::subsamp_420,
        rgb_subpxl_scheme    : vivo_core_pkg::subpxl_UNDEFINED,
        dwidth                : '{ 8, 8, 8 }
    },
    
    LP_dataYUV420_10_CSRS: '{
        col_scheme             : vivo_core_pkg::scheme_YUV,
        chr_subsampling        : vivo_core_pkg::subsamp_420,
        rgb_subpxl_scheme    : vivo_core_pkg::subpxl_UNDEFINED,
        dwidth                : '{ 10, 10, 10 }
    },
    
    LP_dataYUV422_8: '{
        col_scheme             : vivo_core_pkg::scheme_YUV,
        chr_subsampling        : vivo_core_pkg::subsamp_422,
        rgb_subpxl_scheme    : vivo_core_pkg::subpxl_UNDEFINED,
        dwidth                : '{ 8, 8, 8 }
    },
        
    LP_dataYUV422_10: '{
        col_scheme             : vivo_core_pkg::scheme_YUV,
        chr_subsampling        : vivo_core_pkg::subsamp_422,
        rgb_subpxl_scheme    : vivo_core_pkg::subpxl_UNDEFINED,
        dwidth                : '{ 10, 10, 10 }
    },

    LP_dataRGB444: '{
        col_scheme             : vivo_core_pkg::scheme_RGB,
        chr_subsampling        : vivo_core_pkg::subsamp_UNDEFINED,
        rgb_subpxl_scheme    : vivo_core_pkg::subpxl_FULL,
        dwidth                : '{ 4, 4, 4 }
    },
    
    LP_dataRGB555: '{
        col_scheme             : vivo_core_pkg::scheme_RGB,
        chr_subsampling        : vivo_core_pkg::subsamp_UNDEFINED,
        rgb_subpxl_scheme    : vivo_core_pkg::subpxl_FULL,
        dwidth                : '{ 5, 5, 5 }
    },
    
    LP_dataRGB565: '{
        col_scheme             : vivo_core_pkg::scheme_RGB,
        chr_subsampling        : vivo_core_pkg::subsamp_UNDEFINED,
        rgb_subpxl_scheme    : vivo_core_pkg::subpxl_FULL,
        dwidth                : '{ 5, 6, 5 }
    },

    LP_dataRGB666: '{
        col_scheme             : vivo_core_pkg::scheme_RGB,
        chr_subsampling        : vivo_core_pkg::subsamp_UNDEFINED,
        rgb_subpxl_scheme    : vivo_core_pkg::subpxl_FULL,
        dwidth                : '{ 6, 6, 6 }
    },
    
    LP_dataRGB888: '{
        col_scheme             : vivo_core_pkg::scheme_RGB,
        chr_subsampling        : vivo_core_pkg::subsamp_UNDEFINED,
        rgb_subpxl_scheme    : vivo_core_pkg::subpxl_FULL,
        dwidth                : '{ 8, 8, 8 }
    },
    
    LP_dataRAW6: '{
        col_scheme             : vivo_core_pkg::scheme_BW,
        chr_subsampling        : vivo_core_pkg::subsamp_UNDEFINED,
        rgb_subpxl_scheme    : vivo_core_pkg::subpxl_UNDEFINED,
        dwidth                : '{ 6, 0, 0 }
    },
    
    LP_dataRAW7: '{
        col_scheme             : vivo_core_pkg::scheme_BW,
        chr_subsampling        : vivo_core_pkg::subsamp_UNDEFINED,
        rgb_subpxl_scheme    : vivo_core_pkg::subpxl_UNDEFINED,
        dwidth                : '{ 7, 0, 0 }
    },
    
    LP_dataRAW8: '{
        col_scheme             : vivo_core_pkg::scheme_BW,
        chr_subsampling        : vivo_core_pkg::subsamp_UNDEFINED,
        rgb_subpxl_scheme    : vivo_core_pkg::subpxl_UNDEFINED,
        dwidth                : '{ 8, 0, 0 }
    },
    
    LP_dataRAW10: '{
        col_scheme             : vivo_core_pkg::scheme_BW,
        chr_subsampling        : vivo_core_pkg::subsamp_UNDEFINED,
        rgb_subpxl_scheme    : vivo_core_pkg::subpxl_UNDEFINED,
        dwidth                : '{ 10, 0, 0 }
    },
    
    LP_dataRAW12: '{
        col_scheme             : vivo_core_pkg::scheme_BW,
        chr_subsampling        : vivo_core_pkg::subsamp_UNDEFINED,
        rgb_subpxl_scheme    : vivo_core_pkg::subpxl_UNDEFINED,
        dwidth                : '{ 12, 0, 0 }
    },
    
    LP_dataRAW14: '{
        col_scheme             : vivo_core_pkg::scheme_BW,
        chr_subsampling        : vivo_core_pkg::subsamp_UNDEFINED,
        rgb_subpxl_scheme    : vivo_core_pkg::subpxl_UNDEFINED,
        dwidth                : '{ 14, 0, 0 }
    }
};

`endif // __CSI_TYPES_SVH__
