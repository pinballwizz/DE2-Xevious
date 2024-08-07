---------------------------------------------------------------------------------
-- Xevious by Dar (darfpga@aol.fr)
-- http://darfpga.blogspot.fr
---------------------------------------------------------------------------------
-- gen_ram.vhd & io_ps2_keyboard
-------------------------------- 
-- Copyright 2005-2008 by Peter Wendrich (pwsoft@syntiac.com)
-- http://www.syntiac.com/fpga64.html
---------------------------------------------------------------------------------
-- T80/T80se - Version : 0247
-----------------------------
-- Z80 compatible microprocessor core
-- Copyright (c) 2001-2002 Daniel Wallner (jesus@opencores.org)
---------------------------------------------------------------------------------
-- Educational use only
-- Do not redistribute synthetized file with roms
-- Do not redistribute roms whatever the form
-- Use at your own risk
---------------------------------------------------------------------------------
-- Version 0.3 -- 28/02/2017
--             Fixed cs54xx audio 2 (mb88 JMP instruction fixed)
--
-- Version 0.2 -- 26/02/2017 -- 
--             Replace cs50xx rough emulation by mb88 processor
--             mb88.vhd : tstR and tbit fixed
--
-- Version 0.1 -- 15/02/2017 -- 
--		    Add ship explosion with mb88 processor
---------------------------------------------------------------------------------
--  Features :
--   TV 15KHz mode only (atm)
--   Cocktail mode : todo 
--   Replace cs51xx with true mb88 processor : todo
--
--   Sound ok, Ship explode ok with true mb88 processor

--  Use with MAME roms from xevious.zip
--
--  Use make_xevious_proms.bat to build vhd file and bin from binaries

--  IMPORTANT --
--    Use DE2 Control Panel to load xevious_cpu_gfx_16bits.bin to DE2 SRAM
--
--    1) Switch ON DE2
--    2) Launch QuartusII and program DE2 with "DE2_USB_API.sof"
--    3) Launch DE2 control panel
--       a) Menu Open -> Open USB port 0
--       b) (Test connexion) Tab PS2 & 7-SEG : select '3' on HEX7 and click on SET, digit on DE2 should diplay '3'
--       c) Tab SRAM / frame Sequential Write : check box 'File length'. Click on Write a file to SRAM and choose xevious_cpu_gfx_16bits.bin
--       d) wait for compete write
--       e) (check write) frame Random Access : click Read (Adress 0), rData should display '3E3E'
--       f) VERY IMPORTANT : Menu Open -> Close USB port
--    DO NOT SWITCH OFF DE2 or you will need to reload SRAM
--    4) go back to QuartusII and program DE2 with "xevious_de2.sof"

--    Explanation : Xevious make use of large amount of data (prom). All these data could not fit into DE2-35 FPGA. 
--    I choose to put all 3 CPUs program, foreground graphics, background graphics and sprite graphics data
--    to external memory. This lead to 68Ko of data. As DE2-35 use a 16bits width SRAM since and DE2 control panel doesn't allow
--    to load 8bits width data all data have been duplicated on both 8bits LSB and 8bits MSB. So xevious_cpu_gfx_16bits.bin 
--    is 136Ko.

--		For other boards one have to consider that the external data are accessed with a 18Mhz multiplexed addressing scheme. So
--    external device have to have a 55ns max access time. Of course big enough FPGA may directly implement these data bank without
--    requiring external device. It is to notice that 55ns will be not so easy to reach with Flash or SDRAM memories.    

--  Xevious Hardware caracteristics :
--
--    3xZ80 CPU accessing each own program rom and shared ram/devices
--      16Ko program for CPU1
--      8Ko program for CPU2
--      4Ko program for CPU3
--
--    One char tile map 64x28 (called foreground/fg) 
--      1 colors/64sets among 128 colors
--      4Ko ram (code + attr/color), 4Ko rom graphics, 8pixels of 1bits/byte 
--      Horizontal scrolling (horizontal for TV scan = vertical for upright cabinet) 
--      full emulation in vhdl

--    One background tile map 64x28 (called background/bg) 
--      4 colors/128sets among 128 colors
--      4Ko ram (code + attr/color), 8Ko rom graphics, 8pixels of 2bits/ 2bytes 
--      Horizontal/Vertical scrolling 
--      full emulation in vhdl
--
--    64 sprites with priorities, flip H/V, 2x size H/V, 
--      8 colors/64sets among 128 colors.
--      24Ko rom graphics, 4pixels of 3bits / 1.5byte
--      4 colors/64sets among 128 colors.
--      8Ko rom graphics, 4pixels of 2bits / byte
--      full emulation in vhdl (improved capabilities : more sprites/scanline)
--
--    Char/sprites color palette 128 colors among 4096
--      12bits 4red/4green/4blue
--      full emulation in vhdl
--
--    Terrain data
--      8Ko + 4Ko + 4Ko rom
--
--    Namco 06XX for 51/54XX control 
--      simplified emulation in vhdl
--
--    Namco 50XX for protection management 
--      simplified emulation in vhdl

--    Namco 51XX for coin/credit management 
--      simplified emulation in vhdl : 1coin/1credit, 1 or 2 players start
--
--    Namco 54XX for sound effects 
--      true mb88 processor ok
--
--    Namco sound waveform and frequency synthetizer
--      full original emulation in vhdl
--
--    Namco such as address generator, H/V counters and shift registers
--      full emulation in vhdl from what I think they should do.
--
--    Working ram : 2Kx8bits + 3x2Kx8bits + 2x4Kox8bits (all shared)
--    Sprites ram : 1 scan line delay flip/flop 512x4bits  
--    Sound registers ram : 2x16x4bits
--    Sound sequencer rom : 256x4bits (3 sequential 4 bits adders)
--    Sound wavetable rom : 256x4bits 8 waveform of 32 samples of 4bits/level  
---------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity xevious is
port(
 clock_18     : in std_logic;
 reset        : in std_logic;
-- tv15Khz_mode : in std_logic;
 video_r        : out std_logic_vector(3 downto 0);
 video_g        : out std_logic_vector(3 downto 0);
 video_b        : out std_logic_vector(3 downto 0);
 video_clk      : out std_logic;
 video_csync    : out std_logic;
 video_blankn   : out std_logic;
 video_hs     : out std_logic;
 video_vs     : out std_logic;
 audio          : out std_logic_vector(10 downto 0);

-- ledr           : out std_logic_vector(17 downto 0);
-- sw             : in  std_logic_vector(17 downto 0);
 
 rom_bus_addr_o : out std_logic_vector(16 downto 0);
 rom_bus_do     : in std_logic_vector(7 downto 0);
 
 b_test         : in std_logic;
 b_svce         : in std_logic;
 coin           : in std_logic;
 start1         : in std_logic;
 start2         : in std_logic;
 up             : in std_logic;
 down           : in std_logic;
 left           : in std_logic;
 right          : in std_logic;
 fire           : in std_logic;
 bomb           : in std_logic
 );
end xevious;

architecture struct of xevious is

 signal reset_n: std_logic;
 signal clock_18n : std_logic;

 signal slot24          : std_logic_vector(4 downto 0) := (others => '0');
 signal slot            : std_logic_vector(2 downto 0) := (others => '0');
 signal hcnt            : std_logic_vector(8 downto 0);
 signal vcnt            : std_logic_vector(8 downto 0);
 signal ena_vidgen      : std_logic;
 signal ena_snd_machine : std_logic;
 signal ena_sprite      : std_logic;
 signal ena_sprite_grph0: std_logic;
 signal ena_sprite_grph1: std_logic;
 signal cpu1_ena        : std_logic;
 signal cpu2_ena        : std_logic;
 signal cpu3_ena        : std_logic;

 signal cpu1_addr   : std_logic_vector(15 downto 0);
-- signal cpu1_di     : std_logic_vector( 7 downto 0);
 signal cpu1_do     : std_logic_vector( 7 downto 0);
 signal cpu1_wr_n   : std_logic;
 signal cpu1_mreq_n : std_logic;
 signal cpu1_irq_n  : std_logic;
 signal cpu1_nmi_n  : std_logic;
 signal cpu1_m1_n   : std_logic;

 signal cpu2_addr   : std_logic_vector(15 downto 0);
-- signal cpu2_di     : std_logic_vector( 7 downto 0);
 signal cpu2_do     : std_logic_vector( 7 downto 0);
 signal cpu2_wr_n   : std_logic;
 signal cpu2_mreq_n : std_logic;
 signal cpu2_irq_n : std_logic;
 signal cpu2_m1_n   : std_logic;
 
 signal cpu3_addr   : std_logic_vector(15 downto 0);
