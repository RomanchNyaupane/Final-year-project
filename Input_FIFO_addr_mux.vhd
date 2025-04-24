library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity Input_FIFO_addr_mux is
    Port (
        IFAM_sel    : in  std_logic; 
        IFAM_in0    : in  integer range 0 to 2047; -
        IFAM_in1    : in  integer range 0 to 2047; 
        IFAM_out_mux: out integer range 0 to 2047  
    );
end Input_FIFO_addr_mux;

architecture rtl of Input_FIFO_addr_mux is
begin
    process (IFAM_sel, IFAM_in0, IFAM_in1)
    begin
        if IFAM_sel = '0' then
            IFAM_out_mux <= IFAM_in0;
        else
            IFAM_out_mux <= IFAM_in1;
        end if;
    end process;
end rtl;
