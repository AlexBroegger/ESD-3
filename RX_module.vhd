library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity RX is
    port (
        clk        : in  std_logic;
        reset      : in  std_logic;
        rx_line    : in  std_logic;
        rx_data    : out unsigned(7 downto 0);
        rx_ready   : out std_logic
    );
end RX;

architecture rtl of RX is

    type Rstate is (IDLE, START, DATA, STOP);
    signal state, next_state : Rstate;

    signal rx_sync_1, rx_sync_2 : std_logic; -- 2ff

    signal shift_reg : unsigned(7 downto 0);
    signal bit_count : integer range 0 to 7;


    constant oversample       : integer := 16; -- Vores valgte oversampling rate. Vi har 16 gange oversampling
    constant clock_p_16x      : integer := 78 ; -- Dette er 12MHz/(9600*16)=78.125, og vi runder ned. Dette betyder der kommer lidt tidsdrift
    signal os_count           : integer range 0 to clock_p_16x-1; -- Tæller op til
    signal os_tick            : std_logic; -- Bliver en når vi når til 78

    signal sample_count : integer range 0 to 15;


    signal shift_en     : std_logic; -- Tillader shift
    signal done_sample  : std_logic; -- Færdig med at sample

begin

    --2ff, bruges til metastability problemer
    sync_proc : process(clk, reset)
    begin
        if reset='1' then
            rx_sync_1 <= '1';
            rx_sync_2 <= '1';
        elsif rising_edge(clk) then
            rx_sync_1 <= rx_line;
            rx_sync_2 <= rx_sync_1;
        end if;
    end process;

    -- Oversamplings count. Lidt ligesom baud generator, men den kører 16 gange hurtigere, dette bliver vores nye baud_tick. Det vil sige at 16 af disse giver 16 ticks.
    os_baud : process(clk, reset)
    begin
        if reset='1' then
            os_count <= 0;
            os_tick  <= '0';
        elsif rising_edge(clk) then
            os_tick <= '0';
            if os_count = 77 then
                os_count <= 0;
                os_tick  <= '1';
            else
                os_count <= os_count + 1;
            end if;
        end if;
    end process;

    -- State register og lidt datapath
    reg_proc : process(clk, reset)
    begin
        if reset='1' then
            state        <= IDLE;
            shift_reg    <= (others=>'0');
            bit_count    <= 0;
            sample_count <= 0;
            rx_data      <= (others=>'0');

        elsif rising_edge(clk) then
            state <= next_state;

            -- Hold sample_count 0 hele tiden. Dette gøres for at sikre lidt bedre timing
            if state = IDLE then
                sample_count <= 0;
                bit_count    <= 0; -- Reset
            
            elsif os_tick='1' then
                -- Standard counter that wraps around
                if sample_count = 15 then
                    sample_count <= 0;
                    -- Ingen tick fordi det ikke skal bruges, vi skal bare tælle ticks
                else
                    sample_count <= sample_count + 1;
                end if;

                -- Data shift
                if shift_en='1' then
                    shift_reg <= rx_sync_2 & shift_reg(7 downto 1); -- Concatetion (tror det hedder det)
                    bit_count <= bit_count + 1; -- bit_count styring
                end if;

                -- rx_data bliver kun til hele shift_reg når sampling er færdig
                if done_sample='1' then
                    rx_data <= shift_reg;
                end if;
            end if;
        end if;
    end process;

    -- State transition logik
    next_state_proc : process(state, rx_sync_2, bit_count, sample_count, os_tick)
    begin
        next_state <= state;

        case state is
            when IDLE =>
                if rx_sync_2 = '0' then
                    next_state <= START;
                end if;

            when START =>
                -- Vi tjekker midten af bit.
                if os_tick='1' and sample_count = oversample/2 then
                    if rx_sync_2='0' then
                        next_state <= DATA;
                    else
                        next_state <= IDLE; -- Sikrer at det ikke er en falsk start
                    end if;
                end if;

            when DATA =>
                if os_tick='1' and sample_count = oversample/2 then
                    if bit_count = 7 then
                        next_state <= STOP;
                    end if;
                end if;

            when STOP =>
                if os_tick='1' and sample_count = oversample/2 then
                    next_state <= IDLE;
                end if;
        end case;
    end process;

    -- Output logik
    out_proc : process(state, sample_count, os_tick)
    begin
        rx_ready    <= '0';
        shift_en    <= '0';
        done_sample <= '0';

        case state is
            when IDLE =>
            -- Intet
            when START =>
            -- Intet
            when DATA =>
                if os_tick='1' and sample_count = oversample/2 then
                    shift_en <= '1';
                end if;
            when STOP =>
                if os_tick='1' and sample_count = oversample/2 then
                    rx_ready    <= '1';
                    done_sample <= '1';
                end if;
        end case;
    end process;

end rtl;