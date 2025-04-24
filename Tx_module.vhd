library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity Tx_module is
    port(
    clk : in std_logic;
    Tx_module_tx_ready : in std_logic; --indicates data is written on input fifo and frame assembly should start
    Tx_module_data_in : in std_logic_vector(7 downto 0);
    Tx_module_data_out : out std_logic_vector(7 downto 0);
    Tx_module_address_in : in integer range 0 to 2047;
    Tx_module_write_en : in std_logic;
    Tx_module_read_en : in std_logic;
    reset : in std_logic
    );
end Tx_module;

architecture Structural of Tx_module is
signal input_fifo_address : integer range 0 to 2047;
signal input_fifo_data_out : std_logic_vector(7 downto 0);

--signal mac_data_out : std_logic_vector(7 downto 0);

-- signal declarations for input_fifo_address_mux
signal IFAM_sel_sig : std_logic;
signal IFAM_in0_sig : integer range 0 to 2047;
signal IFAM_in1_sig : integer range 0 to 2047;
signal IFAM_out_mux_sig : integer range 0 to 2047;

-- signal declarations for tx_fifo_data_mux
signal TFDM_sel_sig      : std_logic_vector(1 downto 0);  -- 2-bit Select signal (00, 01, 10)
signal TFDM_in0_sig      : std_logic_vector(7 downto 0); -- Input line 0
signal TFDM_in1_sig      : std_logic_vector(7 downto 0); -- Input line 1
signal TFDM_in2_sig      : std_logic_vector(7 downto 0); -- Input line 2
signal TFDM_out_mux_sig  : std_logic_vector(7 downto 0); -- Selected output

-- signal declarations for tx_fifo_address_mux
signal TFAM_sel_sig      : std_logic;  -- 1-bit Select signal 
signal TFAM_in0_sig      : integer range 0 to 2047; -- Input line 0
signal TFAM_in1_sig      : integer range 0 to 2047; -- Input line 1
signal TFAM_out_mux_sig  : integer range 0 to 2047; -- Selected output

-- signal declarations for frame_assm_address_demux
signal FAAD_sel_sig : std_logic;


-- signal declarations for frame assembler's connections
signal frame_assem_data_out             : std_logic_vector(7 downto 0);
signal frame_assem_address_out          : integer range 0 to 2047;
signal frame_assem_change_state         : std_logic;
signal frame_assem_tx_fifo_data_ready   : std_logic;
signal frame_assem_tx_fifo_data_ready_ack : std_logic;
signal frame_assem_tx_fifo_address_valid : std_logic;
signal frame_assem_tx_fifo_write_en     : std_logic;

signal frame_assem_mac_tx_req           : std_logic;
signal frame_assem_mac_tx_complete      : std_logic; --asserted by mac at last byte of mac address
signal frame_assem_mac_tx_complete_ack  : std_logic;

signal frame_assem_input_fifo_address_valid : std_logic;
signal frame_assem_input_fifo_read_en   : std_logic;
signal frame_assem_input_fifo_data_ready : std_logic;
signal frame_assem_input_fifo_data_ready_ack : std_logic;

signal frame_assem_switch_address_mux   : std_logic;

signal frame_assem_assm_start           : std_logic;
signal frame_assem_assm_start_ack       : std_logic;

signal frame_assem_DEST_MAC_end :  std_logic;
signal frame_assem_preamble_end         : std_logic;
signal frame_assem_SFD_end              : std_logic;
signal frame_assem_MAC_over             : std_logic;
signal frame_assem_length_over          : std_logic;
signal frame_assem_payload_over         : std_logic;
signal frame_assem_crc_over             : std_logic;