-- signal cpu3_di     : std_logic_vector( 7 downto 0);
 signal cpu3_do     : std_logic_vector( 7 downto 0);
 signal cpu3_wr_n   : std_logic;
 signal cpu3_mreq_n : std_logic;
 signal cpu3_nmi_n  : std_logic;
 signal cpu3_m1_n   : std_logic;

 signal fg_scan_addr : std_logic_vector(10 downto 0);
 signal bg_scan_addr : std_logic_vector(10 downto 0);

 signal bg_offset_h : std_logic_vector(8 downto 0);
 signal bg_offset_hs: std_logic_vector(8 downto 0);
 signal fg_offset_h : std_logic_vector(8 downto 0);
 signal fg_offset_hs: std_logic_vector(8 downto 0);
 signal bg_scan_h   : std_logic_vector(8 downto 0);
 signal fg_scan_h   : std_logic_vector(8 downto 0);
 signal bg_offset_v : std_logic_vector(8 downto 0);
 signal bg_offset_vs: std_logic_vector(8 downto 0);
 signal fg_offset_v : std_logic_vector(8 downto 0);
 signal fg_offset_vs: std_logic_vector(8 downto 0);
 signal bg_scan_v   : std_logic_vector(8 downto 0);
 signal fg_scan_v   : std_logic_vector(8 downto 0);
 
 signal code_ram_do : std_logic_vector( 7 downto 0);
 signal code_ram_we : std_logic;
 signal attr_ram_do : std_logic_vector( 7 downto 0);
 signal attr_ram_we  : std_logic;
 signal wram0_do    : std_logic_vector( 7 downto 0);
 signal wram0_we    : std_logic;
 signal wram1_do    : std_logic_vector( 7 downto 0);
 signal wram1_we    : std_logic;
 signal wram2_do    : std_logic_vector( 7 downto 0);
 signal wram2_we    : std_logic;
 signal wram3_do    : std_logic_vector( 7 downto 0);
 signal wram3_we    : std_logic;
 signal port_we     : std_logic;
 signal terrain_we  : std_logic;

 signal rom_bus_addr : std_logic_vector(16 downto 0);
 signal ram_bus_addr : std_logic_vector(15 downto 0);
 signal mux_cpu_do   : std_logic_vector( 7 downto 0);
 signal cpus_di      : std_logic_vector( 7 downto 0);
 signal mux_cpu_we   : std_logic;
 signal mux_cpu_mreq : std_logic;
 signal latch_we     : std_logic;
 signal io_we        : std_logic;

 signal cs06XX_control : std_logic_vector( 7 downto 0);
 signal cs06XX_do      : std_logic_vector( 7 downto 0);
 signal cs06XX_di      : std_logic_vector( 7 downto 0);

 signal cs51XX_data_cnt           : std_logic_vector( 1 downto 0);
 signal cs51XX_coin_mode_cnt      : std_logic_vector( 2 downto 0);
 signal cs51XX_switch_mode        : std_logic;
 signal cs51XX_credit_mode        : std_logic;
 signal cs51XX_do                 : std_logic_vector( 7 downto 0);
 signal cs51XX_switch_mode_do     : std_logic_vector( 7 downto 0);
 signal cs51XX_non_switch_mode_do : std_logic_vector( 7 downto 0);
 signal change_next               : std_logic;
 signal credit_bcd_0              : std_logic_vector( 3 downto 0);
 signal credit_bcd_1              : std_logic_vector( 3 downto 0);
 
-- signal cs54XX_cmd        : std_logic_vector( 3 downto 0);
-- signal cs54XX_do         : std_logic_vector( 7 downto 0);
 
 signal cs54xx_ena      : std_logic;
 signal cs5Xxx_rw       : std_logic;
 
 signal cs54xx_rom_addr : std_logic_vector(10 downto 0); 
 signal cs54xx_rom_do   : std_logic_vector( 7 downto 0); 
 
 signal cs54xx_irq_n      : std_logic := '1'; 
 signal cs54xx_irq_cnt    : std_logic_vector( 3 downto 0); 
 signal cs54xx_k_port_in  : std_logic_vector( 3 downto 0); 
 signal cs54xx_r0_port_in : std_logic_vector( 3 downto 0); 
 signal cs54xx_audio_1    : std_logic_vector( 3 downto 0); 
 signal cs54xx_audio_2    : std_logic_vector( 3 downto 0); 
 signal cs54xx_audio_3    : std_logic_vector( 3 downto 0); 

 signal cs50XX_data_cnt   : std_logic_vector( 1 downto 0);
 signal cs50XX_cmd        : std_logic_vector( 7 downto 0);
 signal cs50XX_cmd_80_do  : std_logic_vector( 7 downto 0);
 signal cs50XX_cmd_E5_do  : std_logic_vector( 7 downto 0);
 signal cs50XX_do         : std_logic_vector( 7 downto 0);

 signal cs50xx_rom_addr   : std_logic_vector(10 downto 0); 
 signal cs50xx_rom_do     : std_logic_vector( 7 downto 0); 

 signal cs50xx_irq_n      : std_logic := '1'; 
 signal cs50xx_irq_cnt    : std_logic_vector( 3 downto 0); 
 signal cs50xx_k_port_in  : std_logic_vector( 3 downto 0); 
 signal cs50xx_r0_port_in : std_logic_vector( 3 downto 0); 
 signal cs50xx_ol_port_out: std_logic_vector( 3 downto 0); 
 signal cs50xx_oh_port_out: std_logic_vector( 3 downto 0); 
 
 --signal cs05XX_ctrl       : std_logic_vector( 5 downto 0);
 
 signal dip_switch_a  : std_logic_vector (7 downto 0);
 signal dip_switch_b  : std_logic_vector (7 downto 0);
 signal dip_switch_do : std_logic_vector (1 downto 0);
 
 signal bg_code,bg_code_p : std_logic_vector( 7 downto 0);
 signal bg_attr,bg_attr_p : std_logic_vector( 7 downto 0);
 signal bg_grphx_addr     : std_logic_vector(11 downto 0);
 signal bg_grphx_0_p      : std_logic_vector( 7 downto 0);
 signal bg_grphx_0        : std_logic_vector( 7 downto 0);
 signal bg_grphx_1_p      : std_logic_vector( 7 downto 0);
 signal bg_grphx_1        : std_logic_vector( 7 downto 0);
 signal bg_bits           : std_logic_vector( 1 downto 0);
 signal bg_color_delay_0  : std_logic_vector( 7 downto 0);
 signal bg_color_delay_1  : std_logic_vector( 7 downto 0);
 signal bg_color_delay_2  : std_logic_vector( 7 downto 0);
 signal bg_color_delay_3  : std_logic_vector( 7 downto 0);
 signal bg_color_delay_4  : std_logic_vector( 7 downto 0);
 signal bg_color_delay_5  : std_logic_vector( 7 downto 0);
 signal bg_color          : std_logic_vector( 5 downto 0);
 
 signal fg_code,fg_code_p : std_logic_vector( 7 downto 0);
 signal fg_attr,fg_attr_p : std_logic_vector( 7 downto 0);
 signal fg_grphx_addr     : std_logic_vector(11 downto 0);
 signal fg_grphx_p        : std_logic_vector( 7 downto 0);
 signal fg_grphx          : std_logic_vector( 7 downto 0);
 signal fg_bit            : std_logic;
 signal fg_color          : std_logic_vector( 6 downto 0);
 
 signal terrain_bs0         : std_logic_vector( 7 downto 0); 
 signal terrain_bs1         : std_logic_vector( 7 downto 0);
 signal terrain_2a_rom_addr : std_logic_vector(11 downto 0);
 signal terrain_2a_rom_do   : std_logic_vector( 7 downto 0);
 signal terrain_2b_rom_addr : std_logic_vector(12 downto 0);
 signal terrain_2b_rom_do   : std_logic_vector( 7 downto 0);
 signal terrain_2c_rom_addr : std_logic_vector(11 downto 0);
 signal terrain_2c_rom_do   : std_logic_vector( 7 downto 0);
 signal terrain_mux_do      : std_logic_vector( 2 downto 0);
 signal terrain_bb0         : std_logic_vector( 7 downto 0); 
 signal terrain_bb1         : std_logic_vector( 7 downto 0);
 signal terrain_do          : std_logic_vector( 7 downto 0);
 
 signal bg_palette_addr   : std_logic_vector( 8 downto 0);
 signal bg_palette_lsb_do : std_logic_vector( 7 downto 0); 
 signal bg_palette_msb_do : std_logic_vector( 7 downto 0); 

 signal rgb_palette_addr     : std_logic_vector( 7 downto 0);
 signal rgb_palette_red_do   : std_logic_vector( 7 downto 0); 
 signal rgb_palette_green_do : std_logic_vector( 7 downto 0); 
 signal rgb_palette_blue_do  : std_logic_vector( 7 downto 0); 
 
 signal sprite_num     : std_logic_vector(5 downto 0);
 signal sprite_state   : std_logic_vector(2 downto 0); 
 signal sp_line        : std_logic_vector(7 downto 0);
 signal sp_grphx_cnt   : std_logic_vector(1 downto 0);
 signal sp_scan_addr   : std_logic_vector(6 downto 0);
 signal sprite_code    : std_logic_vector(7 downto 0);
 signal sprite_color   : std_logic_vector(7 downto 0);
 signal sprite_attr    : std_logic_vector(7 downto 0);
 signal sp_code_ext    : std_logic_vector(8 downto 0);
 signal sprite_vcnt    : std_logic_vector(4 downto 0);
 signal sprite_hcnt    : std_logic_vector(4 downto 0);
 signal sp_ram_wr_addr  : std_logic_vector(8 downto 0);
 signal sp_ram_rd_addr  : std_logic_vector(8 downto 0);
 signal sp_ram_we       : std_logic;
 signal sp_ram_clr      : std_logic;
 signal sp_grphx_addr  : std_logic_vector(14 downto 0);
 signal sp_grphx_0     : std_logic_vector(7 downto 0);
 signal sp_grphx_1     : std_logic_vector(3 downto 0);
 signal sp_palette_addr : std_logic_vector(8 downto 0);
 signal sp_palette_lsb_do: std_logic_vector(7 downto 0); 
 signal sp_palette_msb_do: std_logic_vector(7 downto 0); 
 signal sp_color_wr      : std_logic_vector(7 downto 0);
 signal sp_color_rd      : std_logic_vector(6 downto 0);
 signal spflip_V ,spflip_H  : std_logic;
 signal spflip_2V,spflip_2H : std_logic_vector(1 downto 0);
 signal spflip_3V,spflip_3H : std_logic_vector(2 downto 0);
 signal spflips             : std_logic_vector(12 downto 0);

 signal flip_h         : std_logic; 
 
 signal sp_ram1_addr    : std_logic_vector(8 downto 0);
 signal sp_ram1_di      : std_logic_vector(6 downto 0);
 signal sp_ram1_do      : std_logic_vector(6 downto 0);
 signal sp_ram1_we      : std_logic;
 signal sp_ram2_addr    : std_logic_vector(8 downto 0);
 signal sp_ram2_di      : std_logic_vector(6 downto 0);
 signal sp_ram2_do      : std_logic_vector(6 downto 0);
 signal sp_ram2_we      : std_logic;
 
 signal irq1_clr_n  : std_logic;
 signal irq2_clr_n  : std_logic;
 signal nmion_n     : std_logic;
 signal reset_cpu_n : std_logic;

 signal snd_ram_0_we : std_logic;
 signal snd_ram_1_we : std_logic;
 signal snd_audio    : std_logic_vector(9 downto 0);
 signal hcnt_r       : std_logic_vector(8 downto 0);

 signal coin_r   : std_logic;
 signal start1_r : std_logic;
 signal start2_r : std_logic;

 signal buttons  : std_logic_vector(3 downto 0);
 signal joy      : std_logic_vector(3 downto 0);

