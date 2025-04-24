library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity MAC_address is
    Port (
        MAC_clk             : in  std_logic;  
        MAC_rst             : in  std_logic;  
        MAC_tx_req          : in  std_logic;  
        MAC_tx_complete_ack : in  std_logic;  
        MAC_rd_data         : out std_logic_vector(7 downto 0); 
        MAC_tx_complete     : out std_logic  
    );
end MAC_address;

architecture rtl of MAC_address is
    type mem_array is array (0 to 11) of std_logic_vector(7 downto 0);

    signal memory : mem_array := (
        x"AA", x"BB", x"CC", x"DD", x"EE", x"FF", -- Source MAC (AA:BB:CC:DD:EE:FF)
        x"11", x"22", x"33", x"44", x"55", x"66"  -- Destination MAC (11:22:33:44:55:66)
    );

    signal rd_addr     : integer range 0 to 11 := 0; 
    signal byte_count  : integer range 0 to 12 := 0; 
    signal tx_done     : std_logic := '0'; 

begin
    --read Process (updates address on tx_req)
    process (MAC_clk)
    begin
        if rising_edge(MAC_clk) then
            if MAC_rst = '1' then
                rd_addr    <= 0; 
                byte_count <= 0;
                tx_done    <= '0';
            elsif MAC_tx_req = '1' then
                rd_addr    <= (rd_addr + 1) mod 12; --increment and wrap around
                byte_count <= byte_count + 1;

                --assert tx_complete when last byte is sent
                if byte_count = 11 then
                    tx_done <= '1';
                end if;
            elsif MAC_tx_complete_ack = '1' then
                tx_done <= '0'; 
                byte_count <= 0;--reset counter for next frame
            end if;
        end if;
    end process;

    -- Read Data Output
    MAC_rd_data <= memory(rd_addr);
    MAC_tx_complete <= tx_done;

end rtl;
