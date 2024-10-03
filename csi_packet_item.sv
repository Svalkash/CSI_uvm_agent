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
//% Класс пакета CSI
//

`ifndef __CSI_PACKET_ITEM_SV__
    `define __CSI_PACKET_ITEM_SV__
    
//----------------------------------------------------------------------------------------------------------------------
// Math functions
//----------------------------------------------------------------------------------------------------------------------
    
const int ecc_hamatrix [0:23] = '{     'h07, 'h0B, 'h0D, 'h0E, 'h13, 'h15, 'h16, 'h19,
'h1A, 'h1C, 'h23, 'h25, 'h26, 'h29, 'h2A, 'h2C,
'h31, 'h32, 'h34, 'h38, 'h1F, 'h2F, 'h37, 'h3B };
    
function bit[5:0] ecc_parity (bit [0:23] par_in);        
    ecc_parity = 0;
    //calc parity
    foreach (ecc_hamatrix[i])
        ecc_parity = (par_in[i] * ecc_hamatrix[i]) ^ ecc_parity;
endfunction: ecc_parity

//line numbers according to CSI!!!
function int lengthInBytes(packetType_t dataFormat, int lenPix, int line = 0);
    case(dataFormat)
        LP_dataYUV420_8,
        LP_dataYUV420_8_CSRS: begin
            if (line == 0)
                uvm_report_warning("CSI_CALCLEN", "Line number is not defined for YUV 4:2:0 - returned length can be invalid!");
            if (lenPix % 2 != 0)
                uvm_report_warning("CSI_CALCLEN", "Number of pixels doesn't allow to recover integer number of bytes!");
            return (line % 2) ? (lenPix / 2) * 2 : (lenPix / 2) * 4;
        end
        LP_dataYUV420_10,
        LP_dataYUV420_10_CSRS: begin
            if (line == 0)
                uvm_report_warning("CSI_CALCLEN", "Line number is not defined for YUV 4:2:0 - returned length can be invalid!");
            if (lenPix % 4 != 0)
                uvm_report_warning("CSI_CALCLEN", "Number of pixels doesn't allow to recover integer number of bytes!");
            return (line % 2) ? (lenPix / 4) * 5 : (lenPix / 4) * 10;
        end
        LP_dataLegacyYUV420_8: begin
            if (lenPix % 2 != 0)
                uvm_report_warning("CSI_CALCLEN", "Number of pixels doesn't allow to recover integer number of bytes!");
            return (lenPix / 2) * 3;
        end
        LP_dataYUV422_8: begin
            if (lenPix % 2 != 0)
                uvm_report_warning("CSI_CALCLEN", "Number of pixels doesn't allow to recover integer number of bytes!");
            return (lenPix / 2) * 4;
        end
        LP_dataYUV422_10: begin
            if (lenPix % 2 != 0)
                uvm_report_warning("CSI_CALCLEN", "Number of pixels doesn't allow to recover integer number of bytes!");
            return (lenPix / 2) * 5;
        end
        LP_dataRGB444,
        LP_dataRGB555,
        LP_dataRGB565: begin
            return lenPix * 2;
        end
        LP_dataRGB666: begin
            if (lenPix % 4 != 0)
                uvm_report_warning("CSI_CALCLEN", "Number of pixels doesn't allow to recover integer number of bytes!");
            return (lenPix / 4) * 9;
        end
        LP_dataRGB888: begin
            return lenPix * 3;
        end
        LP_dataRAW6: begin
            if (lenPix % 4 != 0)
                uvm_report_warning("CSI_CALCLEN", "Number of pixels doesn't allow to recover integer number of bytes!");
            return (lenPix / 4) * 3;
        end
        LP_dataRAW7: begin
            if (lenPix % 8 != 0)
                uvm_report_warning("CSI_CALCLEN", "Number of pixels doesn't allow to recover integer number of bytes!");
            return (lenPix / 8) * 7;
        end
        LP_dataRAW8: begin
            return lenPix;
        end
        LP_dataRAW10: begin
            if (lenPix % 4 != 0)
                uvm_report_warning("CSI_CALCLEN", "Number of pixels doesn't allow to recover integer number of bytes!");
            return (lenPix / 4) * 5;
        end
        LP_dataRAW12: begin
            if (lenPix % 2 != 0)
                uvm_report_warning("CSI_CALCLEN", "Number of pixels doesn't allow to recover integer number of bytes!");
            return (lenPix / 2) * 3;
        end
        LP_dataRAW14: begin
            if (lenPix % 4 != 0)
                uvm_report_warning("CSI_CALCLEN", "Number of pixels doesn't allow to recover integer number of bytes!");
            return (lenPix / 4) * 7;
        end
        default: uvm_report_error("CSI_UNKNOWN", $sformatf("Unknown data format: %d", dataFormat));
    endcase
