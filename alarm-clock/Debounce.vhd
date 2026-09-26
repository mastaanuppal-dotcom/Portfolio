-- Mastaan Uppal, Eugene Magsino

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- debounces a mechanical button or switch input
-- the output only changes after the input has been stable for count_max clock cycles
entity Debounce is
    generic (
        COUNT_MAX : integer := 500000  -- 10 ms at 50 mhz
    );
    port (
        clk  : in  std_logic;
        rst  : in  std_logic;
        din  : in  std_logic;
        dout : out std_logic
    );
end entity Debounce;

architecture Behavioral of Debounce is
    signal sync0, sync1 : std_logic := '0';                 -- two flop synchronizer
    signal count        : integer range 0 to COUNT_MAX := 0;
    signal state        : std_logic := '0';                 -- debounced value
begin

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                sync0 <= '0';
                sync1 <= '0';
                count <= 0;
                state <= '0';
            else
                -- synchronize the asynchronous input
                sync0 <= din;
                sync1 <= sync0;

                if sync1 = state then
                    -- input agrees with current state, nothing to do
                    count <= 0;
                elsif count = COUNT_MAX - 1 then
                    -- input has been different and stable long enough, accept it
                    state <= sync1;
                    count <= 0;
                else
                    count <= count + 1;
                end if;
            end if;
        end if;
    end process;

    dout <= state;

end architecture Behavioral;
