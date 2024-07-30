Xevious Arcade for the Altera DE2-35 Dev Board.

Notes:
Controls are PS2 keyboard, see readme file in de2 folder for instructions.
Use the 2 included SRAM loader projects (parts 1 and 2) to load Xevious program and gfx prom code to the DE2 SRAM.

Build:
* Obtain correct roms file for Xevious, see make_xevious_proms script in tools/xevious_unzip folder for rom filenames.
* Unzip rom files to tools/xevious_unzip/roms folder.
* Run the make_xevious_proms script in the tools/xevious_unzip folder.
* Place generated prom files into proms folder (except the xevious cpu 1 and 2 and gfx prom files - see below)
* Place the xevious_cpu1.vhd and xevious_cpu2.vhd prom files inside the xevious sram_loader part 1/proms folder (see readme file inside the folder).
* Place the xevious_gfx.vhd prom file inside the xevious sram_loader part 2/proms folder (see readme file inside the folder).
* Compile and program the xevious sram loader part 1 project into DE2-35. (see readme file in sram loader folder).
* Compile and program the xevious sram loader part 2 project into DE2-35. (see readme file in sram loader folder).
* Open the xevious_de2 project file using Quartus and compile.
* Program DE2-35 Board.
