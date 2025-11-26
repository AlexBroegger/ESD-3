-- Fil: reconfig_interface.vhd (Bus Macro Shell)
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM; -- Tilføj dette
use UNISIM.VComponents.all; -- Tilføj dette

entity reconfig_interface is
    Port (
        clk      : in  STD_LOGIC;
        reset_n  : in  STD_LOGIC; -- Aktiv Lav Reset
        
        -- Kontrolporte (til/fra projFSM via DFX Controller)
        reconfig_i : in  STD_LOGIC_VECTOR(1 downto 0); -- FSM Output (e.g., START_CMD)
        reconfig_o : out STD_LOGIC_VECTOR(1 downto 0); -- FSM Input (e.g., TEST_RESULT)
        
        -- Ekstern I/O (den fysiske pin, der skifter funktion)
        -- u_pin_io : inout STD_LOGIC_VECTOR(7 downto 0);
        
        -- RM Data Porte (Disse porte forbinder RM'et til Tri-State logikken)
        -- Buffers anvendes for tri-state logik
        RM_DATA_OUT : out STD_LOGIC_VECTOR(7 downto 0); -- Output data fra RM
        RM_OE       : out STD_LOGIC_VECTOR(7 downto 0); -- Output Enable fra RM
        RM_DATA_IN  : in  STD_LOGIC_VECTOR(7 downto 0)  -- Input data til RM
    );
end reconfig_interface;

architecture Shell of reconfig_interface is


begin
    

    
end Shell;