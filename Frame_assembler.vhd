library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity Frame_assembler is
port(
    --frame assembler will be responsible for writing preambles and sfd. it will then trigger other modules to write on tx module and provides address to these modules
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
    
    switch_address_mux :  out std_logic; --change selection of frame_assm_address_demux(mux written here)
    
    assm_start : in std_logic; --start frame assembly(from tx controller)
    assm_start_ack : out std_logic; --send frame assembly acknowledgement to tx controller
    
    preamble_end : out std_logic; --send to tx controller
    SFD_end : out std_logic; --send to tx controller
    DEST_MAC_end : out std_logic; --destination mac over
    MAC_over : out std_logic; --send to tx controller(source mac over)
    length_over : out std_logic; --send to tx controller
    payload_over : out std_logic; --send to tx controller
    
    crc_over : out std_logic; --send to tx controller
    
    --crc_start: out std_logic; --starts embedding crc in the frame.
    --crc_start_ack : in std_logic;
    
    crc_complete : in std_logic
    --based on these signals, the tx controller modifies select lines in mux, updates status register, etc
    );
end Frame_assembler;

architecture rtl of Frame_assembler is
signal tx_fifo_address_pointer : integer range 0 to 2047;
signal input_fifo_address_pointer : integer range 0 to 2047;

signal ethertype_byte_counter : integer range 0 to 5;
signal payload_byte_counter : integer range 0 to 50;

signal payload_phase : std_logic := '0';  -- '0'=input phase, '1'=write phase

signal mac_byte_counter : integer range 0 to 5 := 0;

--wait logic signals
signal ether_payload_wait : std_logic := '0';
signal mac_xfer_active : std_logic := '0'; 
signal preamble_wait : std_logic := '0';
signal sfd_wait : std_logic := '0';

  type t_state is (
    IDLE,
    PREAMBLE,
    SFD,
    DEST_MAC,
    SRC_MAC,
    ETHERTYPE,
    PAYLOAD,
    WAIT_CRC,
    DONE
  );
  signal state : t_state := IDLE;
  
begin

