----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 21.10.2025 11:50:01
-- Design Name: 
-- Module Name: top - Behavioral
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
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity top is
    Port ( 
           -- Protokol input
           I2C_ACK : in STD_LOGIC;
           I2C_NACK : in STD_LOGIC;
           SPI_ID_VALID : in STD_LOGIC;
           UART_PONG : in STD_LOGIC;
           -- System kontrol
           clk : in STD_LOGIC; -- system clock, nok omkring 10ns
           DEVICE_PRESENT : in STD_LOGIC; -- Frakoblings-detektion pin sat til pull up resistor, sat til GND af forbundet enhed
           rst : in STD_LOGIC;
           -- Pin konfigurering: 00 = højimpedans, 01 = I2C, 10 = SPI, 11 = UART
           MUX_SELECT : out STD_LOGIC_VECTOR(1 downto 0);
           -- Universal pins
           U_Pin_1 : inout STD_LOGIC; 
           U_Pin_2 : inout STD_LOGIC;
           U_Pin_3 : inout STD_LOGIC;
           U_Pin_4 : inout STD_LOGIC
           );
end top;

architecture Behavioral of top is

-- I2C ting
-- KONSTANTER FOR KOMMUNIKATION
CONSTANT C_SYS_CLK_HZ : INTEGER := 100_000_000; -- Antager 100 MHz system clock, da clk er 10ns (1/(10e-9) = 100 MHz)
CONSTANT C_I2C_BUS_HZ : INTEGER := 400_000;    -- I2C Fast Mode hastighed (400 kHz)
CONSTANT C_TEST_I2C_ADDR : STD_LOGIC_VECTOR(6 DOWNTO 0) := "1010000"; -- Testadresse (eksempel: 0x50/80 decimal)

-- I2C KONTROL- OG DATA-SIGNALER
signal I2C_MASTER_BUSY : STD_LOGIC := '0';
signal I2C_MASTER_ACK_ERROR : STD_LOGIC := '0'; -- '1' = NACK (fejl), '0' = ACK (succes)
signal I2C_TX_DATA : STD_LOGIC_VECTOR(7 DOWNTO 0) := X"00"; -- Dummy data for WRITE test



-- State Machine
type fsm_state_type is (IDLE, TEST_I2C, TEST_SPI, TEST_UART, ACTIVE_I2C, ACTIVE_SPI, ACTIVE_UART);
signal state_reg, state_next, state_prev : fsm_state_type := IDLE;

-- Selection Logik
signal MUX_SELECT_SIGNAL : STD_LOGIC_VECTOR(1 downto 0);
-- I2C (bliver mappet til I2C component outputs)
signal I2C_SDA_SIGNAL : STD_LOGIC;
signal I2C_SCL_SIGNAL : STD_LOGIC; 
-- SPI (bliver mappet til SPI component outputs)
signal SPI_SCLK_SIGNAL : STD_LOGIC;
signal SPI_MISO_SIGNAL : STD_LOGIC;
signal SPI_MOSI_SIGNAL : STD_LOGIC;
signal SPI_SS_SIGNAL : STD_LOGIC;
-- UART (bliver mappet til UART component outputs)
signal UART_RX_SIGNAL : STD_LOGIC;
signal UART_TX_SIGNAL : STD_LOGIC;

-- Protokol Kommandoer (kobles til components)
signal I2C_START_CMD : STD_LOGIC;
signal SPI_START_CMD : STD_LOGIC;
signal UART_START_CMD : STD_LOGIC;

-- Timing (lidt arbitrært valgte værdier)
constant I2C_TIMEOUT_MAX : natural := 10000; -- med 10ns clk -> 100us
constant SPI_TIMEOUT_MAX : natural := 5000; -- med 10ns clk -> 50us
constant UART_TIMEOUT_MAX : natural := 100000; -- med 10ns clk -> 1ms [afhænger af UART detektion, i.e hvilket signal, 1ms er ikke sikker på]

signal timeout_counter : natural range 0 to  UART_TIMEOUT_MAX :=0; -- Range sat til største timeout konstant, synthesizer til logic vector af krævet bits
signal timeout_expired : std_logic := '0';



begin

-- -----------------------------------------------------------------
-- I2C MASTER INSTANSIERING (Modul 2)
-- -----------------------------------------------------------------
I2C_MASTER_INST : ENTITY WORK.i2c_master
GENERIC MAP(
    input_clk => C_SYS_CLK_HZ, -- 100 MHz
    bus_clk   => C_I2C_BUS_HZ  -- 400 kHz
)
PORT MAP(
    clk => clk,
    reset_n => NOT rst,           -- I2C modulet bruger aktiv lav reset (reset_n)
    ena => I2C_START_CMD,         -- Puls fra Top-FSM til at starte transaktion
    addr => C_TEST_I2C_ADDR,      -- Adresse til at teste
    rw => '0',                    -- Sæt til '0' (WRITE) for kun at tjekke ACK
    data_wr => I2C_TX_DATA,       -- Dummy data (bruges kun til WRITE)
    busy => I2C_MASTER_BUSY,      -- Master er i gang
    data_rd => open,              -- Vi læser ikke data, så vi lader den være åben
    ack_error => I2C_MASTER_ACK_ERROR, -- VIGTIGT: Resultat af adresse-ACK
    sda => I2C_SDA_SIGNAL,        -- SDA signal
    scl => I2C_SCL_SIGNAL         -- SCL signal
);

