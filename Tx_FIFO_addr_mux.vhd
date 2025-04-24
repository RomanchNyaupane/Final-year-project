library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity Tx_FIFO_addr_mux is
    Port (
        TFAM_sel    : in  std_logic;  --select signal (0 or 1)
        TFAM_in0    : in  integer range 0 to 2047; --input line0
        TFAM_in1    : in  integer range 0 to 2047; --input line1
        TFAM_out_mux: out integer range 0 to 2047  --output
    );
end Tx_FIFO_addr_mux;

architecture rtl of Tx_FIFO_addr_mux is
begin
    process (TFAM_sel, TFAM_in0, TFAM_in1)
    begin
        if TFAM_sel = '0' then
            TFAM_out_mux <= TFAM_in0;
        else
            TFAM_out_mux <= TFAM_in1;
        end if;
    end process;
end rtl;
