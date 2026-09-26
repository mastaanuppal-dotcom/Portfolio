-- Mastaan Uppal

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- two digit bcd counter counting from 0 to mod_max minus 1 then wrapping to 0
-- mod_max 60 gives a seconds or minutes counter, mod_max 24 gives an hours counter
-- init sets the value loaded on reset, rollover pulses when the counter wraps
entity BCDCounter is
    generic (
        MOD_MAX : integer := 60;
        INIT    : integer := 0
    );
    port (
        clk      : in  std_logic;
        rst      : in  std_logic;
        en       : in  std_logic;
        tens     : out std_logic_vector(3 downto 0);
        ones     : out std_logic_vector(3 downto 0);
        rollover : out std_logic
    );
end entity BCDCounter;

architecture Behavioral of BCDCounter is
    constant MAX_TENS  : integer := (MOD_MAX - 1) / 10;
    constant MAX_ONES  : integer := (MOD_MAX - 1) mod 10;
    constant INIT_TENS : integer := INIT / 10;
    constant INIT_ONES : integer := INIT mod 10;

    signal tens_r : unsigned(3 downto 0) := to_unsigned(INIT_TENS, 4);
    signal ones_r : unsigned(3 downto 0) := to_unsigned(INIT_ONES, 4);
    signal at_max : std_logic;
begin

    -- high when the counter holds its maximum value
    at_max <= '1' when (tens_r = to_unsigned(MAX_TENS, 4)) and
                       (ones_r = to_unsigned(MAX_ONES, 4)) else '0';

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                tens_r <= to_unsigned(INIT_TENS, 4);
                ones_r <= to_unsigned(INIT_ONES, 4);
            elsif en = '1' then
                if at_max = '1' then
                    -- wrap around to zero
                    tens_r <= (others => '0');
                    ones_r <= (others => '0');
                elsif ones_r = 9 then
                    -- carry from ones digit into tens digit
                    ones_r <= (others => '0');
                    tens_r <= tens_r + 1;
                else
                    ones_r <= ones_r + 1;
                end if;
            end if;
        end if;
    end process;

    tens     <= std_logic_vector(tens_r);
    ones     <= std_logic_vector(ones_r);
    rollover <= en and at_max;  -- carry out pulse, used to chain counters

end architecture Behavioral;
