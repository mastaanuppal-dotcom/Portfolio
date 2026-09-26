-- Mastaan Uppal

library ieee;
use ieee.std_logic_1164.all;

-- latches the alarm active when the current time first equals the alarm time
-- the alarm stays active until stop is asserted, this is the soft reset
-- alarm_led gates the latched alarm with the blink signal to flash the leds
entity AlarmControl is
    port (
        clk       : in  std_logic;
        rst       : in  std_logic;  -- hard reset
        match     : in  std_logic;  -- current time equals alarm time
        stop      : in  std_logic;  -- soft reset, clears the alarm only
        blink     : in  std_logic;
        alarm_on  : out std_logic;
        alarm_led : out std_logic
    );
end entity AlarmControl;

architecture Behavioral of AlarmControl is
    signal match_prev : std_logic := '0';
    signal active     : std_logic := '0';
begin

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                match_prev <= '0';
                active     <= '0';
            else
                match_prev <= match;
                if stop = '1' then
                    active <= '0';
                elsif match = '1' and match_prev = '0' then
                    -- trigger only on a new match so the alarm does not
                    -- immediately retrigger after the stop switch is released
                    active <= '1';
                end if;
            end if;
        end if;
    end process;

    alarm_on  <= active;
    alarm_led <= active and blink;

end architecture Behavioral;
