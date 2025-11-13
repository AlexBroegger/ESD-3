library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity TX is

	port (
	clk : in std_logic;
	reset : in std_logic;
	data_available : in std_logic;
	tx_line : out std_logic;
	tx_data : in unsigned(7 downto 0);
	tx_busy : out std_logic
	);
	
end TX;

architecture rtl of TX is

	-- Defintion af States
	TYPE Tstate IS (IDLE, START, DATA, STOP); -- States: Intet parity, 1 stop bit og 8 data bits.
	SIGNAL state: Tstate;
	SIGNAL next_state: Tstate;
	
	-- Signaler til at shifte bits ud til tx_linje, og tælle dem
	SIGNAL shift_reg: unsigned(7 downto 0); 
	SIGNAL bit_count: integer range 0 to 7; -- Counter til state transition
	
	-- Klok signaler
	constant clock_p_bit : integer := 1250; --12000000/9600 = 12MHz/9600 baud rate = 1250
	signal baud_count : integer range 0 to clock_p_bit-1: -- Baud counter, som bruges til at tælle op til 1249
	signal baud_tick : std_logic; -- Når baud counter kommer op til 1250, bliver baud_tick slået til logisk 1.
	
begin

	baudgen: process(clk,reset) -- logik til baud rate generator.
	begin
	
		if reset = '1' then
			baud_count <= 0;
			baud_tick <= '0';

		elsif rising_edge(clk) then -- hvert rising edge
			baud_tick <= '0';
			
			if baud_count = clock_p_bit-1 then
				baud_count <= 0;
				baud_tick <= '1';
			else
				baud_count <= baud_count +1;
			end if;
		end if;
	
	end baudgen;

	logic_reg: process(clk, reset) -- Sekventiel logik og data path
	begin
	
		IF reset = '1' then
			state <= IDLE;
			shift_reg <= (others => '0');
			bit_count <= 0;
			
		ELSIF rising_edge(clk) then
			state <= next_state;
			CASE state IS

				WHEN IDLE =>
					if data_available = '1' then
						shift_reg <= unsigned(tx_data);
						bit_count <= 0;
						baud_count <= 0;
					end if;

				WHEN START =>
					if baud_tick = '1' then
						baud_count <= 0;
					end if;

				WHEN DATA =>
					if baud_tick = '1' then
						shift_reg <= '0' & shift_reg(7 downto 1); -- Right Bit shifter. Sammenkæder et 0 på data bits.
						bit_count <= bit_count+1;
						baud_count <= 0;
					end if;

				when STOP =>
					if baud_tick = '1' THEN
						baud_count <= 0;
					end if;
					
			end CASE;
		end if;
	end logic_reg;
	
	next_state_proc : process (state, data_available, bit_count, baud_tick) -- Logik til state transition
	begin
	
		case state IS
		
			WHEN IDLE => -- IDLE state transition
				if data_available = '1' then
					next_state <= START;
				else
					next_state <= IDLE;
				end if;
				
			WHEN START => -- START state transition
				if baud_tick = '1' then
					next_state <= DATA;
                else
					next_state <= START;
				end if;
				
			WHEN DATA => -- DATA state transition
				if bit_count = 7 and baud_tick='1' then
					next_state <= STOP;
				else
					next_state <= DATA;
				end if;
				
			WHEN STOP => -- STOP state transition
				if baud_tick = '1' THEN
					next_state <= IDLE;
                else
					next_state <= STOP;
				end if;
				
		end case;
		
	end process next_state_proc;
	
	state_output: process (state, shift_reg) -- Logik til state output
	begin
		case state IS
			WHEN IDLE =>
				tx_line <= '1';
				tx_busy <= '0'; -- Ikke busy fordi der ikke skal ske noget på tx_linje
			WHEN START =>
				tx_line <= '0';
				tx_busy <= '1';
			WHEN DATA =>
				tx_line <= shift_reg(0);
				tx_busy <= '1';
			WHEN STOP =>
				tx_line <= '1';
				tx_busy <= '1';
		end case;

	end process state_output;

end rtl;