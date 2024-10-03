//
// File : csi_packet_item.sv
//
// Created:
//          by HDL Designers Team
//          of Electronics Design Center "OhT"
//          www.overhitech.com
//
//
// File Description:
//
//% Класс multi-lane транзакции CSI
//

`ifndef __CSI_MLTRAN_ITEM_SV__
    `define __CSI_MLTRAN_ITEM_SV__
    
//----------------------------------------------------------------------------------------------------------------------
// Packet class
//----------------------------------------------------------------------------------------------------------------------

class mltran_item_c#(int LANES_MAX = 4) extends uvm_sequence_item;

    localparam int WORD_LEN = 8;
    
    //------------------------------------------------------------------------------------------------------------------
    // Data
    //------------------------------------------------------------------------------------------------------------------

    int         length = 0;
    bit[7:0]    data     [LANES_MAX-1:0][];
    bit         lastbit [LANES_MAX-1:0] = '{ default: 1'b1 }; //needed because not all last BYTES are actual data
    
    bit     is_last = 0;  // last transaction from that source
    bit        ulps_after = 0; //if 1, driver will go ULPS after transaction

    //------------------------------------------------------------------------------------------------------------------
    // UVM automation macros
    //------------------------------------------------------------------------------------------------------------------

    `uvm_object_param_utils_begin(csi_pkg::mltran_item_c#(LANES_MAX))
        `uvm_field_int        (length        , UVM_ALL_ON | UVM_DEC)
        `uvm_field_int           (is_last        , UVM_ALL_ON | UVM_NOCOMPARE | UVM_BIN)
        `uvm_field_int           (ulps_after    , UVM_ALL_ON | UVM_NOCOMPARE | UVM_BIN)
    `uvm_object_utils_end

    //------------------------------------------------------------------------------------------------------------------
    // constructor
    //------------------------------------------------------------------------------------------------------------------

    function new (string name = "csi_multilane_transaction", int len = 0, bit islast = 0);
        super.new(name);
        set_length(0);
        is_last = islast;
    endfunction: new
    
    function void set_length(int len = 0);
        length = len;
        foreach(data[i])
            data[i] = new[len](data[i]);
    endfunction: set_length
    
    virtual function void do_print (uvm_printer printer);
        string stepstr;
        super.do_print(printer);
        
        stepstr = "";
        for (int i = 0; i < length; ++i) begin
            stepstr = { stepstr, $sformatf("\nByte %0d", i) };
            for (int lane = 0; lane < LANES_MAX; ++lane)
                stepstr = { stepstr, $sformatf(" | %x", data[lane][i]) };
        end
        printer.print_string("data", stepstr);
        
        stepstr = "\n";
        for (int lane = 0; lane < LANES_MAX; ++lane)
            stepstr = { stepstr, $sformatf(" | %b", lastbit[lane]) };
        printer.print_string("lastbit", stepstr);
    endfunction
    
endclass : mltran_item_c

`endif // __CSI_MLTRAN_ITEM_SV__