endfunction: lengthInBytes

//line numbers according to CSI!!!
function int lengthInPixels(packetType_t dataFormat, int lenByte, int line = 1);
    case(dataFormat)
        LP_dataYUV420_8,
        LP_dataYUV420_8_CSRS: begin
            if (line % 2) begin
                if (lenByte % 2 != 0)
                    uvm_report_warning("CSI_CALCLEN", "Number of bytes doesn't allow to recover integer number of pixels!");
                return (lenByte / 2) * 2;
            end
            else begin
                if (lenByte % 4 != 0)
                    uvm_report_warning("CSI_CALCLEN", "Number of bytes doesn't allow to recover integer number of pixels!");
                return (lenByte / 4) * 2;
            end
        end
        LP_dataYUV420_10,
        LP_dataYUV420_10_CSRS: begin
            if (line % 2) begin
                if (lenByte % 5 != 0)
                    uvm_report_warning("CSI_CALCLEN", "Number of bytes doesn't allow to recover integer number of pixels!");
                return (lenByte / 5) * 4;
            end
            else begin
                if (lenByte % 10 != 0)
                    uvm_report_warning("CSI_CALCLEN", "Number of bytes doesn't allow to recover integer number of pixels!");
                return (lenByte / 10) * 4;
            end
        end
        LP_dataLegacyYUV420_8: begin
            if (lenByte % 3 != 0)
                uvm_report_warning("CSI_CALCLEN", "Number of bytes doesn't allow to recover integer number of pixels!");
            return (lenByte / 3) * 2;
        end
        LP_dataYUV422_8: begin
            if (lenByte % 4 != 0)
                uvm_report_warning("CSI_CALCLEN", "Number of bytes doesn't allow to recover integer number of pixels!");
            return (lenByte / 4) * 2;
        end
        LP_dataYUV422_10: begin
            if (lenByte % 5 != 0)
                uvm_report_warning("CSI_CALCLEN", "Number of bytes doesn't allow to recover integer number of pixels!");
            return (lenByte / 5) * 2;
        end
        LP_dataRGB444,
        LP_dataRGB555,
        LP_dataRGB565: begin
            if (lenByte % 2 != 0)
                uvm_report_warning("CSI_CALCLEN", "Number of bytes doesn't allow to recover integer number of pixels!");
            return lenByte / 2;
        end
        LP_dataRGB666: begin
            if (lenByte % 9 != 0)
                uvm_report_warning("CSI_CALCLEN", "Number of bytes doesn't allow to recover integer number of pixels!");
            return (lenByte / 9) * 4;
        end
        LP_dataRGB888: begin
            if (lenByte % 3 != 0)
                uvm_report_warning("CSI_CALCLEN", "Number of bytes doesn't allow to recover integer number of pixels!");
            return lenByte / 3;
        end
        LP_dataRAW6: begin
            if (lenByte % 3 != 0)
                uvm_report_warning("CSI_CALCLEN", "Number of bytes doesn't allow to recover integer number of pixels!");
            return (lenByte / 3) * 4;
        end
        LP_dataRAW7: begin
            if (lenByte % 7 != 0)
                uvm_report_warning("CSI_CALCLEN", "Number of bytes doesn't allow to recover integer number of pixels!");
            return (lenByte / 7) * 8;
        end
        LP_dataRAW8: begin
            return lenByte;
        end
        LP_dataRAW10: begin
            if (lenByte % 5 != 0)
                uvm_report_warning("CSI_CALCLEN", "Number of bytes doesn't allow to recover integer number of pixels!");
            return (lenByte / 5) * 4;
        end
        LP_dataRAW12: begin
            if (lenByte % 3 != 0)
                uvm_report_warning("CSI_CALCLEN", "Number of bytes doesn't allow to recover integer number of pixels!");
            return (lenByte / 3) * 2;
        end
        LP_dataRAW14: begin
            if (lenByte % 7 != 0)
                uvm_report_warning("CSI_CALCLEN", "Number of bytes doesn't allow to recover integer number of pixels!");
            return (lenByte / 7) * 4;
        end
        default: uvm_report_error("CSI_UNKNOWN", $sformatf("Unknown data format: %d", dataFormat));
    endcase