-- State Register
process(clk, rst)
begin 
    if (rst = '1') or DEVICE_PRESENT = '1' then -- asynkron reset eller hardware disconnect
        state_reg <= IDLE;
        timeout_counter <= 0;
        timeout_expired <= '0';
     elsif rising_edge(clk) then
        state_prev <= state_reg;
        state_reg <= state_next;   
    
     -- Synkron timeout tæller for test-states    
     if (state_prev /= state_reg) and (state_reg = TEST_I2C or state_reg = TEST_SPI or state_reg = TEST_UART) then -- reset på overgang af state
            timeout_counter <= 0;
            timeout_expired <= '0';
            
     -- I individuelle test-states
     elsif state_reg = TEST_I2C then
        if timeout_counter < I2C_TIMEOUT_MAX then 
            timeout_counter <= timeout_counter + 1;
            timeout_expired <= '0';
        else 
            timeout_expired <= '1';
        end if;
        
     elsif state_reg = TEST_SPI then
        if timeout_counter < SPI_TIMEOUT_MAX then 
            timeout_counter <= timeout_counter + 1;
            timeout_expired <= '0';
        else 
            timeout_expired <= '1';
        end if;
        
     elsif state_reg = TEST_UART then
        if timeout_counter < UART_TIMEOUT_MAX then 
            timeout_counter <= timeout_counter + 1;
            timeout_expired <= '0';
        else 
            timeout_expired <= '1';
        end if;
     
     -- Reset hvis aktiv state
     else 
        timeout_counter <= 0;
        timeout_expired <= '0';
     end if;
   end if;
end process;


-- Next-state logic
process(state_reg, clk)
begin
    case state_reg is
        when IDLE => 
            state_next <= TEST_I2C;
        
        when TEST_I2C =>
            if I2C_MASTER_BUSY = '0' then
                if I2C_MASTER_ACK_ERROR = '0' then
                    state_next <= ACTIVE_I2C;
                elsif I2C_MASTER_ACK_ERROR = '1' or timeout_expired = '1' then
                    state_next <= TEST_SPI;            
                else
                    state_next <= TEST_SPI; -- fallback
                end if;
                    
            else -- hvis ikke busy
                state_next <= TEST_I2C;
            end if;
                    
--            if I2C_ACK = '1' then
--                state_next <= ACTIVE_I2C;
--            elsif I2C_NACK = '1' or timeout_expired = '1' then
--                state_next <= TEST_SPI;
--            else 
--                state_next <= TEST_I2C;
--            end if;

        when TEST_SPI =>
            if SPI_ID_VALID = '1' then
                state_next <= ACTIVE_SPI;
            elsif SPI_ID_VALID = '0' or timeout_expired = '1' then
                state_next <= TEST_UART;
            else
                state_next <= TEST_SPI;
            end if;


         when TEST_UART =>
            if UART_PONG = '1' then
                state_next <= ACTIVE_UART;
            elsif timeout_expired = '1' then
                state_next <= IDLE;
            else 
                state_next <= TEST_UART;
            end if;


        when ACTIVE_I2C | ACTIVE_SPI | ACTIVE_UART =>
                state_next <= state_reg;
    
        when others =>
            state_next <= IDLE;
    end case;
end process;

-- Mealy Output Logic
process(state_reg)
begin

    I2C_START_CMD <= '0';
    SPI_START_CMD <= '0';
    UART_START_CMD <= '0';

    MUX_SELECT <= "00";
    
    case state_reg is
        when IDLE =>
            MUX_SELECT_SIGNAL <= (others => 'Z');
        
        when TEST_I2C =>
            MUX_SELECT_SIGNAL <= "01";
            I2C_START_CMD <= '1';

        when ACTIVE_I2C =>
            MUX_SELECT_SIGNAL <= "01";
        
        when TEST_SPI => 
            MUX_SELECT_SIGNAL <= "10";
            SPI_START_CMD <= '1';

        when ACTIVE_SPI =>
            MUX_SELECT_SIGNAL <= "10";            

        when TEST_UART =>
            MUX_SELECT_SIGNAL <= "11";
            UART_START_CMD <= '1';
            
        when ACTIVE_UART =>
            MUX_SELECT_SIGNAL <= "11";
   
    end case;    

end process;

-- MUX Selection
process(MUX_SELECT_SIGNAL,U_Pin_1, U_Pin_2, U_Pin_3, U_Pin_4)
begin

    case MUX_SELECT_SIGNAL is
    
        -- Idle
        when "00" =>
            U_Pin_1 <= 'Z';
            U_Pin_2 <= 'Z';
            U_Pin_3 <= 'Z';
            U_Pin_4 <= 'Z';
            
        -- I2C
        when "01" =>
            U_Pin_1 <= I2C_SCL_SIGNAL;
            U_Pin_2 <= I2C_SDA_SIGNAL;
            U_Pin_3 <= 'Z';
            U_Pin_4 <= 'Z';
            
        -- SPI
        when "10" =>
            U_Pin_1 <= SPI_SCLK_SIGNAL;
            U_Pin_2 <= SPI_MISO_SIGNAL;
            U_Pin_3 <= SPI_MOSI_SIGNAL;
            U_Pin_4 <= SPI_SS_SIGNAL;
           
        -- UART
        when "11" =>
            U_Pin_1 <= 'Z';
            U_Pin_2 <= UART_TX_SIGNAL;
            U_Pin_3 <= UART_RX_SIGNAL;
            U_Pin_4 <= 'Z';     
   
when others =>
null;

    end case;

end process;

end Behavioral;
