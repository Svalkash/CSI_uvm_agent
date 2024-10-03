//
// File : csi_ext_monitor.sv
//
// Created:
//          by HDL Designers Team
//          of Electronics Design Center "OhT"
//          www.overhitech.com
//
//
// File Description:
//
//% Внешний монитор CSI
//

`ifndef __CSI_EXT_MONITOR_SV__
    `define __CSI_EXT_MONITOR_SV__

typedef class ext_agent_base_c;
    

class ext_monitor_c#(int LANES_MAX = 4) extends uvm_monitor;
`timescale 1ns/1ps

    virtual oht_vivo_csi_ppi_if#(LANES_MAX).monitor_mp vif;
 
    ext_agent_base_c    p_agent;
    
    ext_config_c        cfg;
    
    uvm_analysis_port#(mltran_item_c#(LANES_MAX))   mltran_aport;

    //------------------------------------------------------------------------------------------------------------------
    // Signal data
    //------------------------------------------------------------------------------------------------------------------
    
    rxState_t data_state = RX_Stop;
    rxState_t clk_state = RX_Stop;
    
    bit[0:7] escapeCmd;
    
    byte data_deser[LANES_MAX-1:0] = '{ default:0 }; //HS data (received)

    uvm_queue#(byte) byte_q [LANES_MAX-1:0]; //deserialized bytes
    
    //constants
    const bit[0:7] esc_cmd_ULPS = 8'b00011110;
    
    //------------------------------------------------------------------------------------------------------------------
    // UVM automation macros
    //------------------------------------------------------------------------------------------------------------------
    
    `uvm_component_param_utils_begin(csi_pkg::ext_monitor_c#(LANES_MAX))
        `uvm_field_object  (p_agent, UVM_ALL_ON | UVM_NOCOMPARE)
        `uvm_field_object  (cfg, UVM_ALL_ON | UVM_NOCOMPARE)
    `uvm_component_utils_end

    //------------------------------------------------------------------------------------------------------------------
    // constructor
    //------------------------------------------------------------------------------------------------------------------

    function new (string name = "csi_ext_monitor", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    //------------------------------------------------------------------------------------------------------------------
    // build routine
    //------------------------------------------------------------------------------------------------------------------

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // create aport
        mltran_aport = new("mltran_aport", this);
        // create queues
        foreach(byte_q[i])
            byte_q[i] = new($sformatf("bytes_queue_%0d", i));
        // config interface
        if(!uvm_config_db#(virtual oht_vivo_csi_ppi_if#(LANES_MAX).monitor_mp)::get(this, "", "vif", vif))
            uvm_report_fatal("NOVIF", {"virtual interface must be set for: ", get_type_name(), ".vif"});
    endfunction: build_phase

    //------------------------------------------------------------------------------------------------------------------
    // run
    //------------------------------------------------------------------------------------------------------------------
    
    virtual task run_phase(uvm_phase phase);
        
        if (cfg.is_active == UVM_ACTIVE)
            return;
        uvm_report_info("DISP", "CSI monitor is PASSIVE", UVM_MEDIUM);
        
        stop_if();
        wait(cfg.enabled);
        
        init_if();
        fork
            dphy_clkSM();
            dphy_dataSM();
        join
    endtask : run_phase

    //------------------------------------------------------------------------------------------------------------------
    // Init function
    //------------------------------------------------------------------------------------------------------------------
    
    task init_if();
        vif.usrstdby     <= 0;
        //LP
        clk_lp();
        data_lp_switch();
        vif.d0_hsdeseren <= 0; //first time async?
    endtask: init_if

    task stop_if();
        vif.usrstdby     <= 1;
    endtask: stop_if

    //------------------------------------------------------------------------------------------------------------------
    // CLK lane
    //------------------------------------------------------------------------------------------------------------------
    
    //LP
    task clk_lp ();
        vif.clk_rxlpen     <= 1;
        vif.clk_rxhsen     <= 0;
    endtask: clk_lp
    
    //HS
    task clk_hs ();
        vif.clk_rxlpen     <= 0;
        vif.clk_rxhsen     <= 1;
    endtask: clk_hs
    
    //cool error handler
    task dphy_clkSM_error(rxState_t rxState);
        uvm_report_error("CSI_CLKSM_ERR", $sformatf("%s: invalid transition (LP: %0d %0d)!", rxState, vif.clk_rxlpp, vif.clk_rxlpn));
        wait ({vif.clk_rxlpp, vif.clk_rxlpn} == {1'b1, 1'b1}); //error recovery
        clk_state = RX_Stop;
    endtask: dphy_clkSM_error
    
    task dphy_clkSM();
        bit lane_stable;
        bit clk_missed;
        
        //wait for starting STOP state :)
        wait ({vif.clk_rxlpp, vif.clk_rxlpn} == {1'b1, 1'b1});
        clk_state = RX_Stop;
        //start SM
        forever
            case(clk_state)
                RX_Stop: begin
                    uvm_report_info("CSI_CLKSM_LOG", "CLK: RX_Stop", UVM_HIGH);
                    @(vif.clk_rxlpp or vif.clk_rxlpn);
                    case({vif.clk_rxlpp, vif.clk_rxlpn})
                        {1'b0, 1'b1}: clk_state = RX_HS_Rqst;
                        {1'b1, 1'b0}: clk_state = RX_ULPS_Rqst;
                        default: dphy_clkSM_error(clk_state);
                    endcase
                end
                RX_HS_Rqst: begin
                    uvm_report_info("CSI_CLKSM_LOG", "CLK: RX_HS_Rqst", UVM_HIGH);
                    @(vif.clk_rxlpp or vif.clk_rxlpn);
                    case({vif.clk_rxlpp, vif.clk_rxlpn})
                        {1'b0, 1'b0}: clk_state = RX_HS_Prpr;
                        default: dphy_clkSM_error(clk_state);
                    endcase
                end
                RX_HS_Prpr: begin
                    uvm_report_info("CSI_CLKSM_LOG", "CLK: RX_HS_Prpr", UVM_HIGH);
                    lane_stable = 1;
                    fork
                        begin: clk_rx_hs_prpr_unstable
                            @(vif.clk_rxlpp or vif.clk_rxlpn);
                            lane_stable = 0;
                            disable clk_rx_hs_prpr_stable;
                        end: clk_rx_hs_prpr_unstable
                        begin: clk_rx_hs_prpr_stable
                            #cfg.t_clk_term_en;
                            disable clk_rx_hs_prpr_unstable;
                        end: clk_rx_hs_prpr_stable
                    join
                    //check if lane is still 00
                    if (lane_stable)
                        clk_state = RX_HS_Term;
                    else dphy_clkSM_error(clk_state);
                end
                RX_HS_Term: begin
                    uvm_report_info("CSI_CLKSM_LOG", "CLK: RX_HS_Term", UVM_HIGH);
                    //enable Termination (some analogue stuff), switch to HS
                    clk_hs();
                    uvm_report_info("CSI_EXT_MON", "CLK Lane - Termination ON", UVM_HIGH); //Analogue stuff, so just message here
                    //enable HS clock, wait for it to settle
                    #(cfg.t_clk_settle - cfg.t_clk_term_en);
                    @(vif.clk_cd); //wait for clock to appear
                    clk_state = RX_HS_Clk;
                end
                RX_HS_Clk: begin
                    uvm_report_info("CSI_CLKSM_LOG", "CLK: RX_HS_Clk", UVM_HIGH);
                    //receiving clock, waiting for it to end
                    clk_missed = 0;        
                    while (!clk_missed)
                        fork
                            begin: clk_rx_hs_clk_missed
                                #cfg.t_clk_miss;
                                clk_missed = 1;
                                disable clk_rx_hs_clk_edge;
                            end: clk_rx_hs_clk_missed
                            begin: clk_rx_hs_clk_edge
                                @(edge vif.clk_cd); //clk_cd at least shows current HS state, so - why not?
                                disable clk_rx_hs_clk_missed;
                            end: clk_rx_hs_clk_edge
                        join
                    //clk missed, trans
                    clk_state = RX_HS_End;
                end
                RX_HS_End: begin
                    uvm_report_info("CSI_CLKSM_LOG", "CLK: RX_HS_End", UVM_HIGH);
                    uvm_report_info("CSI_EXT_MON", "CLK: no transitions, waiting for LP...", UVM_HIGH);
                    //no transitions for Tclk-miss, stop HS
                    clk_lp();
                    uvm_report_info("CSI_EXT_MON", "CLK Lane - Termination OFF", UVM_HIGH); //analogue stuff
                    wait ({vif.clk_rxlpp, vif.clk_rxlpn} == {1'b1, 1'b1}); //just wait, ignore other states (00 -> 11 can't be perfect.. right?)
                    clk_state = RX_Stop;
                end
                RX_ULPS_Rqst: begin
                    uvm_report_info("CSI_CLKSM_LOG", "CLK: RX_ULPS_Rqst", UVM_HIGH);
                    @(vif.clk_rxlpp or vif.clk_rxlpn);
                    case({vif.clk_rxlpp, vif.clk_rxlpn})
                        {1'b0, 1'b0}: clk_state = RX_ULPS;
                        default: dphy_clkSM_error(clk_state);
                    endcase
                end
                RX_ULPS: begin
                    uvm_report_info("CSI_CLKSM_LOG", "CLK: RX_ULPS", UVM_HIGH);
                    @(vif.clk_rxlpp or vif.clk_rxlpn);
                    case({vif.clk_rxlpp, vif.clk_rxlpn})
                        {1'b1, 1'b0}: clk_state = RX_ULPS_Exit;
                        default: dphy_clkSM_error(clk_state);
                    endcase
                end
                RX_ULPS_Exit: begin
                    uvm_report_info("CSI_CLKSM_LOG", "CLK: RX_ULPS_Exit", UVM_HIGH);
                    @(vif.clk_rxlpp or vif.clk_rxlpn);
                    case({vif.clk_rxlpp, vif.clk_rxlpn})
                    	{1'b1, 1'b1}: clk_state = RX_Stop;
						default: dphy_clkSM_error(clk_state);
					endcase
				end
				default: uvm_report_error("CSI_CLKSM_ERR", "Invalid clock SM state!");
			endcase
	endtask: dphy_clkSM

	//------------------------------------------------------------------------------------------------------------------
	// DATA lanes
	//------------------------------------------------------------------------------------------------------------------
	
	//switch to LP
	task data_lp_switch;
		vif.d0_rxlpen 	<= 1;
		vif.d0_rxhsen 	<= 0;
	endtask: data_lp_switch
	
	//switch to HS
	task data_hs_switch ();
		vif.d0_rxlpen 	<= 0;
		vif.d0_rxhsen 	<= 1;
	endtask: data_hs_switch
	
	//HS(data) - WITHOUT switching
	task data_hs_get ();
		int map_index;
		@(posedge vif.rxhsbyteclk);
		for (int lane = 0; lane < cfg.lanes_used; ++lane)
			for (int bi = 0; bi < 8; ++bi)
				data_deser[lane][bi] = vif.q[lane + bi * LANES_MAX];
		uvm_report_info("CSI_EXT_MON", $sformatf("Received data: %p", data_deser), UVM_HIGH);
	endtask: data_hs_get
	
	//cool error handler
	task dphy_dataSM_error(rxState_t rxState);
		uvm_report_error("CSI_DATASM_ERR", $sformatf("%s: invalid transition (LP: %0d %0d)!", rxState, vif.d0_rxlpp, vif.d0_rxlpn));
		wait ({vif.d0_rxlpp, vif.d0_rxlpn} == {1'b1, 1'b1}); //error recovery
		data_state = RX_Stop;
	endtask: dphy_dataSM_error
	
	task dphy_dataSM ();
		bit lane_stable;
		
		//wait for starting STOP state :)
		wait ({vif.d0_rxlpp, vif.d0_rxlpn} == {1'b1, 1'b1});
		data_state = RX_Stop;
		//start SM
		forever
			case(data_state)
				RX_Stop: begin
					uvm_report_info("CSI_DATASM_LOG", "DATA: RX_Stop", UVM_HIGH);
					@(vif.d0_rxlpp or vif.d0_rxlpn);
					case({vif.d0_rxlpp, vif.d0_rxlpn})
						{1'b0, 1'b1}: begin
							data_state = RX_HS_Rqst;
							if (clk_state != RX_HS_Clk)
								uvm_report_error("CSI_DATASM_ERR", "RX_HS_Rqst on DATA lanes before RX_HS_Clk on CLK lane!");
						end
						{1'b1, 1'b0}: data_state = RX_LP_Rqst;
						default: dphy_dataSM_error(data_state);
					endcase
				end
				RX_HS_Rqst: begin
					uvm_report_info("CSI_DATASM_LOG", "DATA: RX_HS_Rqst", UVM_HIGH);
					@(vif.d0_rxlpp or vif.d0_rxlpn);
					case({vif.d0_rxlpp, vif.d0_rxlpn})
						{1'b0, 1'b0}: data_state = RX_HS_Prpr;
						default: dphy_dataSM_error(data_state);
					endcase
				end
				RX_HS_Prpr: begin
					uvm_report_info("CSI_DATASM_LOG", "DATA: RX_HS_Prpr", UVM_HIGH);
					lane_stable = 1;
					fork
						begin: data_rx_hs_prpr_unstable
							@(vif.d0_rxlpp or vif.d0_rxlpn);
							lane_stable = 0;
							disable data_rx_hs_prpr_stable;
						end: data_rx_hs_prpr_unstable
						begin: data_rx_hs_prpr_stable
							#cfg.t_d_term_en;
							disable data_rx_hs_prpr_unstable;
						end: data_rx_hs_prpr_stable
					join
					//check if lane is still 00
					if (lane_stable)
						data_state = RX_HS_Term;
					else dphy_dataSM_error(data_state);
				end
				RX_HS_Term: begin
					uvm_report_info("CSI_DATASM_LOG", "DATA: RX_HS_Term", UVM_HIGH);
					//switch to hsm wait for HS to settle
					data_hs_switch();
					uvm_report_info("CSI_EXT_MON", "DATA Lanes - Termination ON", UVM_HIGH); //Analogue stuff, so just message here
					#(cfg.t_hs_settle - cfg.t_d_term_en);
					data_state = RX_HS_Run;
				end
				RX_HS_Run: begin
					uvm_report_info("CSI_DATASM_LOG", "DATA: RX_HS_Run", UVM_HIGH);
					//enable deser - RX DPHY automatically detects leader sequence
					@(posedge vif.clkhsbyte)
						vif.d0_hsdeseren <= 1;
					//wait and receive packet
					fork
						getTran(); //works until state change
					join_none
					//wait for LP11 (STOP), ignore others
					wait ({vif.d0_rxlpp, vif.d0_rxlpn} == {1'b1, 1'b1});
					//disable HS
					data_lp_switch(); //no time consumed
					uvm_report_info("CSI_EXT_MON", "DATA Lanes - Termination OFF", UVM_HIGH); //Analogue stuff, so just message here
					//it works like fork
					vif.d0_hsdeseren = @(posedge vif.rxhsbyteclk) 0;
					//switch lane state
					data_state = RX_Stop;
				end
				RX_LP_Rqst: begin
					uvm_report_info("CSI_DATASM_LOG", "DATA: RX_LP_Rqst", UVM_HIGH);
					@(vif.d0_rxlpp or vif.d0_rxlpn);
					case({vif.d0_rxlpp, vif.d0_rxlpn})
						{1'b0, 1'b0}: data_state = RX_LP_Yield;
						default: dphy_dataSM_error(data_state);
					endcase
				end
				RX_LP_Yield: begin
					uvm_report_info("CSI_DATASM_LOG", "DATA: RX_LP_Yield", UVM_HIGH);
					@(vif.d0_rxlpp or vif.d0_rxlpn);
					case({vif.d0_rxlpp, vif.d0_rxlpn})
						{1'b0, 1'b1}: data_state = RX_Esc_Rqst;
						default: dphy_dataSM_error(data_state);
					endcase
				end
				RX_Esc_Rqst: begin
					uvm_report_info("CSI_DATASM_LOG", "DATA: RX_Esc_Rqst", UVM_HIGH);
					@(vif.d0_rxlpp or vif.d0_rxlpn);
					case({vif.d0_rxlpp, vif.d0_rxlpn})
						{1'b0, 1'b0}: data_state = RX_Esc_Go;
						default: dphy_dataSM_error(data_state);
					endcase
				end
				RX_Esc_Go: begin
					uvm_report_info("CSI_DATASM_LOG", "DATA: RX_Esc_Go", UVM_HIGH);
					@(vif.d0_rxlpp or vif.d0_rxlpn);
					case({vif.d0_rxlpp, vif.d0_rxlpn})
						{1'b0, 1'b1},
						{1'b1, 1'b0}: data_state = RX_Esc_Cmd;
						default: dphy_dataSM_error(data_state);
					endcase
				end
				RX_Esc_Cmd: begin
					uvm_report_info("CSI_DATASM_LOG", "DATA: RX_Esc_Cmd", UVM_HIGH);
					getEscapeCmd();
					case(escapeCmd)
						esc_cmd_ULPS: data_state = RX_ULPS;
						default: begin
							if (cfg.strictEscapeCheck)
								uvm_report_error("CSI_ESC_UNKNCMD", $sformatf("Unknown Escape Mode command received: %b! Waiting for RX_Stop...", escapeCmd));
							else
								uvm_report_warning("CSI_ESC_UNKNCMD", $sformatf("Received Escape Mode command is unsupported: %b! Waiting for RX_Stop...", escapeCmd));
							@(vif.d0_rxlpp or vif.d0_rxlpn);
								//wait for LP11 (STOP), ignore others
							wait ({vif.d0_rxlpp, vif.d0_rxlpn} == {1'b1, 1'b1});
							uvm_report_info("CSI_ESC_UNKNCMD", $sformatf("Got RX_Stop - recovered.", escapeCmd), UVM_LOW);
						end
					endcase
				end
				RX_ULPS: begin
					uvm_report_info("CSI_DATASM_LOG", "DATA: RX_ULPS", UVM_HIGH);
					@(vif.d0_rxlpp or vif.d0_rxlpn);
					case({vif.d0_rxlpp, vif.d0_rxlpn})
						{1'b1, 1'b0}: data_state = RX_Wait;
						default: dphy_dataSM_error(data_state);
					endcase
				end
				RX_Wait: begin
					uvm_report_info("CSI_DATASM_LOG", "DATA: RX_Wait", UVM_HIGH);
					@(vif.d0_rxlpp or vif.d0_rxlpn);
					case({vif.d0_rxlpp, vif.d0_rxlpn})
						{1'b1, 1'b1}: data_state = RX_Stop;
						default: dphy_dataSM_error(data_state);
					endcase
				end
				default: uvm_report_error("CSI_DATASM_ERR", "Invalid data SM state!");
			endcase
	endtask: dphy_dataSM
	
	task getEscapeCmd();
		for (int i = 0; i < 8; ++i) begin
			//one-hot
			if (i > 0) //first time it's done in RX_Esc_Go
				@(vif.d0_rxlpp or vif.d0_rxlpn);
			case({vif.d0_rxlpp, vif.d0_rxlpn})
				{1'b0, 1'b1},
				{1'b1, 1'b0}: escapeCmd[i] = vif.d0_rxlpp;
				default: dphy_dataSM_error(data_state);
			endcase
			//space
			@(vif.d0_rxlpp or vif.d0_rxlpn);
			if ({vif.d0_rxlpp, vif.d0_rxlpn} != {1'b0, 1'b0})
				uvm_report_error("CSI_DATASM_ERR", $sformatf("RX_Esc_Cmd: Space is not 00 (LP: %0d %0d)!", vif.d0_rxlpp, vif.d0_rxlpn));
		end
	endtask: getEscapeCmd
	
	task getTran();
		mltran_item_c#(LANES_MAX) collected_tran; //received transaction
		int byte_pos = 0;
		
		longint last_byte_time = 0;
		//receive data on ALL lanes
		//starter sequence is recognized automatically
		while (data_state == RX_HS_Run)
			begin
				data_hs_get();
				for (int lane = 0; lane < cfg.lanes_used; ++lane)
					byte_q[lane].push_back(data_deser[lane]);
				last_byte_time = $time;
			end
			
		//ignore skipped bits
		for (int lane = 0; lane < cfg.lanes_used; ++lane)
			ignoreSkipped(lane, last_byte_time);
		
		//trails will be removed later, send as is
		collected_tran = mltran_item_c#(LANES_MAX)::type_id::create("collected_mltran");
		collected_tran.set_length(byte_q[0].size()); //since all lengths are equal, don't care
		while (byte_q[0].size()) begin //same
			for (int lane = 0; lane < cfg.lanes_used; ++lane)
				collected_tran.data[lane][byte_pos] = byte_q[lane].pop_front();
			++byte_pos;
		end
		//CURRENT lastbit is inversed data lastbit
		for (int lane = 0; lane < cfg.lanes_used; ++lane)
			collected_tran.lastbit[lane] = !collected_tran.data[lane][collected_tran.length - 1];
		//send this trash to next monitor
		mltran_aport.write(collected_tran);
	endtask: getTran
	
	//removes last flipped bit from queue
	function void ignoreSkipped(int lane, longint last_byte_time);
		int bits_skipped;
		byte last_unskipped;
		bit flipped_bit;
		
		//ignore last X bits to negate transmission effects
		bits_skipped = (cfg.t_hs_skip - ($time - last_byte_time)) / cfg.t_ui;
		for (int i = 0; i < bits_skipped / 8; ++i) //just remove skipped bytes
			void'(byte_q[lane].pop_back()); //if q is empty and timings are wrong, another error will happen :)
		
		//mask skipped bits in last byte AND remember flipped bit
		last_unskipped = byte_q[lane].pop_back();
		flipped_bit = last_unskipped[8 - bits_skipped % 8 - 1];
		for (int i = 8 - bits_skipped % 8; i < 8; ++i)
			last_unskipped[i] = flipped_bit;
		byte_q[lane].push_back(last_unskipped);
	endfunction: ignoreSkipped

endclass : ext_monitor_c

`endif //__CSI_EXT_MONITOR_SV__