begin

rom_bus_addr_o <= rom_bus_addr;

clock_18n <= not clock_18;
reset_n   <= not reset;

dip_switch_a <= "11111111"; -- | cabinet(1) | lives(2)| bonus life(3) | coinage A(2) |
dip_switch_b <= "1110001" & not bomb; -- |freeze(1)| difficulty(2)| input B(1) | coinage B (2) | Flags bonus life (1) | input A (1) |
dip_switch_do <= 	dip_switch_a(to_integer(unsigned(ram_bus_addr(3 downto 0)))) & 
									dip_switch_b(to_integer(unsigned(ram_bus_addr(3 downto 0))));
									
audio <= ("00" & cs54xx_audio_1 &  "00000" ) + ("00" & cs54xx_audio_2 &  "00000" )+ ('0'&snd_audio);
--audio <= ("00" & cs54xx_audio_1 &  "00000" ) + ('0'&snd_audio);
--audio <= ('0'&snd_audio);

-- sp stand for sprite, fg stand for foreground and bg stand for background.
-- make access slots from 18MHz
--  1 access to any ram or rom for each cpu every 2 pixels
--  1 access to ram(2 bytes) for foreground every 8 pixels (code and attr/color simultaneous) 
--  1 access to ram(2 bytes) for background every 8 pixels (code and attr/color simultaneous)
--  8 access to ram(3 bytes) for sprites every 8 pixels (code, attr and color simultaneous) 
--  1 access to fg graphix rom every 8 pixels (1 color bit / pixel) for foreground scan machine
--  2 access to bg graphix rom every 8 pixels (2 color bits / pixel) for background scan machine
--  8 access to sp graphix rom every 8 pixels (3 color bits / pixel) for sprite scan machine
--  2 access to sound ram every 2 pixels for sound machine 
--
--  sprite machine should access ram and rom graphics often enough to allow many sprites on the same scan line. 
--
--       hcnt   |          0         |            1             |          2          |            3             |
--       slot   |   0  |   1  |   2  |    3   |   4    |   5    |   0   |   1  |   2  |    3   |   4    |   5    |
--       slot16 |   0  |   1  |   2  |    3   |   4    |   5    |   6   |   7  |   8  |    9   |  10    |  11    |
-- ram   access | cpu1 | cpu2 | cpu3 | fg ram | sp ram | sp ram |  cpu1 | cpu2 | cpu3 | bg ram | sp ram | sp ram |
-- rom   access | cpu1 | cpu2 | cpu3 | sp gfx0| sp gfx1| fg gfx |  cpu1 | cpu2 | cpu3 | sp gfx0| sp gfx1| bg gfx0|
-- sound access | cpu1 | cpu2 | cpu3 | sndram | n.u.   | sndram |  cpu1 | cpu2 | cpu3 | sndram | n.u.   | sndram |

--       hcnt   |          4         |            5             |          6          |            7             |
--       slot   |   0  |   1  |   2  |    3   |   4    |   5    |   0   |   1  |   2  |    3   |   4    |   5    |
--       slot16 |  12  |  13  |  14  |   15   |  16    |  17    |  18   |  19  |  20  |   21   |  22    |  23    |
-- ram   access | cpu1 | cpu2 | cpu3 |    x   | sp ram | sp ram |  cpu1 | cpu2 | cpu3 |    x   | sp ram | sp ram |
-- rom   access | cpu1 | cpu2 | cpu3 | sp gfx0| sp gfx1| bg gfx1|  cpu1 | cpu2 | cpu3 | sp gfx0| sp gfx1|   x    |
-- sound access | cpu1 | cpu2 | cpu3 | sndram | n.u.   | sndram |  cpu1 | cpu2 | cpu3 | sndram | n.u.   | sndram |


-- remenber that enable signals are one slot early

process (clock_18, hcnt)
begin 
	if rising_edge(clock_18) then
		slot24  <= slot24 + "00001";
		slot    <= slot + "001";

		if slot = "101" then
			if (hcnt(2 downto 0) = "111") then slot24 <= (others=>'0'); end if;
			if (hcnt(0) = '1'  ) then
				slot   <= "000";
			else
				slot   <= "011"; -- ensure slot and hcnt well synchronised
			end if;
		end if;
	end if;
end process;

process (clock_18)
begin
 if rising_edge(clock_18) then
  ena_vidgen      <= '0';
	ena_snd_machine <= '0';
  cpu1_ena   <= '0';
  cpu2_ena   <= '0';
  cpu3_ena   <= '0';
	ena_sprite       <= '0';
	ena_sprite_grph0 <= '0';
	ena_sprite_grph1 <= '0';
	cs54xx_ena       <= '0';

	if slot = "100" or slot = "001" then ena_vidgen       <= '1';	end if;	 
	if slot = "010" or slot = "100" then ena_snd_machine  <= '1';	end if;	 -- sound ram access
	if slot = "011" or slot = "100" then ena_sprite       <= '1';	end if;  -- ram_bus access (wram : sp regs)
	if slot = "010"  then ena_sprite_grph0 <= '1';	end if;  -- rom_bus access (graphx)
	if slot = "011"  then ena_sprite_grph1 <= '1';	end if;  -- rom_bus access (graphx)
	
--	if slot = "101" and (cpu1_addr /= sw(15 downto 0) or cpu1_m1_n = '1') then cpu1_ena <= '1';	end if;
--	if slot = "101" and (cpu1_addr /= X"3bb2" or cpu1_m1_n = '1') then cpu1_ena <= '1';	end if;
--	if slot = "101" and (cpu1_addr /= X"030e" or cpu1_m1_n = '1') then cpu1_ena <= '1';	end if; -- stopped @ grid display

	if slot = "101" then cpu1_ena <= '1';	end if;	
	if slot = "000" then cpu2_ena <= '1';	end if;	
	if slot = "001" then cpu3_ena <= '1';	end if;
		
	if slot24 = "00000" then cs54xx_ena <= '1';	end if;	 
--	if slot24 = "00000" or slot24 = "01100" then cs54xx_ena <= '1';	end if;	 
--	if slot = "000" or slot = "011" then cs54xx_ena <= '1';	end if;	 
	
 end if;
end process;

--- SPRITES MACHINE ---
-----------------------
-- Sprite machine makes use of two video memory lines. Read and write process are toggled every other line. 
--
-- At each video line sprite machine has to scan all 64 sprite registers.
-- sprite_num holds which one of the 64 sprite is currently selected.
-- Process consist of :
--   * check from vertical sprite position, vertical sprite size and current video line 
--     if sprite belong to current video line, if not go to next sprite
--   * if sprite belong to current video line, collect sprite code, sprite attributes
--     and sprite color (color_set)
--   * then with sprite code collect sprite graphix data from gfx rom, 
--     1.5 bytes for each 4 pixels, sprite is 16 or 32 pixels depending on horizontal size
--     (2 bytes are actulally read but only 1/2 of one of these 2 bytes is use)
--   * for each 1.5 bytes collected serialise 3bits of graphix data
--   * use serialized graphix data together with color_set to build palette rom address and
--     get actual color from palette rom
--   * fill shadow sprite memory with actual sprite color, sprite color has to be written
--     at the right address correponding to the horizontal position of the sprite. In that
--     process, sprites are written one after the others, as sprites may overlapped if the
--     'new' written color is not transparent color then the 'new' color replace the 'previous'
--     written color. Highest priority sprites are the latest to be written (CPU take care of this point)
--   * go to next sprite until the last one
--   
-- Shadow memory filled during one video line is read and displayed on the next line (CPU take care
-- of this point). After each pixel read, the memory data is cleaned so that the written process will
-- get a 'fresh empty' memory space (unlike the write process which only writes data where sprites are,
-- the read process will read and clean the entire memory line)

-- sprite registers content
--                                      |            even address          | - |    odd address   |	
-- wram1 : 0x8xxx - 0x8FFF : 64 sprites |                 pos v            | - |     pos h lsb    |
-- wram2 : 0x9xxx - 0x9FFF : 64 sprites |code msb|xxx|flip v|flip h|2xV|2xH| - |xxxxxxx|pos h  msb|  
-- wram3 : 0xAxxx - 0xAFFF : 64 sprites |                 code             | - |x|ena|   color    |

sp_scan_addr <= sprite_num & sprite_state(0); -- toggle odd/even wram address, valid when sprite_state = "000" or "001"
sp_line      <= wram1_do + vcnt(7 downto 0);  -- wram1_do = sprite vertical position when sprite_state = "000" 
--sp_line <= X"B0" + vcnt(7 downto  0); -- dbg

process (clock_18, ena_sprite)
begin
 if rising_edge(clock_18) then 
  -- restart start machine at begining of line, start with the first sprite
	if hcnt = std_logic_vector(to_unsigned(128,9)) then
		sprite_num   <= "000000";
		sprite_state <= "000";
		sp_ram_rd_addr<= "111110000";
	end if;
	-- when ena_sprite = '1' wrams are adressed by sp_scan_addr, sprite regs can be collected
	if ena_sprite = '1' and sprite_state = "000" then
		sprite_code <= wram3_do;
		sprite_attr <= wram2_do; 
