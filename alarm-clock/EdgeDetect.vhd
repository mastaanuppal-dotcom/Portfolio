-- Mastaan Uppal

library ieee;
use ieee.std_logic_1164.all;

-- converts a rising edge on din into a single clock cycle pulse
-- used after the debouncer so one button press causes exactly one increment
entity EdgeDetect is
    port (
        clk   : in  std_logic;
        rst   : in  std_logic;
        din   : in  std_logic;
        pulse : out std_logic
    );
end entity EdgeDetect;

architecture Behavioral of EdgeDetect is
    signal prev    : std_logic := '0';
    signal pulse_r : std_logic := '0';
begin

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                prev    <= '0';
                pulse_r <= '0';
            else
                prev    <= din;
                pulse_r <= din and (not prev);  -- high for one cycle on a rising edge
            end if;
        end if;
    end process;

    pulse <= pulse_r;

end architecture Behavioral;
