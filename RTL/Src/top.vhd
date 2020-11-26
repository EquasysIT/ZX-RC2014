--------------------------------------------------------------------------
--																								--
--       ZX-RC2014 - ZX Spectrum ULA Board for RC2014 Modular CPU		   --
--																								--
-- Based on work by Chris Smith														--
-- HTTP://www.zxdesign.info/book/ 													--
--																								--
-- Version 1																				--
--																								--
--------------------------------------------------------------------------

-- Random corruption on the screen including dashed lines can be caused if Lyontek RAM is used for the memory. Cypress 62256 seems to be the most reliable

-- The output clock of 3.5Mhz from the CPLD has a lot of ringing and needs increasing from 3.3V to 5V. A 220 Ohm resistor removes the overshoot and ringing
-- and a SN74LV1T34 single gate buffer is used to increase the voltage from 3.3V to 5V
--
-- ---> Clock Output from CPLD ---> SN74LV1T34 ---> 220 Ohm resistor ---> Pin 21 on board ---> Clock input to Z80
--
-- Requirements:-
--
-- Original RC2014 Backplane Board
-- ZX-RC2014 ULA board should be located in slot 1
-- Original RC2014 RAM Module located in slot2 - This is the lower 16K for the ZX Spectrum and needs some modifications
-- Original RC2014 ROM Module located in slot3 - This is the ROM for the ZX Spectrum and some modifications required
-- Original RC2014 RAM Module located in slot4 - This is the upper 32K for the ZX Spectrum. No modifications required
-- Original RC2014 Z80 CPU Module located in slot 5


 
library ieee;
use ieee.std_logic_1164.all;
use IEEE.NUMERIC_STD.ALL;


entity top is
    port (

iCLK28       : in   std_logic;										
																			
oVVSync_n	 : out  std_logic;
oHHSync_n	 : out  std_logic;

									-- Pin 39 - Inverted Composite Sync
oRED	 	    : out  std_logic_vector( 3 downto 0);
oGREEN		 : out  std_logic_vector( 3 downto 0);
oBLUE			 : out  std_logic_vector( 3 downto 0);
																			
iA14         : in   std_logic;										
iA15         : in   std_logic;										
iA0			 : in   std_logic;
oROMCE       : out  std_logic;										

oRAMCE       : out  std_logic;
oRAMOE       : out  std_logic;
oRAMWE       : out  std_logic;

iMREQ        : in   std_logic;										
iWR          : in   std_logic;										
iRD          : in   std_logic;										
oCPU         : out  std_logic;
iCS          : in   std_logic;										
iULA_D       : inout std_logic_vector ( 7 downto 0 );			
                                                             	
iKB			 : in   std_logic_vector ( 4 downto 0 );      	

oVRAM_A      : out  std_logic_vector ( 13 downto 0 );			
						
oINT         : out  std_logic;										
                                                             	
oSOUND       : out  std_logic;										
oMIC         : out  std_logic;										                                                         
iEAR         : in   std_logic
 
    );                       
end entity;
        
architecture behavior of top is
 
begin

   ula1: entity work.ula 
	port map 
	(
        CLK28      => iCLK28,

        CPU        => oCPU,
		  
        RED			 => oRED,
		  GREEN		 => oGREEN,
		  BLUE		 => oBLUE,

        VVSync_n	 => oVVSync_n,
		  HHSync_n	 => oHHSync_n,
        
        A14        => iA14,            
        A15        => iA15,
		  A0	       => iA0,
        ROMCE      => oROMCE,
		  
		  RAMCE		 => oRAMCE,
		  RAMOE		 => oRAMOE,
		  RAMWE		 => oRAMWE,
		  
        MREQ       => iMREQ,        
        WR         => iWR,            
        RD         => iRD,            
                    
        VRAM_A     => oVRAM_A,         
                    
        ULA_D      => iULA_D,  
		  
		  KB			 => iKB,	
        		  
        INT        => oINT,            
                    
        CS         => iCS,            
                    
        SOUND      => oSOUND,         
        MIC        => oMIC,         
		  EAR        => iEAR
	  	  		  
    );
    
end architecture;