--		sprite_code <= sw(7 downto 0); -- dbg
--		sprite_attr <= sw(15 downto 8); -- dbg
		sprite_vcnt <= sp_line(4 downto 0);
		-- sprite belong to current horizontal line ? yes go to next state
		if  sp_line(7 downto 4) = "1111" or 											-- size V x 1
		   (sp_line(7 downto 5) = "111" and wram2_do(1)='1' )then -- size V x 2
--		   (sp_line(7 downto 5) = "111" and sw(9) ='1') then --  dbg
			sprite_state <= "001";
		-- sprite doen't belong to current horizontal line
		else
			-- if 64th sprite reached stop sprite machine 
			if sprite_num = "111111" then
				sprite_state <= "111";
			-- if not 64th sprite go to next sprite
			else
				sprite_num <= sprite_num + "000001";			
				sprite_state <= "000";
			end if;		
		end if;	
	end if;

	-- get sprite color set
	-- prepare first shadow ram write position with respect to sprite horizontal position
	-- prepare sprite_hcnt to get first grpahics data (2 or 4 differents graphics may be used for one video line)
	if ena_sprite = '1' and sprite_state = "001" then
		sprite_color   <= wram3_do;
		sp_ram_wr_addr <= wram2_do(0) & wram1_do; -- pos h
		sprite_hcnt    <= "00000";
		sprite_state   <= "010";
	end if;

	-- when ena_sprite_grph0 ='1' gfx rom are addressed with first data of current sprite_code
	-- collect first graphic byte	
	if ena_sprite_grph0 = '1' and sprite_state = "010" then
		sp_grphx_0 <= rom_bus_do;
		sprite_state <= "011";
	end if;
	
	-- when ena_sprite_grph1 ='1' gfx rom are addressed with second data of current sprite_code
	-- collect second graphic byte, keep only 4lsb or 4msb depending on sprite attribut and code	
	if ena_sprite_grph1 = '1' and sprite_state = "011" then
		if sprite_attr(7) = '0' then
			if sprite_code(7) = '0' then
				sp_grphx_1 <= rom_bus_do(3 downto 0);
			else
				sp_grphx_1 <= rom_bus_do(7 downto 4);
			end if;
		else
			sp_grphx_1 <= X"0";
		end if;
		sprite_state <= "100";
	end if;

	-- write process to shadow memory
  -- manage sprite_hcnt to get correct graphics rom address
	-- loop to state "010" to get graphics data, fill 4 pixels at each loop
	-- loop until 16 or 32 pixels written depending on sprite horizontal size
	-- when done, go to next sprite
	if sprite_state = "100" then
		sprite_hcnt <= sprite_hcnt + "00001";
		sp_ram_wr_addr <= sp_ram_wr_addr + "000000001";
		if sprite_hcnt(1 downto 0) = "11" then sprite_state <= "010"; end if; -- go seek for next graphx data
		if 	(sprite_hcnt = "01111" and sprite_attr(0) = '0' ) or   -- size H x 1
				(sprite_hcnt = "11111" and sprite_attr(0) = '1' ) then -- size H x 2
			if sprite_num = "111111" then
				sprite_state <= "111";
			else
				sprite_num <= sprite_num + "000001";			
				sprite_state <= "000";
			end if;		
		end if;
	end if;
	
	-- read process
	-- get color from either ram
	if slot = "000" or slot = "011" then
		if vcnt(0) = '1' then
			sp_color_rd <= sp_ram2_do;
		else
			sp_color_rd <= sp_ram1_do;
		end if;
	end if;
	
	-- clear ram after reading
	sp_ram_clr <= '0';
	if slot = "001" or slot = "100" then
		sp_ram_clr <= '1';
	end if;
	
	-- next read address
	if slot = "010" or slot = "101" then
		sp_ram_rd_addr <= sp_ram_rd_addr + "000000001";
	end if;

 end if;
end process;

-- write to shadow ram if sprite color ready and not transparent
sp_ram_we <= '1' when sprite_state = "100" and sp_color_wr/=X"00" else '0';
-- toggle read or write address on odd/even line (vertical) number 
sp_ram1_addr <= sp_ram_wr_addr when vcnt(0) = '1' else sp_ram_rd_addr;
sp_ram2_addr <= sp_ram_wr_addr when vcnt(0) = '0' else sp_ram_rd_addr;
-- toggle sprite color or clear data to be written on odd/even line (vertical) number 
sp_ram1_di  <= sp_color_wr(6 downto 0) when vcnt(0) = '1' else "1111111";
sp_ram2_di  <= sp_color_wr(6 downto 0) when vcnt(0) = '0' else "1111111";
-- toggle sprite write command or clear command on odd/even line (vertical) number 
sp_ram1_we <= sp_ram_we when vcnt(0) = '1' else sp_ram_clr;
sp_ram2_we <= sp_ram_we when vcnt(0) = '0' else sp_ram_clr;

-- build sprite code from both parts
sp_code_ext  <= '0'&sprite_code when sprite_attr(7) = '0' else "100"&sprite_code(5 downto 0);
-- prepare flip masks
spflip_H <= sprite_attr(2) xor flip_h; spflip_2H <= spflip_H & spflip_H;
spflip_V <= sprite_attr(3); spflip_2V <= spflip_V & spflip_V;
-- finish preparing flip mask from flip attribute (flip v, flip h) and with respect to sprite size (2xV, 2xH) 
with sprite_attr(1 downto 0) select
spflips <= 	"0000000"                       & spflip_V & spflip_2H & spflip_V & spflip_2V when "00",
						"000000"  &            spflip_H & spflip_V & spflip_2H & spflip_V & spflip_2V when "01",
						"00000"   & spflip_V & '0'      & spflip_V & spflip_2H & spflip_V & spflip_2V when "10",
						"00000"   & spflip_V & spflip_H & spflip_V & spflip_2H & spflip_V & spflip_2V when others;

-- set graphics rom address (external) from sprite code, flip mask, sprite size (2xV, 2xH), sprite horizontal tile and vertical line 
-- rom data will be latch within sprite machine loop at sprite_state = "010" and sprite_state = "011"  
with sprite_attr(1 downto 0) select
sp_grphx_addr <=  (sp_code_ext(8 downto 0)                                    & sprite_vcnt(3) & sprite_hcnt(3 downto 2) & sprite_vcnt(2 downto 0) ) xor spflips when "00",
									(sp_code_ext(8 downto 1) & 						      sprite_hcnt(4)  & sprite_vcnt(3) & sprite_hcnt(3 downto 2) & sprite_vcnt(2 downto 0) ) xor spflips when "01",
									(sp_code_ext(8 downto 2) & sprite_vcnt(4) & sp_code_ext(0)  & sprite_vcnt(3) & sprite_hcnt(3 downto 2) & sprite_vcnt(2 downto 0) ) xor spflips when "10",
									(sp_code_ext(8 downto 2) & sprite_vcnt(4) & sprite_hcnt(4)  & sprite_vcnt(3) & sprite_hcnt(3 downto 2) & sprite_vcnt(2 downto 0) ) xor spflips when others;

-- set palette rom address with sprite color_set and serialized sprite graphics (1.5byte => 3bits) with respect to horizontal flip cmd
sp_palette_addr <= sprite_color(5 downto 0) &
									sp_grphx_1(to_integer(unsigned(      ((not sprite_hcnt(1 downto 0)) xor spflip_2H )))) &
									sp_grphx_0(to_integer(unsigned('1' & ((not sprite_hcnt(1 downto 0)) xor spflip_2H )))) &
									sp_grphx_0(to_integer(unsigned('0' & ((not sprite_hcnt(1 downto 0)) xor spflip_2H )))); 
-- get sprite_color to be written from color palette or transparent (00) if color_set > 63
with sprite_color(6) select
	sp_color_wr <= sp_palette_msb_do(3 downto 0) & sp_palette_lsb_do(3 downto 0) when '0', X"00" when others; 

--- FOREGROUND/BACKGROUND TILES MACHINE ---
-------------------------------------------

-- synchronise offsets update out of displayed video
-- to avoid horizontal shrink
process (clock_18, slot24)
begin
 if rising_edge(clock_18) and vcnt = "000000000" then 

--  bg_offset_h  <= "111110000";--sw(8 downto 0); -- dbg
--  bg_offset_v  <= "001000000";--sw(17 downto 9); -- dbg
--  fg_offset_h  <= "111110000";--sw(8 downto 0); -- dbg
--  fg_offset_v  <= "001000000";--sw(17 downto 9); -- dbg
	
		bg_offset_hs <= bg_offset_h + ('1'&X"6C"); --sw(8 downto 0);--('1'&X"6B"); -- dbg
		bg_offset_vs <= bg_offset_v + ('0'&X"FE"); --sw(17 downto 9);--('0'&X"FE"); -- dbg
 end if;
end process;

-- set bg/fg scan tile ram address with respect to h/v video counter and h/v offset.
-- for horizontal offset only 6 msb (8-3) are used to get synchronized with 8 pixels addressing process.
-- for background the 3 lsb (2-0) will be use to control a shift register to finish horizontal scrolling. 
-- even in original there is no provision to finish horizontal scrolling for foreground. 
bg_scan_h    <= hcnt + (bg_offset_hs(8 downto 3) & "000");
bg_scan_v    <= vcnt +  bg_offset_vs;
bg_scan_addr <= bg_scan_v(7 downto 3) & bg_scan_h(8 downto 3);

fg_offset_hs <= fg_offset_h + ('1'&X"77"); --sw(8 downto 0);--('1'&X"77"); -- dbg
fg_offset_vs <= fg_offset_v + ('0'&X"00"); --sw(17 downto 9);--('0'&X"00"); -- dbg

fg_scan_h    <= hcnt + (fg_offset_hs(8 downto 3) & "000");
fg_scan_v    <= vcnt +  fg_offset_vs;
fg_scan_addr <= fg_scan_v(7 downto 3) & fg_scan_h(8 downto 3);
	
