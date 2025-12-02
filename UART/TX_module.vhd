library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity TX is
    port (
        clk            : in  std_logic;
        reset          : in  std_logic;
        data_available : in  std_logic;
        tx_line        : out std_logic;
        tx_data        : in  STD_LOGIC_VECTOR(7 downto 0);
        tx_busy        : out std_logic
    );
end TX;

architecture rtl of TX is

    
    type Tstate is (IDLE, START, DATA, STOP);
    signal state, next_state : Tstate;

   
    signal shift_reg : STD_LOGIC_VECTOR(7 downto 0);
    signal bit_count : integer range 0 to 7;

    
    constant clock_p_bit : integer := 1250;
    signal baud_count : integer range 0 to clock_p_bit-1;
    signal baud_tick  : std_logic;
    signal baud_reset : std_logic;

    
    signal load_shift  : std_logic;
    signal shift_enable: std_logic;

begin

    
    baudgen : process(clk, reset)
    begin
        if reset = '1' then
            baud_count <= 0;
            baud_tick  <= '0';

        elsif rising_edge(clk) then
            baud_tick <= '0';

            if baud_reset = '1' then
                baud_count <= 1;
            elsif baud_count = clock_p_bit-1 then
                baud_count <= 0;
                baud_tick  <= '1';
            else
                baud_count <= baud_count + 1;
            end if;
        end if;
    end process;

    baud_reset <= '1' when (next_state = START and state = IDLE and data_available = '1')
    	else '0';
    reg_proc : process(clk, reset)
    begin
        if reset = '1' then
            state      <= IDLE;
            shift_reg  <= (others => '0');
            bit_count  <= 0;
            
        elsif rising_edge(clk) then
            
            state <= next_state;
            if load_shift = '1' then
                shift_reg <= tx_data;
                bit_count <= 0;

            elsif shift_enable = '1' then
                shift_reg <= '0' & shift_reg(7 downto 1);
                bit_count <= bit_count + 1;
            end if;
        end if;
    end process;


    
    next_state_proc : process(state, data_available, bit_count, baud_tick)
    begin
        case state is

            when IDLE =>
                if data_available = '1' then
                    next_state <= START;
                else
                    next_state <= IDLE;
                end if;

            when START =>
                if baud_tick = '1' then
                    next_state <= DATA;
                else
                    next_state <= START;
                end if;

            when DATA =>
                if bit_count = 7 and baud_tick = '1' then
                    next_state <= STOP;
                else
                    next_state <= DATA;
                end if;

            when STOP =>
                if baud_tick = '1' then
                    next_state <= IDLE;
                else
                    next_state <= STOP;
                end if;

        end case;
    end process;


    
    state_output : process(state, shift_reg, data_available, baud_tick)
    begin
      
        tx_line      <= '1';
        tx_busy      <= '1';
        load_shift   <= '0';
        shift_enable <= '0';

        case state is

            when IDLE =>
                tx_line <= '1';
                tx_busy <= '0';

                if data_available = '1' then
                    load_shift <= '1';
                end if;

            when START =>
                tx_line <= '0';


            when DATA =>
                tx_line <= shift_reg(0);
                if baud_tick = '1' then
                    shift_enable <= '1';
                end if;

            when STOP =>
                tx_line <= '1';

        end case;
    end process;

end rtl;
