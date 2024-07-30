------------------------------------------------------------------------
-- SRAM LOADER	edits by pinballwiz 2024
-- code used is from dar ram loader etc (ckong and bagman).
-- added sram data read on green leds using sw16-0 to set sram addr
-- sram data also displayed in hex on 7 segment display
-- red led0 indicates sram load active (fast flash at start or reset)
-- to reload sram data press key0 to reset
------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all,ieee.numeric_std.all;

entity sram_loader_top is
port(
   clock_50  : in std_logic;
   reset     : in std_logic;
	ledr      : out std_logic_vector(1 downto 0);
	ledg      : out std_logic_vector(7 downto 0);
	sw			 : in std_logic_vector(17 downto 0);
	
	hex0 		 : out std_logic_vector(6 downto 0);
	hex1  	 : out std_logic_vector(6 downto 0);
	
	hex4 		 : out std_logic_vector(6 downto 0);
	hex5  	 : out std_logic_vector(6 downto 0);
	hex6 		 : out std_logic_vector(6 downto 0);
	hex7  	 : out std_logic_vector(6 downto 0);
	
	sram_addr : out std_logic_vector(17 downto 0);
	sram_dq   : inout std_logic_vector(15 downto 0);
	sram_we_n : out std_logic;
	sram_oe_n : out std_logic;
	sram_ub_n : out std_logic;
	sram_lb_n : out std_logic;
	sram_ce_n : out std_logic
);
end sram_loader_top;

architecture struct of sram_loader_top is
------------------------------------------------------------
-- create signals etc
signal clock_12mhz  : std_logic := '0';
signal div3_clk     : unsigned(1 downto 0) := "00";

-- (s)ram loader
signal load_addr : std_logic_vector(16 downto 0);
signal load_data : std_logic_vector(7 downto 0);
signal load_we   : std_logic;
signal loading   : std_logic;

signal sram_we  : std_logic;
alias sram_data : std_logic_vector is sram_dq(7 downto 0);
alias loadled   : std_logic is ledr(0);

-------------------------------------------------------------
begin
-- initialize sram
	sram_addr(17 downto 17) <= (others => '0');
	sram_ce_n <= '0';
	sram_we_n <= not sram_we;
	sram_oe_n <= sram_we;
	sram_ub_n <= '0';
	sram_lb_n <= '0';
	
	loadled <= loading; -- red led0
	ledg(7 downto 0) <= sram_data; -- sram addr data on green leds
-------------------------------------------------------------
-- make a clock one third of 50mhz
process(clock_50)
begin
	if rising_edge(clock_50) then

		if div3_clk = 2 then
			div3_clk <= to_unsigned(0,2);
		else
			div3_clk <= div3_clk + 1;
		end if;
		clock_12mhz <= div3_clk(0);
	end if;
end process;
-------------------------------------------------------------
-- do some stuff when clock rises
process(clock_12mhz)
begin
	if rising_edge(clock_12mhz) then
		sram_addr(16 downto 0) <= (others => '1');
		sram_we <= '0';
		sram_data <= (others => 'Z');
		if loading = '1' then
			sram_addr(16 downto 0) <= load_addr;
			sram_we <= load_we;
			sram_data <= load_data;
			else
			sram_addr(16 downto 0) <= sw(16 downto 0);
				end if;
	end if;
end process;
-------------------------------------------------------------
-- send stuff to sram loader
ram_loader : entity work.ram_loader
port map(
	clock    => clock_12mhz,
	reset    => reset,
	address  => load_addr,
	data     => load_data,
	we       => load_we,
	loading  => loading
);
-------------------------------------------------------------
-- display sram addr data on 7 segment display
h0 : entity work.seven_segment_decoder port map(sram_data(3 downto 0),hex0);
h1 : entity work.seven_segment_decoder port map(sram_data(7 downto 4),hex1);
-------------------------------------------------------------
-- display sw/sram address on 7 segment display
h4 : entity work.seven_segment_decoder port map(sw(3 downto 0),hex4);
h5 : entity work.seven_segment_decoder port map(sw(7 downto 4),hex5);
h6 : entity work.seven_segment_decoder port map(sw(11 downto 8),hex6);
h7 : entity work.seven_segment_decoder port map(sw(15 downto 12),hex7);
-------------------------------------------------------------
end architecture;