process (clock_18, slot24)
begin
 if rising_edge(clock_18) then
    -- get code, attr (inc. color_set), graphics with respect to slot and rom/ram addressing scheme
		-- 1 graphics byte => 8 pixels of 2 colors for foreground (1 color 1 transparent)
	  -- 2 graphics bytes => 8 pixels of 4 colors for background (one the 4 colors could be transparent depending on bg color_set)	
		if slot24 = "00011" then 
			fg_code_p <= code_ram_do;
			fg_attr_p <= attr_ram_do;
		end if;
		if slot24 = "00101" then 
			fg_grphx_p <= rom_bus_do;
		end if;
		if slot24 = "01001" then 
			bg_code_p <= code_ram_do;
			bg_attr_p <= attr_ram_do;
		end if;
		if slot24 = "01011" then
			bg_grphx_0_p <= rom_bus_do;
		end if;
		if slot24 = "10001" then 
			bg_grphx_1_p <= rom_bus_do;
		end if;		
		-- synchronise graphics and attributes at end of current tile for fg and bg
		if slot24 = "10111" then 
			fg_attr <= fg_attr_p;
			bg_attr <= bg_attr_p;
			fg_code <= fg_code_p;
			bg_code <= bg_code_p;
			-- flip h foreground graphics if needed
			if fg_attr_p(6) = '0' then
				fg_grphx   <= fg_grphx_p;
			else
				for k in 0 to 7 loop
					fg_grphx(k) <= fg_grphx_p(7-k);
				end loop;			
			end if;			
			-- flip h background grphics if needed
			if bg_attr_p(6) = '0' then
			  bg_grphx_0 <= bg_grphx_0_p;
			  bg_grphx_1 <= bg_grphx_1_p;
			else
				for k in 0 to 7 loop
					bg_grphx_0(k) <= bg_grphx_0_p(7-k);
					bg_grphx_1(k) <= bg_grphx_1_p(7-k);
				end loop;
			end if;			
		end if;
 end if;
end process;

-- set bg graphics rom address (external) from bg tile code, vertical bg line with respect to vertical flip
-- rom data will be latch within bg/fg machine for slot24 = "01011" and slot24 = "10001"  
with bg_attr_p(7) select
bg_grphx_addr <= 	bg_attr_p(0) & bg_code_p & bg_scan_v(2 downto 0) when '0',
									bg_attr_p(0) & bg_code_p & not bg_scan_v(2 downto 0) when others;

-- set fg graphics rom address (external) from fg tile code, vertical fg line with respect to vertical flip
-- (flip H is used to access rom horizontal flipped character)
-- rom data will be latch within bg/fg machine for slot24 = "00101"  
with fg_attr_p(7) select
fg_grphx_addr <= 	flip_h & fg_code_p & fg_scan_v(2 downto 0) when '0',
									flip_h & fg_code_p & not fg_scan_v(2 downto 0) when others; 

-- serialize bg graphics (2 bits / pixel)
bg_bits <= bg_grphx_0(to_integer(unsigned(hcnt(2 downto 0) xor "111"))) &
					 bg_grphx_1(to_integer(unsigned(hcnt(2 downto 0) xor "111" ))) ;

-- serialize fg graphics (1 bit / pixel)
fg_bit <= fg_grphx(to_integer(unsigned(hcnt(2 downto 0)  xor "111")));

-- set bg palette with bg color_set and bg serialized graphic bits
bg_palette_addr <= bg_attr(1 downto 0) & bg_code(7) & bg_attr(5 downto 2) & bg_bits;

process (clock_18, ena_vidgen)
begin
 if rising_edge(clock_18) and ena_vidgen = '1' then
    -- 7 pixels length delay line feed with bg color 6bits  
		bg_color_delay_0 <= bg_color_delay_0(6 downto 0) & bg_palette_lsb_do(0);
		bg_color_delay_1 <= bg_color_delay_1(6 downto 0) & bg_palette_lsb_do(1);
		bg_color_delay_2 <= bg_color_delay_2(6 downto 0) & bg_palette_lsb_do(2);
		bg_color_delay_3 <= bg_color_delay_3(6 downto 0) & bg_palette_lsb_do(3);
		bg_color_delay_4 <= bg_color_delay_4(6 downto 0) & bg_palette_msb_do(0);
		bg_color_delay_5 <= bg_color_delay_5(6 downto 0) & bg_palette_msb_do(1);
		
		-- select delay line output to finish bg horizontal scrolling with respect to 3 lsb bits
		bg_color(0) <= bg_color_delay_0(to_integer(unsigned(not bg_offset_hs(2 downto 0))));
		bg_color(1) <= bg_color_delay_1(to_integer(unsigned(not bg_offset_hs(2 downto 0))));
		bg_color(2) <= bg_color_delay_2(to_integer(unsigned(not bg_offset_hs(2 downto 0))));
		bg_color(3) <= bg_color_delay_3(to_integer(unsigned(not bg_offset_hs(2 downto 0))));
		bg_color(4) <= bg_color_delay_4(to_integer(unsigned(not bg_offset_hs(2 downto 0))));
		bg_color(5) <= bg_color_delay_5(to_integer(unsigned(not bg_offset_hs(2 downto 0))));
		
		-- set fg color or transparent color with respect to fg serialized graphic bit
		if fg_bit = '1' then
			fg_color <= "0"&fg_attr(1 downto 0) & fg_attr(5 downto 2);
		else
			fg_color <= "1111111"; 
		end if;
		
 end if;
end process;
 
--- VIDEO MUX ---
-----------------

process (clock_18, ena_vidgen)
begin
 if rising_edge(clock_18) and ena_vidgen = '1'then
  -- set rbg palette address prior with fg color if < 63 
	-- or with sprite color if not transparent
	-- otherwise with background color
  if fg_color(6)='0' then
		rgb_palette_addr <= '0' & fg_color;	
	else
	  if sp_color_rd /= "1111111" then
			rgb_palette_addr <= "0" & sp_color_rd;	
		else
			rgb_palette_addr <= "00" & bg_color;	
		end if;
	end if;
 end if;
end process;

process (clock_18, ena_vidgen)
begin
 -- output rbg color from rbg palette
 if rising_edge(clock_18) then
		video_r <= rgb_palette_red_do(3 downto 0);
		video_g <= rgb_palette_green_do(3 downto 0);
		video_b <= rgb_palette_blue_do(3 downto 0);		
 end if;
end process;

--- TERRAIN MAP ---
-------------------
-- bs1/bs0 are set by CPU to retrieve to background area tile code and attribut.
-- seems that terrain map is addressed as 2x2 tile area that can be flipped h/v during read

terrain_2a_rom_addr <=  terrain_bs1(6 downto 1) & terrain_bs0(7 downto 2);
terrain_2b_rom_addr <=  terrain_bs1(6 downto 1) & terrain_bs0(7 downto 1);

terrain_mux_do <= terrain_2a_rom_do(2 downto 0) when terrain_bs0(1) = '0' else terrain_2a_rom_do(6 downto 4);

terrain_2c_rom_addr <=  hcnt(0) & terrain_mux_do(0) & -- hcnt(2) is used but any fast enough toggling signal would be ok. 
												terrain_2b_rom_do &
												(terrain_bs1(0) xor terrain_mux_do(1)) &
												(terrain_bs0(0) xor terrain_mux_do(2));

-- prepare both bb0/bb1 output registers to be read when CPU will required
-- register holds tile code and attribut that will be written to bg wram.
-- bg wram is written coherently with horizontal scrolling out of displayed zone  
process (clock_18, ena_vidgen)
begin
 if rising_edge(clock_18) then
		if hcnt(0) = '0' then
			terrain_bb0 <=  (terrain_mux_do(1) xor terrain_2c_rom_do(6)) &
											(terrain_mux_do(2) xor terrain_2c_rom_do(7)) &
											terrain_2c_rom_do(5 downto 0);
		else
			terrain_bb1 <=  terrain_2c_rom_do;
		end if;
 end if;
end process;

-- select and return which register is addressed 
terrain_do <= terrain_bb0 when ram_bus_addr(0) = '0' else terrain_bb1; 

--- SOUND MACHINE ---
---------------------

-- resynchronisation of hcnt with respect to ena_snd_machine
-- there is to be one (and only one) ena_snd_machine during 1 pixel
process (clock_18)
begin
 if rising_edge(clock_18) then
		hcnt_r <= hcnt;
 end if;
end process;


sound_machine : entity work.sound_machine
port map(
clock_18  => clock_18,
ena       => ena_snd_machine,
hcnt      => hcnt_r(5 downto 0),
cpu_addr  => ram_bus_addr(3 downto 0), 
cpu_do    => mux_cpu_do(3 downto 0), 
ram_0_we  => snd_ram_0_we,
ram_1_we  => snd_ram_1_we,
audio     => snd_audio
);

--- CPUS -------------
----------------------

-- rom address multiplexer
-- should reflect content of xevious_cpu_gfx_8/16bits.bin loaded to external memory
rom_bus_addr <= "000"   & cpu1_addr(13 downto 0) when cpu1_ena = '1'   else -- 0x0_0000 - 0x0_3FFF : 16K prog cpu1
								"0010"  & cpu2_addr(12 downto 0) when cpu2_ena = '1'   else -- 0x0_4000 - 0x0_5FFF :  8K prog cpu2
 				  			"00110" & cpu3_addr(11 downto 0) when cpu3_ena = '1'   else -- 0x0_6000 - 0x0_6FFF :  4K prog cpu3
								"00111" & fg_grphx_addr          when slot24 = "00101" else -- 0x0_7000 - 0x0_7FFF :  4K fg grphx   
								"01000" & bg_grphx_addr          when slot24 = "01011" else -- 0x0_8000 - 0x0_8FFF :  4K bg grphx1   
								"01001" & bg_grphx_addr          when slot24 = "10001" else -- 0x0_9000 - 0x0_9FFF :  4K bg grphx2
								('0'&X"A000") + ("00"&sp_grphx_addr) when ena_sprite_grph0 = '1' else -- 0x0_A000 - 0x0_EFFF : 20K sp grphx1 -- ajouter '0_1010_0000_0000_0000'   
								('0'&X"F000") + ("0000"&sp_grphx_addr(12 downto 0)) when ena_sprite_grph1 = '1' else -- 0x0_F000 - 0x1_0FFF :  8K sp grphx2 -- ajouter '0_1111_0000_0000_0000'     
								'0'&X"A5A5"; -- sighting mark