--crc related signals
signal crc_data_in_sig : std_logic_vector(7 downto 0);
signal crc_append_sig             : std_logic;
signal crc_append_complete_sig            : std_logic;
signal crc_append_ack_sig        : std_logic;
signal crc_data_out_sig : std_logic_vector(7 downto 0);
signal crc_out_sig : std_logic_vector(31 downto 0);


    component CRC is 
        port(
        clk         : in  std_logic;                        -- system clock
        reset       : in  std_logic;                        -- sync reset, active-high
        read_en     : in  std_logic;                        -- shared read enable from TX controller
        data_in     : in  std_logic_vector(7 downto 0);     -- byte from Tx_FIFO
        crc_append  : in  std_logic;                        -- pulse to append CRC
        data_out    : out std_logic_vector(7 downto 0);     -- goes on to PHY
        crcOut      : out std_logic_vector(31 downto 0);    -- exposes current CRC (optional)
        
        crc_append_complete: out std_logic;
        crc_append_ack : out std_logic
    );
    
    end component;
  -- Component declarations
  component Input_FIFO is
    Port (
    IF_data_in : in std_logic_vector(7 downto 0);
    IF_data_out : out std_logic_vector(7 downto 0);
    IF_address : in integer range 0 to 2047;
    IF_address_valid : in std_logic;
    
    IF_data_ready : in std_logic; --input fifo data ready check
    IF_data_ready_ack : out std_logic; --input fifo data ready acknowledgment
    
    --control ports
    IF_read_en : in std_logic; --enable before reading data
    IF_write_en : in std_logic; --enable before writing data
    IF_reset : in std_logic;
    IF_clk : in std_logic
    );
  end component;

  component Input_FIFO_addr_mux is
    Port (
        IFAM_sel    : in  std_logic;  -- Select signal (0 or 1)
        IFAM_in0    : in integer range 0 to 2047; -- Input line 0 (for user)
        IFAM_in1    : in integer range 0 to 2047; -- Input line 1 (for frame_assembler)
        IFAM_out_mux: out integer range 0 to 2047  -- Selected output
    );
  end component;

  component Tx_FIFO_data_mux is
    Port (
        TFDM_sel    : in  std_logic_vector(1 downto 0);  -- 2-bit Select signal (00, 01, 10)
        TFDM_in0    : in  std_logic_vector(7 downto 0); -- Input line 0 (to input_fifo data_out)
        TFDM_in1    : in  std_logic_vector(7 downto 0); -- Input line 1 (to mac data_out)
        TFDM_in2    : in  std_logic_vector(7 downto 0); -- Input line 2 (to frame_assembler_data_out)
        TFDM_out_mux: out std_logic_vector(7 downto 0)  -- Selected output
    );
  end component;

  component MAC_address is
    Port (
        MAC_clk             : in  std_logic;  -- Clock signal
        MAC_rst             : in  std_logic;  -- Reset signal
        MAC_tx_req          : in  std_logic;  -- Transmit request signal
        MAC_tx_complete_ack : in  std_logic;  -- Acknowledgement for tx_complete reset
        MAC_rd_data         : out std_logic_vector(7 downto 0); -- 8-bit read data
        MAC_tx_complete     : out std_logic  -- Transmission complete signal
    );
  end component;

  component Tx_FIFO is
    Port (
        data_in : in std_logic_vector(7 downto 0);
        data_out : out std_logic_vector(7 downto 0);
        address : in integer range 0 to 2047;
        address_valid : in std_logic;
        data_ready : in std_logic;          -- New signal: indicates receiver is ready
        data_ready_ack : out std_logic;     -- New signal: acknowledge data_ready
        
        read_en : in std_logic;
        write_en : in std_logic;
        reset : in std_logic;
        clk : in std_logic
    );
  end component;

  component Frame_assembler is
    Port (
        clk: in std_logic;
    
        data_out : out std_logic_vector(7 downto 0);
        address_out : out integer range 0 to 2047;
        
        change_state : in std_logic; --from tx_controller
        
        tx_fifo_data_ready : out std_logic; --check fifo buffer(tx fifo) before transmitting
        tx_fifo_data_ready_ack : in std_logic; --fifo buffer ready acknowledgement(tx_fifo)
        tx_fifo_address_valid : out std_logic; --assert valid address
        tx_fifo_write_en : out std_logic;   --
        
        mac_tx_req : out std_logic;
        mac_tx_complete : in std_logic; --asserted by mac at last byte of mac address
        mac_tx_complete_ack : out std_logic;
        
        input_fifo_address_valid : out std_logic; --
        input_fifo_read_en : out std_logic;
        input_fifo_data_ready : out std_logic;
        input_fifo_data_ready_ack : in std_logic;
        
        switch_address_mux :  out std_logic;
                
        assm_start : in std_logic; --start frame assembly(from tx controller)
        assm_start_ack : out std_logic; --send frame assembly acknowledgement to tx controller
        
        DEST_MAC_end : out std_logic;
        preamble_end : out std_logic; --send to tx controller
        SFD_end : out std_logic; --send to tx controller
        MAC_over : out std_logic; --send to tx controller
        length_over : out std_logic; --send to tx controller
        payload_over : out std_logic; --send to tx controller
        crc_over : out std_logic;
        
        crc_complete : in std_logic
    );
  end component;

  component Frame_Assm_addr_demux is
    Port (
        sel    : in  std_logic;  -- Select signal (0 or 1)
        in_data: in  integer range 0 to 2047; -- 8-bit input
        out0   : out integer range 0 to 2047; -- 8-bit output line 0 ( to input fifo's address)
        out1   : out integer range 0 to 2047  -- 8-bit output line 1 ( to tx fifo's address)
    );
    end component;
    
    component Tx_FIFO_addr_mux is
    Port (
        TFAM_sel    : in  std_logic;  -- Select signal (0 or 1)
        TFAM_in0    : in integer range 0 to 2047;
        TFAM_in1    : in  integer range 0 to 2047; -- Input line 1 (for frame_assmebler through frame assembler address demux's output)
        TFAM_out_mux: out integer range 0 to 2047  -- Selected output
    );
    end component;
    component Tx_controller is
          Port (
            clk : in std_logic;
            assm_start_ack : in std_logic;
            assm_start : out std_logic;
            
            -- Mux control lines
            sel0 : out std_logic_vector(1 downto 0); -- tx_fifo_data_mux
            sel1 : out std_logic; -- tx_fifo_address_mux
            sel2 : out std_logic; -- frame_assm_address_demux
            sel3 : out std_logic; -- input_fifo_address_mux
            
            change_state : out std_logic;
            
            -- State transition signals
            preamble_end : in std_logic;
            sfd_end : in std_logic;
            dest_mac_end : in std_logic;
            src_mac_end : in std_logic;
            ethertype_end : in std_logic;
            payload_end : in std_logic;
            crc_end : in std_logic;
            
            -- PHY interface
            --phy_tx_start : out std_logic;
            --phy_tx_ready : in std_logic;
            
            switch_address_mux : in std_logic;
            
            crc_append  : out  std_logic;
            crc_append_complete: in std_logic;
            crc_append_ack : in std_logic;
            
            
            input_fifo_tx_ready : in std_logic;
            address : integer range 0 to 2047
          );
     end component;

  
begin

  -- Component instantiations
  U1: Input_FIFO
    port map (
      IF_address           => IFAM_out_mux_sig,
      IF_data_out          => input_fifo_data_out,
      IF_data_in => Tx_module_data_in,
        IF_address_valid => frame_assem_input_fifo_address_valid,
        
        IF_data_ready => frame_assem_input_fifo_data_ready, --input fifo data ready check
        IF_data_ready_ack => frame_assem_input_fifo_data_ready_ack, --input fifo data ready acknowledgment
        
        --control ports
        IF_read_en => frame_assem_input_fifo_read_en,--enable before reading data
        IF_write_en => Tx_module_write_en, --enable before writing data
        IF_reset => reset,
        IF_clk => clk
    );

  U2: Input_FIFO_addr_mux
    port map (
      IFAM_sel    => IFAM_sel_sig,  -- Select signal (0 or 1)
      IFAM_in0    =>  Tx_module_address_in,-- Input line 0 (for user)
      IFAM_out_mux=> IFAM_out_mux_sig,
      IFAM_in1  => IFAM_in1_sig
    );

  U3: Tx_FIFO_data_mux
    port map (
      TFDM_sel             => TFDM_sel_sig,
      TFDM_in0             => input_fifo_data_out,
      TFDM_in1             => TFDM_in1_sig,
      TFDM_in2             => frame_assem_data_out,
      TFDM_out_mux            => TFDM_out_mux_sig
    );

  U4: MAC_address
    port map (
    MAC_rst => reset,
        MAC_clk => clk,
      MAC_rd_data          => TFDM_in1_sig,
      MAC_tx_req => frame_assem_mac_tx_req,
        MAC_tx_complete_ack => frame_assem_mac_tx_complete_ack,  -- Acknowledgement for tx_complete reset
        MAC_tx_complete     => frame_assem_mac_tx_complete   -- Transmission complete signal
    );


  U5: Frame_assembler
    port map (
      clk => clk,
    
        data_out => frame_assem_data_out,   --
        address_out => frame_assem_address_out, --
        
        change_state => frame_assem_change_state, --from tx_controller
        
        tx_fifo_data_ready => frame_assem_tx_fifo_data_ready,   --   --check fifo buffer(tx fifo) before transmitting
        tx_fifo_data_ready_ack => frame_assem_tx_fifo_data_ready_ack,   -- --fifo buffer ready acknowledgement(tx_fifo)
        tx_fifo_address_valid => frame_assem_tx_fifo_address_valid, -- --assert valid address
        tx_fifo_write_en => frame_assem_tx_fifo_write_en,   --  --
        
        mac_tx_req => frame_assem_mac_tx_req, --
        mac_tx_complete => frame_assem_mac_tx_complete, --asserted by mac at last byte of mac address
        mac_tx_complete_ack => frame_assem_mac_tx_complete_ack,
        
        
        input_fifo_address_valid => frame_assem_input_fifo_address_valid, --
        input_fifo_read_en => frame_assem_input_fifo_read_en,   --
        input_fifo_data_ready => frame_assem_input_fifo_data_ready, --
        input_fifo_data_ready_ack => frame_assem_input_fifo_data_ready_ack,--
        
        switch_address_mux => frame_assem_switch_address_mux,
        
        DEST_MAC_end => frame_assem_DEST_MAC_end,
        assm_start => frame_assem_assm_start, --start frame assembly(from tx controller)
        assm_start_ack => frame_assem_assm_start_ack, --send frame assembly acknowledgement to tx controller
        preamble_end => frame_assem_preamble_end, --send to tx controller
        SFD_end => frame_assem_SFD_end, --send to tx controller
        MAC_over => frame_assem_MAC_over, --send to tx controller
        length_over => frame_assem_length_over, --send to tx controller
        payload_over => frame_assem_payload_over, --send to tx controller
        crc_over => frame_assem_crc_over,

        crc_complete => crc_append_complete_sig    --
    );

  U6: Tx_FIFO
    port map (
        data_in => TFDM_out_mux_sig,
        data_out => crc_data_in_sig ,
        address => TFAM_out_mux_sig,
        address_valid => frame_assem_tx_fifo_address_valid,
        data_ready => frame_assem_tx_fifo_data_ready,        -- New signal: indicates receiver is ready
        data_ready_ack => frame_assem_tx_fifo_data_ready_ack,     -- New signal: acknowledge data_ready


        read_en => Tx_module_read_en,
        write_en => frame_assem_tx_fifo_write_en,
        reset => reset,
        clk => clk
    );

  U7: Frame_Assm_addr_demux
    port map (
            in_data => frame_assem_address_out,
            out0 => IFAM_in1_sig,
            out1 => TFAM_in1_sig,
            sel => FAAD_sel_sig
            
            
    );
    
   U8: Tx_FIFO_addr_mux
    Port map(
        TFAM_sel    => TFAM_sel_sig,  -- Select signal (0 or 1)
        TFAM_in0    =>  Tx_module_address_in,
        TFAM_in1    =>  TFAM_in1_sig,   -- Input line for frame_assembler
        TFAM_out_mux =>   TFAM_out_mux_sig
    );
    
   U9 : Tx_controller
   port map(
            clk => clk,
            assm_start_ack => frame_assem_assm_start_ack,
            assm_start => frame_assem_assm_start,
            
            -- Mux control lines
            sel0 => TFDM_sel_sig,
            sel1 => TFAM_sel_sig,
            sel2 => FAAD_sel_sig,
            sel3 => IFAM_sel_sig,
            
            change_state => frame_assem_change_state,
            
            -- State transition signals
            preamble_end => frame_assem_preamble_end,
            sfd_end => frame_assem_sfd_end,
            dest_mac_end => frame_assem_DEST_MAC_end,
            src_mac_end => frame_assem_mac_over,
            ethertype_end => frame_assem_length_over,
            payload_end => frame_assem_payload_over,
            crc_end => frame_assem_crc_over,
            
            -- PHY interface
            --phy_tx_start : out std_logic;
            --phy_tx_ready : in std_logic;
            
            switch_address_mux => frame_assem_switch_address_mux,
            
            
            input_fifo_tx_ready => Tx_module_tx_ready,
            address => TFAM_in0_sig,
            
            crc_append  => crc_append_sig,
    crc_append_complete => crc_append_complete_sig,
        crc_append_ack => crc_append_ack_sig
   
   );
   U10: CRC
        port map(
        clk         => clk,                       -- system clock
        reset       => reset,                        -- sync reset, active-high
        read_en     => Tx_module_read_en,                        -- shared read enable from TX controller
        data_in     => crc_data_in_sig ,     -- byte from Tx_FIFO

        crc_append  => crc_append_sig,                       -- pulse to append CRC
        data_out    => Tx_module_data_out,     -- goes on to PHY
        crcOut      => crc_out_sig,    -- exposes current CRC (optional)
        crc_append_complete =>crc_append_complete_sig,
        crc_append_ack => crc_append_ack_sig
    );

end Structural;