endfunction: lengthInPixels

//WHY IS IT ILLEGAL
function byte byteReverse(byte r_in);
    for (int i = 0; i < 8; ++i)
        byteReverse[i] = r_in[7 - i];
endfunction: byteReverse
    
//----------------------------------------------------------------------------------------------------------------------
// Packet class
//----------------------------------------------------------------------------------------------------------------------

class packet_item_c extends uvm_sequence_item;
    
    localparam int CRC16_POLY = 16'h8408;
    
    //------------------------------------------------------------------------------------------------------------------
    // Data
    //------------------------------------------------------------------------------------------------------------------

    //header
    bit[1:0]    channelID;
    bit[5:0]    dataType;
    shortint    wordCount = 0;
    byte        ecc = 0;
    //data
    byte        data [];
    //footer
    shortint    crc = 0;
    
    bit            is_last;  // last packet from that source

    //------------------------------------------------------------------------------------------------------------------
    // UVM automation macros
    //------------------------------------------------------------------------------------------------------------------

    `uvm_object_utils_begin(csi_pkg::packet_item_c)
        `uvm_field_int        (channelID, UVM_ALL_ON | UVM_DEC)
        `uvm_field_int        (dataType , UVM_ALL_ON | UVM_HEX)
        `uvm_field_int        (wordCount, UVM_ALL_ON | UVM_DEC)
        `uvm_field_int        (ecc         , UVM_ALL_ON | UVM_HEX)
        `uvm_field_array_int  (data     , UVM_ALL_ON)
        `uvm_field_int        (crc         , UVM_ALL_ON | UVM_HEX)
        `uvm_field_int           (is_last    , UVM_ALL_ON | UVM_NOCOMPARE | UVM_BIN)
    `uvm_object_utils_end

    //------------------------------------------------------------------------------------------------------------------
    // constructor
    //------------------------------------------------------------------------------------------------------------------

    function new (string name = "csi_packet_item", packetType_t pt = P_invalid, bit [1:0] chID = 0, shortint wc = 0, bit islast = 0);
        super.new(name);
        set_dataType(pt);
        set_channelID(chID);
        wordCount = wc;
        is_last = islast;
        //reacalc check fields
        recalc_ecc();
        //for long packets
        if (is_long() && wordCount > 0) begin
            data = new[wc];
            recalc_crc (); //well, why not
        end
    endfunction : new
    
    function void set_dataID (byte di);
        //channelID = di[7:6];
        //dataType = di[5:0];
        {channelID, dataType} = di;
        recalc_ecc();
    endfunction: set_dataID
    
    function void set_channelID (bit [1:0] cid);
        channelID = cid;
        recalc_ecc();
    endfunction: set_channelID
    
    function void set_dataType (packetType_t pt);
        $cast(dataType, pt);
        recalc_ecc();
    endfunction: set_dataType
    
    function void set_wordCount(shortint wc);
        wordCount = wc;
        recalc_ecc();
        if (is_long()) begin
            //resize data, recalc stuff
            data = new[wordCount](data);
            recalc_crc();
        end
    endfunction: set_wordCount
    
    function byte get_dataID ();
        return { channelID, dataType };
    endfunction: get_dataID
    
    function packetType_t get_packetType ();
        packetType_t pt;
        $cast(pt, dataType);
        return pt;
    endfunction: get_packetType
    
    function bit is_long();
        return dataType > 6'h0F;
    endfunction: is_long
    
    //changes length in PIXELS
    function void set_pixel_length(int len, int line = 0);
        int tempLen;
        if (!is_long())
            uvm_report_error("CSI_SPL", "Setting pixel length of the short packet");
        tempLen = lengthInBytes(get_packetType(), len, line);
        //check if temp length is correct
        if (tempLen > 16'hffff)
            uvm_report_error("CSI_SPL", $sformatf("Too long (in bytes), must be < 0xFFFF: %x", tempLen));
        set_wordCount(tempLen);
    endfunction: set_pixel_length
    
    //returns length in PIXELS
    function int get_pixel_length(int line = 0);
        if (!is_long)
            uvm_report_error("CSI_SPL", "Trying to get pixel length of the short packet");
        return lengthInPixels(get_packetType(), wordCount, line);
    endfunction: get_pixel_length
    
    function void recalc_ecc ();
        bit [0:23] ecc_in;

        ecc_in[0:7] = byteReverse({channelID, dataType});
        ecc_in[8:15] = byteReverse(wordCount[7:0]);
        ecc_in[16:23] = byteReverse(wordCount[15:8]);
        //calc parity
        ecc[5:0] = ecc_parity(ecc_in);
    endfunction: recalc_ecc
    
    //0 = no errs, 1 = corrected, 2 = error
    function int ecc_correct ();
        int err_pos = -1;
        bit[5:0] err_syndrome;
        bit [0:23] ecc_in;        

        //combine header
        ecc_in[0:7] = byteReverse({channelID, dataType});
        ecc_in[8:15] = byteReverse(wordCount[7:0]);
        ecc_in[16:23] = byteReverse(wordCount[15:8]);
        //calc syn
        err_syndrome = ecc_parity(ecc_in) ^ ecc;
        //find pos
        if (!err_syndrome)
            return 0;
        foreach (ecc_hamatrix[i])
            if (ecc_hamatrix[i] == err_syndrome)
                err_pos = i;
        if (err_pos == -1) return 2;
        //correct
        ecc_in[err_pos] = !ecc_in[err_pos];
        
        {channelID, dataType} = byteReverse(ecc_in[0:7]);
        wordCount[15:0] = byteReverse(ecc_in[8:23]);
        return 1;
    endfunction: ecc_correct

    function bit [15:0] crc16_ibm ();
        int i, j;
        shortint new_crc = 16'hffff;
        
        if (wordCount == 0)
            return new_crc;
        
        for (int i = 0; i < wordCount; ++i) begin
            for (int j = 0; j < 8; ++j) begin
                if (new_crc[0] ^ data[i][j])
                    new_crc = (new_crc >> 1) ^ CRC16_POLY;
                else
                    new_crc >>= 1;
            end
        end
        return new_crc;
    endfunction: crc16_ibm

    function void recalc_crc ();
        crc = crc16_ibm();
    endfunction: recalc_crc

    function bit crc_check ();
        return (crc16_ibm() != crc);
    endfunction: crc_check
    
endclass : packet_item_c

`endif // __CSI_PACKET_ITEM_SV__