-- ram address multiplexer
ram_bus_addr <= cpu1_addr              when cpu1_ena = '1'   else 
								cpu2_addr              when cpu2_ena = '1'   else 
 								cpu3_addr              when cpu3_ena = '1'   else 
								"00000" & fg_scan_addr when slot24 = "00011" else -- X000-X7FF => B000-B7FF (fg code) / C000-C7FF (fg attr)
								"00001" & bg_scan_addr when slot24 = "01001" else -- X800-XFFF => B800-BFFF (bg code) / C800-CFFF (bg attr)
								"000001111" & sp_scan_addr;                       -- X780-X7FF => wram1/2/3 (sprite registers)

-- cpu data out multiplexer
with slot select
mux_cpu_do <= 	cpu1_do when "000",
								cpu2_do when "001",
								cpu3_do when "010",
								X"00"   when others;

-- cpu we multiplexer
mux_cpu_we <= 	(not cpu1_wr_n and cpu1_ena)or
								(not cpu2_wr_n and cpu2_ena)or
								(not cpu3_wr_n and cpu3_ena);

-- cpu mreq multiplexer
mux_cpu_mreq <= 	(not cpu1_mreq_n and cpu1_ena) or
									(not cpu2_mreq_n and cpu2_ena) or
									(not cpu3_mreq_n and cpu3_ena);
									
-- dispatch cpu(s) we to devices 
snd_ram_0_we <= '1' when mux_cpu_we = '1' and ram_bus_addr(15 downto 11) = "01101"  and ram_bus_addr(5 downto 4) = "00" else '0';
snd_ram_1_we <= '1' when mux_cpu_we = '1' and ram_bus_addr(15 downto 11) = "01101"  and ram_bus_addr(5 downto 4) = "01" else '0';
latch_we     <= '1' when mux_cpu_we = '1' and ram_bus_addr(15 downto 11) = "01101" else '0';
io_we        <= '1' when mux_cpu_we = '1' and ram_bus_addr(15 downto 11) = "01110" else '0';
wram0_we     <= '1' when mux_cpu_we = '1' and ram_bus_addr(15 downto 11) = "01111" else '0';
wram1_we     <= '1' when mux_cpu_we = '1' and ram_bus_addr(15 downto 12) = "1000"  else '0';
wram2_we     <= '1' when mux_cpu_we = '1' and ram_bus_addr(15 downto 12) = "1001"  else '0';
wram3_we     <= '1' when mux_cpu_we = '1' and ram_bus_addr(15 downto 12) = "1010"  else '0';
attr_ram_we  <= '1' when mux_cpu_we = '1' and ram_bus_addr(15 downto 12) = "1011"  else '0';
code_ram_we  <= '1' when mux_cpu_we = '1' and ram_bus_addr(15 downto 12) = "1100"  else '0';
port_we      <= '1' when mux_cpu_we = '1' and ram_bus_addr(15 downto 12) = "1101"  else '0'; -- x/y scroll offset, flip general
terrain_we   <= '1' when mux_cpu_we = '1' and ram_bus_addr(15 downto 12) = "1111"  else '0'; -- bs0/1

-- manage irq reset/enable, cpu1 and 2 reset, namco custom chips, misc. lacthes/registers
process (reset, clock_18n, io_we) 
	variable cs06XX_nmi_cnt : natural range 0 to 10000;
begin
 if reset='1' then
			irq1_clr_n  <= '0';
			irq2_clr_n  <= '0';
			nmion_n     <= '0';
			reset_cpu_n <= '0';
			cpu1_irq_n  <= '1';
			cpu2_irq_n  <= '1';
			cs51XX_coin_mode_cnt <= "000";
			cs51XX_data_cnt <= "00";
			cs50XX_cmd <= X"00";
			flip_h <= '0';	
			cs54xx_irq_n <= '1';
			cs54xx_irq_cnt <= X"0";
			cs50xx_irq_n <= '1';
			cs50xx_irq_cnt <= X"0";
			cs50xx_r0_port_in <= X"0";
			cs50xx_k_port_in <= X"0";
 else 
  if rising_edge(clock_18n) then 
		if latch_we = '1' and ram_bus_addr(5 downto 4) = "10" then 
			if ram_bus_addr(2 downto 0) = "000" then irq1_clr_n  <= mux_cpu_do(0); end if;
			if ram_bus_addr(2 downto 0) = "001" then irq2_clr_n  <= mux_cpu_do(0); end if;
			if ram_bus_addr(2 downto 0) = "010" then nmion_n     <= mux_cpu_do(0); end if;
			if ram_bus_addr(2 downto 0) = "011" then reset_cpu_n <= mux_cpu_do(0); end if;
		end if;
		
		if port_we = '1' then 
			if ram_bus_addr(6 downto 4) = "000" then bg_offset_h <= ram_bus_addr(0) & mux_cpu_do; end if;
			if ram_bus_addr(6 downto 4) = "001" then fg_offset_h <= ram_bus_addr(0) & mux_cpu_do; end if;
			if ram_bus_addr(6 downto 4) = "010" then bg_offset_v <= ram_bus_addr(0) & mux_cpu_do; end if;
			if ram_bus_addr(6 downto 4) = "011" then fg_offset_v <= ram_bus_addr(0) & mux_cpu_do; end if;
			if ram_bus_addr(6 downto 4) = "111" then flip_h <= mux_cpu_do(0); end if;
		end if;

		if terrain_we = '1' then 
			if ram_bus_addr(0) = '0' then terrain_bs0 <= mux_cpu_do; end if;
			if ram_bus_addr(0) = '1' then terrain_bs1 <= mux_cpu_do; end if;
		end if;

		if irq1_clr_n = '0' then 
		  cpu1_irq_n <= '1';
		elsif vcnt = std_logic_vector(to_unsigned(240,9)) and hcnt = std_logic_vector(to_unsigned(128,9)) then cpu1_irq_n <= '0';
 		end if;
		if irq2_clr_n = '0' then 
		  cpu2_irq_n <= '1';
		elsif vcnt = std_logic_vector(to_unsigned(240,9)) and hcnt = std_logic_vector(to_unsigned(128,9)) then cpu2_irq_n <= '0';
		end if;

		if cs54xx_irq_cnt = X"0" then 
		  cs54xx_irq_n <= '1';
		else 
			if cs54xx_ena = '1' then
				cs54xx_irq_cnt <= cs54xx_irq_cnt - '1';
			end if;
		end if;

		if cs50xx_irq_cnt = X"0" then 
		  cs50xx_irq_n <= '1';
		else 
			if cs54xx_ena = '1' then
				cs50xx_irq_cnt <= cs50xx_irq_cnt - '1';
			end if;
		end if;
	
		-- write to cs06XX
		if io_we = '1' then 
			-- write to data register (0x7000)
		  if ram_bus_addr(8) = '0' then
				-- write data to device#4 (cs54XX)
				if cs06XX_control(3 downto 0) = "1000" then
						-- write data for k and r#0 port and launch irq to advice cs50xx
						cs54xx_k_port_in <= mux_cpu_do(7 downto 4);
						cs54xx_r0_port_in <= mux_cpu_do(3 downto 0);
						cs54xx_irq_n <= '0';
						cs54xx_irq_cnt <= X"7";						
				end if;
				-- write data to device#1 (cs51XX)
				if cs06XX_control(3 downto 0) = "0001" then
					-- when not in coin mode
					if cs51XX_coin_mode_cnt = "000" then
						-- if data = 1 enter coin mode for next 4 write operations
						if mux_cpu_do(2 downto 0) = "001" then
							cs51XX_coin_mode_cnt <= "100";
						end if;
						-- if data = 2 enter credit mode
						if mux_cpu_do(2 downto 0) = "010" then
							cs51XX_switch_mode <= '0';
							cs51XX_credit_mode <= '1';
							cs51XX_data_cnt <= "00";
						end if;
						-- if data = 5 enter switch mode 
						if mux_cpu_do(2 downto 0) = "101" then
							cs51XX_switch_mode <= '1';  -- '1' for galaga '0' for xevious (see klugde mode ) TBC
							cs51XX_credit_mode <= '0';
							cs51XX_data_cnt <= "00";
						end if;
					-- when in coin mode	
					else
						-- written coin/credit data are ignored atm 
						-- only count down to exit coin_mode (request 4 write operations)
						cs51XX_coin_mode_cnt <= cs51XX_coin_mode_cnt - "001";
					end if;	
				end if;
				-- write data to device#3 (cs50XX)
-- rough emulation
				if cs06XX_control(3 downto 0) = "0100" then
						-- keep written data as cmd and reset read counter
						cs50XX_cmd <= mux_cpu_do;
						cs50XX_data_cnt <= "00";     -- !!!! cs51xx_data_cnt TBC
				end if;

