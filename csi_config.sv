//
// File : csi_config.sv
//
// Created:
//          by HDL Designers Team
//          of Electronics Design Center "OhT"
//          www.overhitech.com
//
//
// File Description:
//
//% Конфигурация CSI сиквенсера пакетов
//

`ifndef __CSI_CONFIG_SV__
    `define __CSI_CONFIG_SV__

//----------------------------------------------------------------------------------------------------------------------
// CSI configuration
//----------------------------------------------------------------------------------------------------------------------

class config_c extends vivo_cfg_pkg::cfg_base_c;

    //------------------------------------------------------------------------------------------------------------------
    // Parameters
    //------------------------------------------------------------------------------------------------------------------

    int frame_w = 0; //size not needed for monitor, but is checked after frame receiving (if not 0)
    int frame_h = 0;

    int interlaced = 0; //0 - not int, 1 - first field uneven lines, 2 - even (counting from 1)

    //------------------------------------------------------------------------------------------------------------------
    // Driver-specific
    //------------------------------------------------------------------------------------------------------------------

    int intFormat = 6'h2A; //kostyl for dataFormat, monitor - checked after receiving (if not 0)
    packetType_t dataFormat = P_invalid; //because why not? Good format, defined in STD...

    int frame_n_period = 4; //if 0 - number is inoperative
    bit sendLineSE = 0; //send lineStart / lineEnd packet

    //------------------------------------------------------------------------------------------------------------------
    // Monitor-specific
    //------------------------------------------------------------------------------------------------------------------

    bit checkLineSE = 0; // check presence and contents of LS/LE packets
    bit checkFieldOrder = 0;

    //------------------------------------------------------------------------------------------------------------------
    // UVM automation macros
    //------------------------------------------------------------------------------------------------------------------

    `uvm_object_param_utils_begin(csi_pkg::config_c)
        `uvm_field_int    (frame_n_period,    UVM_ALL_ON | UVM_DEC)
        `uvm_field_int    (frame_w,            UVM_ALL_ON | UVM_DEC) //used for checking in monitor
        `uvm_field_int    (frame_h,            UVM_ALL_ON | UVM_DEC) //used for checking in monitor
        `uvm_field_int    (intFormat,            UVM_ALL_ON | UVM_DEC) //used for checking in monitor
        `uvm_field_int    (sendLineSE,        UVM_ALL_ON | UVM_BIN)
        `uvm_field_int    (interlaced,        UVM_ALL_ON | UVM_BIN)
        `uvm_field_enum (csi_pkg::packetType_t, dataFormat, UVM_ALL_ON)
        //monitor
        `uvm_field_int    (checkLineSE,        UVM_ALL_ON | UVM_BIN)
        `uvm_field_int    (checkFieldOrder,    UVM_ALL_ON | UVM_BIN)
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
        if (frame_w <= 0 || frame_h <= 0) begin
            uvm_report_error("CSICFGCHECK", $sformatf("Frame size (%0d x %0d) is invalid!", frame_w, frame_h));
            return 1;
        end
        if (!$cast(dataFormat, intFormat)) begin
            uvm_report_error("CSICFGCHECK", $sformatf("Invalid data format: %0x", intFormat));
            return 1;
        end
        //Driver-specific
        if (is_active == UVM_ACTIVE) begin
            if (frame_n_period < 0) begin
                uvm_report_error("CSICFGCHECK", $sformatf("Frame number period (%0d) is invalid!", frame_n_period));
                return 1;
            end
            if (interlaced && !sendLineSE)
                uvm_report_warning("CSICFGCHECK", "Enabled 'interlaced' flag without 'sendLineSE'. Interlaced frames will not be recognized on receiver.");
        end
        if (!$cast(dataFormat, intFormat)) begin
            uvm_report_error("CSICFGCHECK", $sformatf("Invalid data format: %0x", intFormat));
            return 1;
        end
        return 0;
    endfunction: check_cfg

    virtual function void cfg_update();
        super.cfg_update();
        //check other params
        if (check_cfg())
            uvm_report_fatal("CSICFGERR", "Configuration check didn't passed.");
    endfunction: cfg_update

    //------------------------------------------------------------------------------------------------------------------
    // vd_mode2params function
    //------------------------------------------------------------------------------------------------------------------

    function vivo_cfg_pkg::cfg_params_t vd_mode2params(vivo_cfg_pkg::cfg_vd_mode_t vd_mode);
        if (vd_mode.resol_x <= 0 || vd_mode.resol_y <= 0)
            uvm_report_fatal("CSICFGERR", $sformatf("Provided video mode (%0dx%0d) is impossible.", vd_mode.resol_x, vd_mode.resol_y));
        vd_mode2params = new[2];
        vd_mode2params[0].name = "frame_w";
        vd_mode2params[0].value = vd_mode.resol_x;
        vd_mode2params[1].name = "frame_h";
        vd_mode2params[1].value = vd_mode.resol_y;
        //transform fps value to mode name
    endfunction : vd_mode2params

    //------------------------------------------------------------------------------------------------------------------
    // get new frame_item
    //------------------------------------------------------------------------------------------------------------------

    function vivo_core_pkg::frame_item_c get_frame_item(string name = "dvi_d_frame_item", bit field = 0);
        if (dataFormat == P_invalid)
            uvm_report_fatal("CSICFGERR", $sformatf("Can't return frame item while data format is not defined."));
        get_frame_item = vivo_core_pkg::frame_item_c::type_id::create(name);
        get_frame_item.width = frame_w;
        get_frame_item.height = frame_h;

        //instead of dumb case
        get_frame_item.col_scheme          = frameFormats[dataFormat].col_scheme;
        get_frame_item.rgb_subpxl_scheme = frameFormats[dataFormat].rgb_subpxl_scheme;
        get_frame_item.chr_subsampling      = frameFormats[dataFormat].chr_subsampling;
        get_frame_item.layer0_dwidth      = frameFormats[dataFormat].dwidth[0];
        get_frame_item.layer1_dwidth      = frameFormats[dataFormat].dwidth[1];
        get_frame_item.layer2_dwidth      = frameFormats[dataFormat].dwidth[2];

        get_frame_item.interlaced = interlaced;
        get_frame_item.data_init();
    endfunction

endclass : config_c

`endif // __CSI_CONFIG_SV__
