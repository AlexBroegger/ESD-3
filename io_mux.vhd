-- Fil: io_mux.vhd (STASTISK GRÆNSELOGIK)
-- Statisk component for IO selection logik, da det ikke virker inde i dynamiske regioner.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VComponents.all; -- Inkluderer IOBUF primitive: UBRUGT

entity io_mux is
    Port (
        -- Ekstern I/O (Systemets fysiske pin)
        u_pin_io : inout STD_LOGIC_VECTOR(7 downto 0);
        
        -- Grænseflade til den Dynamiske Region (RP)
        rp_data_o : in  STD_LOGIC_VECTOR(7 downto 0);  -- Data ud fra RP (RM_DATA_OUT)
        rp_oe_o   : in  STD_LOGIC_VECTOR(7 downto 0);  -- Output Enable ud fra RP (RM_OE)
        rp_data_i : out STD_LOGIC_VECTOR(7 downto 0)   -- Data ind til RP (RM_DATA_IN)
    );
end io_mux;

architecture Behavioral of io_mux is

begin


G_TRI_STATE_LOGIC: for i in 7 downto 0 generate
    u_pin_io(i) <= rp_data_o(i) when rp_oe_o(i) = '1' else 'Z';
end generate G_TRI_STATE_LOGIC;

    -- Forbind den dedikerede inputbus tilbage til RP'et
rp_data_i <= u_pin_io; -- Tildeler alle rp_data_i(i) til alle u_pin_io(i), simpel tilskrivning her da vi ikke har brug for output-enable logik for inputs

end Behavioral;