-- mb88 emulation
				if cs06XX_control(3 downto 0) = "0100" then
				-- write data for k and r#0 port and reset irq counter
						cs5Xxx_rw <= cs06XX_control(4);
						cs50xx_k_port_in <= mux_cpu_do(7 downto 4);
						cs50xx_r0_port_in <= mux_cpu_do(3 downto 0);
						cs50xx_irq_n <= '0';
						cs50xx_irq_cnt <= X"7";						
				end if;

				
			end if;
			
			-- write to control register (0x7100) 
			-- data(3..0) select custom chip 50xx/51xx/54xx
			-- data (4)   read/write mode for custom chip (1 = read mode)
			if ram_bus_addr(8) = '1' then
				cs06XX_control <= mux_cpu_do;
			  -- start/stop nmi timer (stop if no chip selected)
				if mux_cpu_do(3 downto 0) = "0000" then
					cs06XX_nmi_cnt := 0;  -- stop
					cpu1_nmi_n <= '1';
				else
					cs06XX_nmi_cnt := 1;  -- start
					
					if mux_cpu_do(4 downto 0) = "10100" then  -- prepare next read to cs50xx
						cs5Xxx_rw <= mux_cpu_do(4);             -- *must* launch irq to cs50xx
						cs50xx_irq_n <= '0';          
						cs50xx_irq_cnt <= X"7";						
					end if;

				end if;
			end if;
		end if;	
		
		-- generate periodic nmi when timer is on
		if cs06XX_nmi_cnt >= 1 then
			if cpu1_ena = '1' then  -- to get 333ns tick
--				-- 600 * 333ns = 200µs
--				if cs06XX_nmi_cnt < 600 then  
				-- 2000 * 333ns = 666µs
				if cs06XX_nmi_cnt < 600 then  
					cs06XX_nmi_cnt := cs06XX_nmi_cnt + 1;
					cpu1_nmi_n <= '1';
				else
					cs06XX_nmi_cnt := 1;
					cpu1_nmi_n <= '0';
				end if;	
			end if;
		end if;
		
		-- manage cs06XX data read (0x7000)
		change_next <= '0';
		if mux_cpu_mreq = '1' and mux_cpu_we ='0' and ram_bus_addr(15 downto 11) = "01110" then
			if ram_bus_addr(8) = '0' then
				change_next <= '1';
			end if;
		end if ;
		-- cycle data_cnt at each read
		if change_next = '1' then
			if cs06XX_control(3 downto 0) = "0001" then
				if cs51XX_data_cnt = "10" then cs51XX_data_cnt <= "00"; 
				else cs51XX_data_cnt <= cs51XX_data_cnt + "01"; end if;
			end if;
			if cs06XX_control(3 downto 0) = "0100" then
				-- cs50xx (rough emulation)
				if cs50XX_data_cnt = "11" then cs50XX_data_cnt <= "00"; 
				else cs50XX_data_cnt <= cs50XX_data_cnt + "01"; end if;
				-- cs50xx (m88 emulation)
				cs5Xxx_rw <= cs06XX_control(4);  -- launch irq to request next read
				cs50xx_irq_n <= '0';
				cs50xx_irq_cnt <= X"7";						
	
			end if;				
		end if;
		
		-- manage credit count (bcd)
		--   increase at each coin up to 99
		coin_r <= coin;
		start1_r <= start1;
		start2_r <= start2;
		if coin = '1' and coin_r = '0' then 
			if credit_bcd_0 = "1001" then 
				if credit_bcd_1 /= "1001" then
					credit_bcd_1 <= credit_bcd_1 + "0001";
					credit_bcd_0 <= "0000";
				end if;
			else
				credit_bcd_0 <= credit_bcd_0 + "0001";
			end if; 
		end if;
		
	  -- decrease credit only when in credit mode
		-- CPU spy this counter to start a new game
		if cs51XX_credit_mode = '1' then
			  -- decreasing credit by 1 will start a new game for 1 player
			if (start1 = '1' and start1_r = '0') then
				cs51XX_credit_mode <= '0';
				if credit_bcd_0 = "0000" then 
					if credit_bcd_1 /= "0000" then
						credit_bcd_1 <= credit_bcd_1 - "0001";
						credit_bcd_0 <= "1001";
					end if;
				else
					credit_bcd_0 <= credit_bcd_0 - "0001";
				end if; 		
			end if;

		  -- decreasing credit by 2 (at once) will start a new game for 2 player
			if (start2 = '1' and start2_r = '0') then
				if credit_bcd_0 = "0000" or credit_bcd_0 = "0001" then
 					if credit_bcd_1 /= "0000" then
						cs51XX_credit_mode <= '0';
						credit_bcd_1 <= credit_bcd_1 - "0001";
						if credit_bcd_0 = "0000" then 
							credit_bcd_0 <= "1000";
						else
							credit_bcd_0 <= "1001";
						end if;
					end if;
				else
					cs51XX_credit_mode <= '0';
					credit_bcd_0 <= credit_bcd_0 - "0010";					
				end if;
			end if;
		end if;
		
  end if;
 end if;
end process;

-- namco cs51XX joy remap LUT (active for xevious)
buttons <= left & down & right & up;
with buttons select
joy <= X"8" when "0000",
       X"0" when "0001",
			 X"2" when "0010",
			 X"1" when "0011",
			 X"4" when "0100",
			 X"A" when "0101",
			 X"3" when "0110",
			 X"B" when "0111",
			 X"6" when "1000",
			 X"7" when "1001",
			 X"9" when "1010",
			 X"C" when "1011",
			 X"5" when "1100",
			 X"D" when "1101",
			 X"E" when "1110",
			 X"F" when others;

-- swicth mode reply with respect to reply rank
with cs51XX_data_cnt select
cs51XX_switch_mode_do <= 	not (left & '0' & right & '0' & left & '0' & right & '0' )         when "00",
													not (b_test & b_svce & '0' & coin & start2 & start1 & fire & fire) when "01",
													X"00" when others;	
-- N.U. (galaga configuration)
--cs51XX_switch_mode_do <= 	not (left2 & '0' & right2 & '0' & left1 & '0' & right1 & '0' )       when "00",
--													not (b_test & b_svce & '0' & coin & start2 & start1 & fire2 & fire1) when "01",
--													X"00" when others;	

-- non swicth mode reply with respect to reply rank
with cs51XX_data_cnt select
cs51XX_non_switch_mode_do <= 	credit_bcd_1 & credit_bcd_0 when "00", -- credits (cpu spy this to start a new game)
															"00" & not fire & '1' & joy when "01",
															X"38" when "10",
															X"00" when "11"; -- N.U.	
															
-- N.U. (galaga configuration)
--cs51XX_non_switch_mode_do <= 	credit_bcd_1 & credit_bcd_0 when "00", -- credits (cpu spy this)
--															not ("110" & fire1 & left1 & '0' & right1 & '0' ) when "01",
--															not ("110" & fire2 & left2 & '0' & right2 & '0' ) when "10",
--															X"00" when "11"; -- N.U.	

-- select reply with respect to current mode 
cs51XX_do <= cs51XX_switch_mode_do when cs51XX_switch_mode = '1' else cs51XX_non_switch_mode_do;

-- reply for cmd_80 mode (rough emulation)
with cs50XX_data_cnt select
cs50XX_cmd_80_do <= 	X"80" when "00",
											X"00" when "01",
											X"00" when "10",
										  X"05"	when others;	

-- reply for cmd_E5 mode (rough emulation)
with cs50XX_data_cnt select
cs50XX_cmd_E5_do <= 	X"F0" when "00",
											X"00" when "01",
											X"00" when "10",
										  X"95"	when others;	

-- select reply with respect to current mode (rough emulation)
--cs50XX_do <= cs50XX_cmd_80_do when cs50XX_cmd = X"80" else cs50XX_cmd_E5_do;
-- mb88 emulation
cs50XX_do <= cs50XX_oh_port_out & cs50XX_ol_port_out; -- keep this line for cs50xx true mb88 emulation

-- select custom chip reply depending on current control mode for data read request
with cs06XX_control(3 downto 0) select
cs06XX_di <= cs51XX_do when "0001",
						 cs50XX_do when "0100",
--						 cs54XX_do when "1000",
						 X"00" when others;

-- select reply depending on data or control read
cs06XX_do <= cs06XX_di when ram_bus_addr(8)= '0' else cs06XX_control;

-- trigger CPU3 nmi when enable during line 0x40 and 0x60
process (clock_18, nmion_n)
begin
 if nmion_n = '1' then
 elsif rising_edge(clock_18) and ena_vidgen = '1' then
		if hcnt = "100000000" then
			if vcnt = "001000000" or vcnt = "011000000" then cpu3_nmi_n <= '0'; end if;
			if vcnt = "001000001" or vcnt = "011000001" then cpu3_nmi_n <= '1'; end if;
		end if;
 end if;
end process;

-- multiplex ram/rom/devices data out to cpu di with respect to multiplexed cpu address
-- remenber : rom_bus_addr = ram_bus_addr for any cpu access (see addressing scheme)
with ram_bus_addr(15 downto 11) select
cpus_di <= 	rom_bus_do when "00000",
						rom_bus_do when "00001",
						rom_bus_do when "00010",
						rom_bus_do when "00011",
						rom_bus_do when "00100",
						rom_bus_do when "00101",
						rom_bus_do when "00110",
 						rom_bus_do when "00111",
						"000000" & dip_switch_do when "01101",
						cs06XX_do   when "01110",
						wram0_do    when "01111",
						wram1_do    when "10000",
						wram1_do    when "10001",
						wram2_do    when "10010",
						wram2_do    when "10011",
						wram3_do    when "10100",
						wram3_do    when "10101",
						attr_ram_do when "10110",
						attr_ram_do when "10111",
						code_ram_do when "11000",
						code_ram_do when "11001",
						terrain_do  when "11110", 
						terrain_do  when "11111", 
						X"00"       when others;

-- video address/sync generator
gen_video : entity work.gen_video
port map(
clk     => clock_18,
enable  => ena_vidgen,
hcnt    => hcnt,
vcnt    => vcnt,
--hsync   => open,
--vsync   => open,
hsync   => video_hs,
vsync   => video_vs,
csync   => video_csync,
blankn  => video_blankn
);