process(clk)
begin
--crc_over <= '0';

    if rising_edge(clk) then
        
        --fifo_data_ready <= '0';
        --mac_tx_req <= '0';
        preamble_end <= '0';
        SFD_end <= '0';
        DEST_MAC_end <= '0';
        MAC_over <= '0';
        length_over <= '0';
        payload_over <= '0';
        crc_over <= '0';
        
        mac_tx_req <= '0';
        mac_tx_complete_ack <= '0';

        
        assm_start_ack <= '0';
        
        tx_fifo_data_ready   <= '0';
        tx_fifo_write_en     <= '0';
        tx_fifo_address_valid<= '0';
        
        
        case state is
        
        when IDLE =>
            tx_fifo_address_pointer <= 0;
            mac_byte_counter <= 0;
            input_fifo_address_pointer <= 0;
            
            if assm_start = '1' then
                state <= PREAMBLE;
                assm_start_ack <= '1';
            end if;
            
            
            
            
            
           when PREAMBLE =>

                tx_fifo_data_ready   <= '0';       -- Deassert request by default
                tx_fifo_address_valid<= '0';       -- Address invalid until ready
                data_out             <= x"55";     -- Preamble byte
                address_out          <= tx_fifo_address_pointer;  --drive address continuously
            
                --handshake(1-cycle gap between request and ack)
                if preamble_wait = '0' then
                    -- Phase 1: Request data (assert ready and address valid)
                    tx_fifo_data_ready    <= '1';  -- Request data
                    tx_fifo_write_en     <= '0';
                    tx_fifo_address_valid <= '1';  -- Address is now valid
                    preamble_wait         <= '1';  -- Wait for ack
                else
                    -- Check acknowledgment
                    if tx_fifo_data_ready_ack = '1' then
                        -- Write data to FIFO
                        tx_fifo_write_en  <= '1';  -- Latch data_out into FIFO
                        tx_fifo_address_pointer <= tx_fifo_address_pointer + 1;  -- Next address
                        tx_fifo_address_valid <= '0';  -- Invalidate address after use
                    preamble_wait         <= '0';  -- Reset for next byte
                    end if;
                    
                end if;
            
                -- Preamble termination check
                if tx_fifo_address_pointer = 6 then
                    preamble_end <= '1';
                    if change_state = '1' then
                        preamble_end <= '0';
                        state <= SFD;
                    end if;
                end if;
            
                when SFD =>
                    --preamble_end <= '0';
                    -- Default outputs (safe defaults)
                    tx_fifo_data_ready    <= '0';       -- Deassert request by default
                    tx_fifo_address_valid <= '0';       -- Address invalid until ready
                    data_out              <= x"D5";     -- SFD byte (constant)
                    address_out           <= tx_fifo_address_pointer;  -- Drive address continuously
                
                    -- Handshake FSM (1-cycle gap between request and ack)
                    if sfd_wait = '0' then
                        -- request data (assert ready and address valid)
                        tx_fifo_data_ready    <= '1';   -- Request data
                        tx_fifo_write_en <= '0';
                        tx_fifo_address_valid <= '1';   -- Address is now valid
                        sfd_wait              <= '1';   -- Wait for ack
                    else
                        --Check acknowledgment
                        if tx_fifo_data_ready_ack = '1' then
                            tx_fifo_write_en  <= '1';   -- Latch data_out into FIFO
                            tx_fifo_address_pointer <= tx_fifo_address_pointer + 1; -- Next address
                            tx_fifo_address_valid <= '0';
                            --sfd_wait              <= '0';
                            -- State transition
                            SFD_end <= '1';
                        end if;
                           -- Reset for next operation
                    end if;
                    if change_state = '1' then
                            sfd_wait <= '0';
                            SFD_end <= '0';
                            state <= DEST_MAC;
                    end if;

                when DEST_MAC =>
                    -- Default outputs
                    tx_fifo_data_ready <= '0';
                    --mac_tx_req <= '1';
                    tx_fifo_address_valid <= '0';
                    address_out <= tx_fifo_address_pointer;
                    
                    -- MAC interface control
                    if mac_xfer_active = '0' then
                        -- Start new byte transfer
                        mac_tx_req <= '1';
                        tx_fifo_data_ready <= '1';
                        tx_fifo_write_en <= '0';
                        tx_fifo_address_valid <= '1';
                        mac_xfer_active <= '1';
                    else
                    if tx_fifo_data_ready_ack = '1' then
                        tx_fifo_write_en <= '1';
                        tx_fifo_address_valid <= '0';
                        --mac_tx_req <= '0';
                        tx_fifo_address_pointer <= tx_fifo_address_pointer + 1;
                        mac_byte_counter <= mac_byte_counter + 1;
                        mac_xfer_active <= '0';
                    end if;
                    end if;
                        
                if mac_byte_counter = 5 then
                    -- Last byte of DEST MAC
                    DEST_MAC_end <= '1';
                    mac_tx_req <= '0';
                    mac_xfer_active <= '0';
                    if change_state = '1' then
                        DEST_MAC_end <= '0';
                        state <= SRC_MAC;
                    end if;
                end if;
                
                when SRC_MAC =>
                    -- Same structure as DEST_MAC
                    tx_fifo_data_ready <= '0';
                    --mac_tx_req <= '1';
                    tx_fifo_address_valid <= '0';
                    address_out <= tx_fifo_address_pointer;
                    
                    if mac_xfer_active = '0' then
                        mac_tx_req <= '1';
                        tx_fifo_data_ready <= '1';
                        tx_fifo_write_en <= '0';
                        tx_fifo_address_valid<= '1';
                        mac_xfer_active <= '1';
                    else
                     if tx_fifo_data_ready_ack = '1' then
                        tx_fifo_write_en <= '1';
                        tx_fifo_address_valid <= '0';
                        mac_tx_req <= '0';
                        tx_fifo_address_pointer <= tx_fifo_address_pointer + 1;
                        mac_byte_counter <= mac_byte_counter + 1;
                        mac_xfer_active <= '0';
                      end if;
                    end if;
                        
                        if mac_byte_counter = 11 then
                            -- Last byte of SRC MAC
                            mac_tx_complete_ack <= '1';
                            MAC_over <= '1';                            
                            mac_xfer_active <= '0';
                            if change_state = '1' then
                                state <= ETHERTYPE;
                                switch_address_mux <= '1';
                            end if;
                        end if;
                    
                    
            when ETHERTYPE =>
                -- Default outputs
                tx_fifo_data_ready <= '0';
                input_fifo_data_ready <= '0';
                tx_fifo_address_valid <= '0';
                input_fifo_address_valid <= '0';
                input_fifo_read_en <= '0';
                switch_address_mux <= '0';
                length_over <= '0';
                  -- Default to TX FIFO path
                
                if ether_payload_wait = '0' then
                switch_address_mux <= '0';
                    tx_fifo_data_ready <= '1';
                    input_fifo_data_ready <= '1';
                    tx_fifo_write_en <= '0';
                    tx_fifo_address_valid <= '1';
                    address_out <= tx_fifo_address_pointer;
                    ether_payload_wait <= '1';
                else
                        if input_fifo_data_ready_ack = '1' and tx_fifo_data_ready_ack = '1' then
                            switch_address_mux <= '1';
                            tx_fifo_address_valid <= '0';
                            tx_fifo_address_pointer <= tx_fifo_address_pointer +1;
                            input_fifo_address_valid <= '1';
                            address_out <= input_fifo_address_pointer;
                            input_fifo_read_en <= '1';
                            tx_fifo_write_en <= '1';
                            ether_payload_wait <= '0';
                            ethertype_byte_counter <= ethertype_byte_counter + 1;
                        end if;
                        end if;
                        
                        if ethertype_byte_counter = 2 then
                        length_over <= '1';
                        ether_payload_wait <= '0';
                        if change_state = '1' then
                        ether_payload_wait <= '0';
                            state <= PAYLOAD;
                        end if;
                        else
                        input_fifo_address_pointer <= input_fifo_address_pointer + 1;
                        
                        end if;
            
                        -- Phase 2: Set TX FIFO address and write
            
             when PAYLOAD =>
                -- Default outputs
                tx_fifo_data_ready <= '0';
                input_fifo_data_ready <= '0';
                tx_fifo_address_valid <= '0';
                input_fifo_address_valid <= '0';
                input_fifo_read_en <= '0';
                switch_address_mux <= '0';
                length_over <= '0';
                  -- Default to TX FIFO path
                
                if ether_payload_wait = '0' then
                switch_address_mux <= '0';
                    tx_fifo_data_ready <= '1';
                    input_fifo_data_ready <= '1';
                    tx_fifo_write_en <= '0';
                    tx_fifo_address_valid <= '1';
                    address_out <= tx_fifo_address_pointer;
                    ether_payload_wait <= '1';
                else
                        if input_fifo_data_ready_ack = '1' and tx_fifo_data_ready_ack = '1' then
                            switch_address_mux <= '1';
                            tx_fifo_address_valid <= '0';
                            tx_fifo_address_pointer <= tx_fifo_address_pointer +1;
                            input_fifo_address_valid <= '1';
                            address_out <= input_fifo_address_pointer;
                            input_fifo_read_en <= '1';
                            tx_fifo_write_en <= '1';
                            ether_payload_wait <= '0';
                            payload_byte_counter <= payload_byte_counter + 1;
                        end if;
                        end if;
                        
                        if payload_byte_counter = 50 then
                        payload_over <= '1';
                        ether_payload_wait <= '0';
                        if change_state = '1' then
                            state <= WAIT_CRC;
                        end if;
                        else
                        input_fifo_address_pointer <= input_fifo_address_pointer + 1;
                        end if;
            
                        -- Phase 2: Set TX FIFO address and write
                    
                    when WAIT_CRC =>
                            -- Default outputs
                           if crc_complete = '1' then
                                crc_over <= '1';
                           end if;
                            
                            if change_state = '1' then
                                crc_over <= '1';
                                state <= DONE;
                            end if;
                            
                            
                      when DONE =>
                            -- Wait for new frame assembly request
                            if assm_start = '1' then
                                state <= IDLE;
                            end if;
    
     
  end case;
  end if;          
end process;
end rtl;
