library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity Tx_controller is
  Port (
    clk : in std_logic;
    assm_start_ack : in std_logic;
    assm_start : out std_logic;
    
    --Mux control lines
    sel0 : out std_logic_vector(1 downto 0); -- tx_fifo_data_mux
    sel1 : out std_logic; -- tx_fifo_address_mux
    sel2 : out std_logic; -- frame_assm_address_demux
    sel3 : out std_logic; -- input_fifo_address_mux
    
    change_state : out std_logic;
    
    --State transition signals
    preamble_end : in std_logic;
    sfd_end : in std_logic;
    dest_mac_end : in std_logic;
    src_mac_end : in std_logic;
    ethertype_end : in std_logic;
    payload_end : in std_logic;
    crc_end : in std_logic;
    
    --PHY interface
    --phy_tx_start : out std_logic;
    --phy_tx_ready : in std_logic;
    
    switch_address_mux : in std_logic;
    
    
    input_fifo_tx_ready : in std_logic;
    address : integer range 0 to 2047;
    
    
    --crc pins
    crc_append  : out  std_logic;
    crc_append_complete: in std_logic;
    crc_append_ack : in std_logic
  );
end Tx_controller;

architecture rtl of Tx_controller is

    signal assm_running : std_logic:= '0';
    
    signal preamble_running : std_logic:= '0';
    signal sfd_running : std_logic:= '0';
    signal dest_mac_running : std_logic:= '0';
    signal src_mac_running : std_logic:= '0';
    signal ethertype_running : std_logic:= '0';
    signal payload_running : std_logic:= '0';
    signal crc : std_logic:= '0';
    --edge detection signals
begin

process(clk)
begin
    if rising_edge(clk) then
        change_state <= '0';
        assm_start <= '0';
       --phy_tx_start <= '0';

                if input_fifo_tx_ready = '1' and assm_running = '0' then
                    assm_start <= '1';
                    assm_running <= '1';
                    preamble_running <= '1';
                    -- Initialize all muxes
                    sel0 <= "10"; -- Frame assembler data
                    sel1 <= '1';  -- Frame assembler address
                    sel2 <= '1';  -- Input FIFO address path
                    sel3 <= '1';  -- Payload address
                end if;
                
           --PREAMBLE =>
                if  preamble_end = '1' and preamble_running = '1' then
                    change_state <= '1';
                    preamble_running <= '0';
                    sfd_running <= '1';
                end if;
                
           
                if sfd_end = '1' and sfd_running = '1' then
                    change_state <= '1';
                    sfd_running <= '0';
                    dest_mac_running <= '1';
                    sel0 <= "01"; -- MAC data
                end if;
                
            --DEST_MAC =>
                if dest_mac_end = '1' and dest_mac_running = '1' then
                    change_state <= '1';
                    dest_mac_running <= '0';
                    src_mac_running <= '1';
                end if;
                
            --SRC_MAC =>
                if src_mac_end = '1' and src_mac_running ='1' then
                    change_state <= '1';
                    src_mac_running <= '0';
                    ethertype_running <= '1';
                    sel0 <= "00"; -- Frame assembler data
                    sel2 <= '1';  -- Input FIFO address
                    sel3 <= '1';  -- Ethertype address
                end if;
                
            --ETHERTYPE =>
            if ethertype_running = '1' then
            
                if switch_address_mux = '1' then
                        sel2 <= '0';  -- When Frame_assembler wants input FIFO path
                    else
                        sel2 <= '1';  -- Default to TX FIFO path
                    end if;
                end if;
                
                if ethertype_running = '1' and ethertype_end = '1' then
                    change_state <= '1';
                    ethertype_running <= '0';
                    payload_running <= '1';
                     sel3 <= '0';
                end if;
                
                
                if payload_running = '1' then
            
                if switch_address_mux = '1' then
                        sel2 <= '0';  -- When Frame_assembler wants input FIFO path
                    else
                        sel2 <= '1';  -- Default to TX FIFO path
                    end if;
                end if;
                
                if payload_running = '1' and payload_end = '1' then
                    change_state <= '1';
                    ethertype_running <= '0';
                    payload_running <= '1';
                     sel3 <= '0';
                end if;
                

                
            --when FCS =>
                if crc_end = '1' then
                    change_state <= '1';
                end if;
               
        
        -- Clear assm_start after acknowledgment
        if assm_start_ack = '1' then
            assm_start <= '0';
        end if;
    end if;
end process;


end rtl;