-- microprocessor Z80 - 1
cpu1 : entity work.T80se
generic map(Mode => 0, T2Write => 1, IOWait => 1)
port map(
  RESET_n => reset_n,
  CLK_n   => clock_18,
	CLKEN   => cpu1_ena,
  WAIT_n  => '1',
  INT_n   => cpu1_irq_n,
  NMI_n   => cpu1_nmi_n,
  BUSRQ_n => '1',
  M1_n    => cpu1_m1_n,
  MREQ_n  => cpu1_mreq_n,
  IORQ_n  => open,
  RD_n    => open,
  WR_n    => cpu1_wr_n,
  RFSH_n  => open,
  HALT_n  => open,
  BUSAK_n => open,
  A       => cpu1_addr,
  DI      => cpus_di,
  DO      => cpu1_do
);

-- microprocessor Z80 - 2
cpu2 : entity work.T80se
generic map(Mode => 0, T2Write => 1, IOWait => 1)
port map(
--  RESET_n => reset_n,
  RESET_n => reset_cpu_n,
  CLK_n   => clock_18,
	CLKEN   => cpu2_ena,
  WAIT_n  => '1',
  INT_n   => cpu2_irq_n,
  NMI_n   => '1', --cpu_int_n,
  BUSRQ_n => '1',
  M1_n    => cpu2_m1_n,
  MREQ_n  => cpu2_mreq_n,
  IORQ_n  => open,
  RD_n    => open,
  WR_n    => cpu2_wr_n,
  RFSH_n  => open,
  HALT_n  => open,
  BUSAK_n => open,
  A       => cpu2_addr,
  DI      => cpus_di,
  DO      => cpu2_do
);

-- microprocessor Z80 - 3
cpu3 : entity work.T80se
generic map(Mode => 0, T2Write => 1, IOWait => 1)
port map(
--  RESET_n => reset_n,
  RESET_n => reset_cpu_n,
  CLK_n   => clock_18,
	CLKEN   => cpu3_ena,
  WAIT_n  => '1',
  INT_n   => '1',
  NMI_n   => cpu3_nmi_n,
  BUSRQ_n => '1',
  M1_n    => cpu3_m1_n,
  MREQ_n  => cpu3_mreq_n,
  IORQ_n  => open,
  RD_n    => open,
  WR_n    => cpu3_wr_n,
  RFSH_n  => open,
  HALT_n  => open,
  BUSAK_n => open,
  A       => cpu3_addr,
  DI      => cpus_di,
  DO      => cpu3_do
);

-- mb88 - cs54xx (28 pins IC, 1024 bytes rom)
mb88_54xx : entity work.mb88
port map(
 reset_n    => reset_cpu_n, --reset_n,
 clock      => clock_18,
 ena        => cs54xx_ena,

 r0_port_in  => cs54xx_r0_port_in, -- pin 12,13,15,16
 r1_port_in  => X"0",
 r2_port_in  => X"0",
 r3_port_in  => X"0",
 r0_port_out => open,
 r1_port_out => cs54xx_audio_3,   -- pin 17,18,19,20 (resistor divider )
 r2_port_out => open,
 r3_port_out => open,
 k_port_in   => cs54xx_k_port_in, -- pin 24,25,26,27
 ol_port_out => cs54xx_audio_1,   -- pin  4, 5, 6, 7 (resistor divider 150K/22K)
 oh_port_out => cs54xx_audio_2,   -- pin  8, 9,10,11 (resistor divider  47K/10K)
 p_port_out  => open,

 stby_n    => '0',
 tc_n      => '0',
 irq_n     => cs54xx_irq_n,
 sc_in_n   => '0',
 si_n      => '0',
 sc_out_n  => open,
 so_n      => open,
 to_n      => open,
 
 rom_addr  => cs54xx_rom_addr,
 rom_data  => cs54xx_rom_do
);

-- cs54xx program ROM
cs54xx_prog : entity work.cs54xx_prog
port map(
 clk  => clock_18n,
 addr => cs54xx_rom_addr(9 downto 0),
 data => cs54xx_rom_do
);

-- mb88 - cs50xx (28 pins IC, 2048 bytes rom)
mb88_50xx : entity work.mb88
port map(
 reset_n    => reset_cpu_n, --reset_n,
 clock      => clock_18,
 ena        => cs54xx_ena, -- same clock for 50XX, 51XX, 54XX 

 r0_port_in  => cs50xx_r0_port_in,  -- pin 12,13,15,16 (data in 0-3)
 r1_port_in  => X"0",
 r2_port_in  => "000"&cs5Xxx_rw,    -- pin 21 (read '1', write '0')
 r3_port_in  => X"0",
 r0_port_out => open,
 r1_port_out => open,
 r2_port_out => open,
 r3_port_out => open,
 k_port_in   => cs50xx_k_port_in,   -- pin 24,25,26,27 (data in 4-7)
 ol_port_out => cs50xx_ol_port_out, -- pin  4, 5, 6, 7 (data out 0-3)
 oh_port_out => cs50xx_oh_port_out, -- pin  8, 9,10,11 (data out 4-7)
 p_port_out  => open,

 stby_n    => '0',
 tc_n      => '0',
 irq_n     => cs50xx_irq_n,
 sc_in_n   => '0',
 si_n      => '0',
 sc_out_n  => open,
 so_n      => open,
 to_n      => open,
 
 rom_addr  => cs50xx_rom_addr,
 rom_data  => cs50xx_rom_do
);

-- cs50xx program ROM
cs50xx_prog : entity work.cs50xx_prog
port map(
 clk  => clock_18n,
 addr => cs50xx_rom_addr(10 downto 0),
 data => cs50xx_rom_do
);



-- terrain map 2a ROM
terrain_2a : entity work.terrain_2a
port map(
 clk  => clock_18n,
 addr => terrain_2a_rom_addr,
 data => terrain_2a_rom_do
);

-- terrain map 2b ROM
terrain_2b : entity work.terrain_2b
port map(
 clk  => clock_18n,
 addr => terrain_2b_rom_addr,
 data => terrain_2b_rom_do
);

-- terrain map 2c ROM
terrain_2c : entity work.terrain_2c
port map(
 clk  => clock_18n,
 addr => terrain_2c_rom_addr,
 data => terrain_2c_rom_do
);

-- foreground/background attr RAM   0xB000-0xBFFF
attr_ram : entity work.gen_ram
generic map( dWidth => 8, aWidth => 12)
port map(
 clk  => clock_18n,
 we   => attr_ram_we,
 addr => ram_bus_addr(11 downto 0),
 d    => mux_cpu_do,
 q    => attr_ram_do
);

-- foreground/background code RAM   0xC000-0xCFFF
code_ram : entity work.gen_ram
generic map( dWidth => 8, aWidth => 12)
port map(
 clk  => clock_18n,
 we   => code_ram_we,
 addr => ram_bus_addr(11 downto 0),
 d    => mux_cpu_do,
 q    => code_ram_do
);
-- working RAM0   0x7800-0x7FFF
wram0 : entity work.gen_ram
generic map( dWidth => 8, aWidth => 11)
port map(
 clk  => clock_18n,
 we   => wram0_we,
 addr => ram_bus_addr(10 downto 0),
 d    => mux_cpu_do,
 q    => wram0_do
);
-- working/sprite register RAM1   0x8000-0x87FF / 0x8800-0x8FFF
wram1 : entity work.gen_ram
generic map( dWidth => 8, aWidth => 11)
port map(
 clk  => clock_18n,
 we   => wram1_we,
 addr => ram_bus_addr(10 downto 0),
 d    => mux_cpu_do,
 q    => wram1_do
);
-- working/sprite register RAM2   0x9000-0x97FF / 0x9800-0x9FFF
wram2 : entity work.gen_ram
generic map( dWidth => 8, aWidth => 11)
port map(
 clk  => clock_18n,
 we   => wram2_we,
 addr => ram_bus_addr(10 downto 0),
 d    => mux_cpu_do,
 q    => wram2_do
);
-- working/sprite register RAM3   0xA000-0xA7FF / 0xA800-0xAFFF
wram3 : entity work.gen_ram
generic map( dWidth => 8, aWidth => 11)
port map(
 clk  => clock_18n,
 we   => wram3_we,
 addr => ram_bus_addr(10 downto 0),
 d    => mux_cpu_do,
 q    => wram3_do
);
-- background palette lsb ROM
bg_palette_lsb : entity work.bg_palette_lsb
port map(
 clk  => clock_18n,
 addr => bg_palette_addr,
 data => bg_palette_lsb_do
);
-- background palette msb ROM
bg_palette_msb : entity work.bg_palette_msb
port map(
 clk  => clock_18n,
 addr => bg_palette_addr,
 data => bg_palette_msb_do
);

-- red palette ROM
red_palette : entity work.red
port map(
 clk  => clock_18n,
 addr => rgb_palette_addr,
 data => rgb_palette_red_do
);
-- red palette ROM
green_palette : entity work.green
port map(
 clk  => clock_18n,
 addr => rgb_palette_addr,
 data => rgb_palette_green_do
);
-- red palette ROM
blue_palette : entity work.blue
port map(
 clk  => clock_18n,
 addr => rgb_palette_addr,
 data => rgb_palette_blue_do
);

-- sprite RAM1
sp_ram1 : entity work.gen_ram
generic map( dWidth => 7, aWidth => 9)
port map(
 clk  => clock_18,
 we   => sp_ram1_we,
 addr => sp_ram1_addr,
 d    => sp_ram1_di,
 q    => sp_ram1_do
);

-- sprite RAM2
sp_ram2 : entity work.gen_ram
generic map( dWidth => 7, aWidth => 9)
port map(
 clk  => clock_18,
 we   => sp_ram2_we,
 addr => sp_ram2_addr,
 d    => sp_ram2_di,
 q    => sp_ram2_do
);

-- sprite palette lsb ROM
sp_palette_lsb : entity work.sp_palette_lsb
port map(
 clk  => clock_18n,
 addr => sp_palette_addr,
 data => sp_palette_lsb_do
);
-- sprite palette msb ROM
sp_palette_msb : entity work.sp_palette_msb
port map(
 clk  => clock_18n,
 addr => sp_palette_addr,
 data => sp_palette_msb_do
);

end struct;