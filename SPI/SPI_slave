----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 25.11.2025 13:53:39
-- Design Name: 
-- Module Name: SPI_slave - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;
-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity SPI_slave is
  Port ( 
  --SPI INTERFACE
  SCLK: in std_logic;   -- SCLK input pin
  MOSI: in std_logic;   -- MOSI input pin
  MISO: out std_logic;  -- MISO output line
  CS: in std_logic      -- CS input line
 
  
  );
end SPI_slave;

architecture Behavioral of SPI_slave is

    -- SCLK domain signals
    signal MOSI_shift_reg: std_logic_vector(7 downto 0) := (others => '0'); -- Use for sampling data
    
    signal SPI_byte_ready: std_logic_vector(7 downto 0); -- holds data in SCLK DOMAIN
    signal SPI_byte_meta: std_logic_vector(7 downto 0); -- Meta block
    signal SPI_byte_sys: std_logic_vector(7 downto 0); -- holds data in Clock domain
    
    signal bit_count: integer range 0 to 7 := 0; -- Keeps track of how many bits have been input in shift reg
    
    signal byte_ready_sclk : std_logic := '0'; -- Flag telling when byte is ready to sync

begin

-- Eventhandeling of SCLK and CS line
    process(SCLK, CS)
    begin
           
         if CS = '1' then     
        -- If CS line is high then no communication is happening
        -- If CS goes high then communication must sieze
            bit_count       <= 0;
            byte_ready_sclk <= '0';


        elsif rising_edge(SCLK) then
            -- Sample MOSI and insert into shift register
            MOSI_shift_reg <= MOSI_shift_reg(7 downto 0) & MOSI;
            
            -- When a byte is ready, flag as ready
            if bit_count = 7 then
                -- Copy out the completed byte
                SPI_byte_ready  <= MOSI_shift_reg(7 downto 0) & MOSI;
                -- Pulse the flag
                byte_ready_sclk <= '1';
                bit_count       <= 0;
        
            else 
                byte_ready_sclk <= '0';
                bit_count       <= bit_count + 1; 
            end if;
        end if;

     

    end process;

    -- Byte SYNC
    process(Mosi_shift_reg)
    begin
    
        if byte_ready_sclk = '1' then
           -- Take bits from MOSI_shift_reg and sync to an output shift register, which can be safely read.
           -- Using as double flip-flop synch for each bite
            SPI_byte_meta <= SPI_byte_ready;
            SPI_byte_sys <= SPI_byte_meta; 
        end if;
    
    end process;
end Behavioral;
