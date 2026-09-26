-- Mastaan Uppal, Eugene Magsino

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- divides the 50 mhz board clock down to a one pulse per second tick
-- fast input switches to a shorter division for the demo speed up
-- blink output is a square wave used to flash the leds when the alarm fires
entity PreScale is
    generic (
        DIV_NORMAL : integer := 50000000;  -- one second at 50 mhz
        DIV_FAST   : integer := 500000;    -- 100x faster for demo
        DIV_BLINK  : integer := 6250000    -- blink toggle rate, 4 hz flash
    );
    port (
        clk      : in  std_logic;
        rst      : in  std_logic;
        fast     : in  std_logic;
        tick_sec : out std_logic;
        blink    : out std_logic
    );
end entity PreScale;

architecture Behavioral of PreScale is
    signal sec_count   : integer range 0 to DIV_NORMAL - 1 := 0;
    signal blink_count : integer range 0 to DIV_BLINK - 1  := 0;
    signal tick_r      : std_logic := '0';
    signal blink_r     : std_logic := '0';
begin

    process(clk)
        variable limit : integer;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                sec_count   <= 0;
                blink_count <= 0;
                tick_r      <= '0';
                blink_r     <= '0';
            else
                -- select the division ratio for the seconds tick
                if fast = '1' then
                    limit := DIV_FAST;
                else
                    limit := DIV_NORMAL;
                end if;

                -- one cycle pulse every limit clock cycles
                -- the greater or equal compare handles switching between fast and normal
                if sec_count >= limit - 1 then
                    sec_count <= 0;
                    tick_r    <= '1';
                else
                    sec_count <= sec_count + 1;
                    tick_r    <= '0';
                end if;

                -- free running square wave for the alarm flash
                if blink_count = DIV_BLINK - 1 then
                    blink_count <= 0;
                    blink_r     <= not blink_r;
                else
                    blink_count <= blink_count + 1;
                end if;
            end if;
        end if;
    end process;

    tick_sec <= tick_r;
    blink    <= blink_r;

end architecture Behavioral;
