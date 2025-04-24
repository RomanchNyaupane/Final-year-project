library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity Tx_FIFO_data_mux is
    Port (
        TFDM_sel    : in  std_logic_vector(1 downto 0);  
        TFDM_in0    : in  std_logic_vector(7 downto 0); 
        TFDM_in1    : in  std_logic_vector(7 downto 0); 
        TFDM_in2    : in  std_logic_vector(7 downto 0); 
        TFDM_out_mux: out std_logic_vector(7 downto 0)  
    );
end Tx_FIFO_data_mux;

architecture rtl of Tx_FIFO_data_mux is
begin
    process (TFDM_sel, TFDM_in0, TFDM_in1, TFDM_in2)
    begin
        case TFDM_sel is
            when "00"   => TFDM_out_mux <= TFDM_in0;
            when "01"   => TFDM_out_mux <= TFDM_in1;
            when "10"   => TFDM_out_mux <= TFDM_in2;
            when others => TFDM_out_mux <= (others => '0'); 
        end case;
    end process;
end rtl;
