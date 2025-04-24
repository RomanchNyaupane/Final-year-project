library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity Frame_Assm_addr_demux is
    Port (
        sel    : in  std_logic;  --select signal (0 or 1)
        in_data: in  integer range 0 to 2047; --input
        out0   : out integer range 0 to 2047; --output line 0
        out1   : out integer range 0 to 2047  --output line 1
    );
end Frame_Assm_addr_demux;

architecture rtl of Frame_Assm_addr_demux is
begin
    process (sel, in_data)
    begin
        if sel = '0' then
            out0 <= in_data; 
            
        else
            out1 <= in_data; 
        end if;
    end process;
end rtl;
