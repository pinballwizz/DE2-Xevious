---------------------------------------------------------------------------------
-- Ram loader - Dar - Feb 2014
---------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all, ieee.std_logic_unsigned.all, ieee.numeric_std.all;

entity ram_loader is
port(
	clock : in std_logic;
	reset    : in std_logic;
	address  : out std_logic_vector(16 downto 0);
	data     : out std_logic_vector(7 downto 0);
	we       : out std_logic;
	loading  : out std_logic
);

end ram_loader;

architecture struct of ram_loader is

signal wr_addr      : std_logic_vector(16 downto 0) := (others => '0');
signal rd_addr      : std_logic_vector(16 downto 0) := (others => '0');
signal step_cnt     : integer range 0 to 7 := 0;
signal next_word    : std_logic := '0';
signal do_xevious_cpu1 : std_logic_vector(7 downto 0);
signal do_xevious_cpu2 : std_logic_vector(7 downto 0);

begin

-----------------------------------------------------------
-- edit below to add your rom info

xevious_cpu1 : entity work.xevious_cpu1
port map(
 clk  => clock,
 addr => rd_addr(13 downto 0),
 data => do_xevious_cpu1
);

xevious_cpu2 : entity work.xevious_cpu2
port map(
 clk  => clock,
 addr => rd_addr(12 downto 0),
 data => do_xevious_cpu2
);

-----------------------------------------------------------

address <= wr_addr;

with step_cnt select
	we <= next_word when 1,
				next_word when 2,
				next_word when 3,
				next_word when 4,
				next_word when 5,
				'0' when others;

with step_cnt select
	data <= do_xevious_cpu1 when 1,
			  do_xevious_cpu2 when 2,
			 --  do_ripoff when 3,
			--	do_spacewars when 4,
				--	"01" & rd_addr(9 downto 8) &"0001" when 5,
					"00000000" when others;

process(clock,reset)
begin
		if reset = '0' then
			wr_addr <= (others => '0');
			rd_addr <= (others => '0');
			step_cnt <= 0;
			next_word <= '0';
		else
			if rising_edge(clock) then
			
				next_word <= not next_word;
				if next_word = '1' then
					rd_addr <= rd_addr + '1';
					wr_addr <= wr_addr + '1';
					if step_cnt = 0 then                 -- step 0
						if rd_addr = X"3" then
							wr_addr <= (others => '0');
							loading <= '1';
							
						elsif rd_addr = X"7" then
							wr_addr <= "0" & X"0000";      -- xevious start 68k
							rd_addr <= (others => '0');
							step_cnt <= step_cnt + 1;
						end if;
						
					elsif step_cnt = 1 then              -- step 1
						if rd_addr = X"3FFF" then         -- xevious cpu1 length
							wr_addr <= "0" & X"4000";      -- next addr start
							rd_addr <= (others => '0');
							step_cnt <= step_cnt + 1;
						end if;

					elsif step_cnt = 2 then              -- step 2
						if rd_addr = X"1FFF" then          -- xevious cpu2 length
							wr_addr <= "0" & X"6000";        -- next addr start
							rd_addr <= (others => '0');
							step_cnt <= step_cnt + 1;
						end if;
				
				--	elsif step_cnt = 3 then              -- step 3
				--		if rd_addr = X"0FFF" then          -- ripoff length
				--			wr_addr <= "0" & X"3000";        -- spacewars start
				--			rd_addr <= (others => '0');
				--			step_cnt <= step_cnt + 1;
				--		end if;
						
				--	elsif step_cnt = 4 then              -- step 4
				--		if rd_addr = X"0FFF" then          -- spacewars length
				--			wr_addr <= "0" & X"4000";        -- next rom start
				--			rd_addr <= (others => '0');
				--			step_cnt <= step_cnt + 1;
				--		end if;
				
				--	elsif step_cnt = 5 then              -- step 5
				--		if rd_addr = X"03FF" then          -- ram color length
				--			wr_addr <= "1" & X"FFFF";        -- stop address
				--			rd_addr <= (others => '0');
				--			step_cnt <= step_cnt + 1;
				--		end if;
					elsif step_cnt < 7 then              -- other steps
					step_cnt <= step_cnt + 1;
					else
						loading <= '0';
					end if;
				end if;

		end if;
	end if;
end process;

end struct;
