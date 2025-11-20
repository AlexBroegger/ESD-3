library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity RX is

    port(
    clk: in std_logic;
    reset: in std_logic;
    rx_line: in std_logic;

    );

end RX;


architecture rtl of RX is
    -- States
    TYPE Tstate IS (IDLE,START,DATA,PARITY,STOP); -- Vi ved ikke om incoming har parity eller ikke, derfor det er inkluderet i RX, men ikke TX
    SIGNAl state: Tstate;
    SIGNAL next_state: Tstate;


    -- Shift register (gemme kommende på tx linje)
    signal shift_reg: unsigned (7 downto 0); -- Umiddelbart lige 8 bits til at starte med, men den skal være mulig at konfiguere 8-n-1 er standard uart data frame
    signal bit_count: integer range 0 to 7; -- Se overstående

    -- Klok signaler og konstanter
    constant oversampling: integer := 78; -- Vi har vores baud rate 9600, som har en clock_p_bit hvert 1250, så med 16x oversampling, må det være 1250/16=78,125
    signal os_count : integer range 0 to oversampling-1;
    signal os_tick : std_logic;
    signal os_reset : std_logic; 

begin

end rtl;