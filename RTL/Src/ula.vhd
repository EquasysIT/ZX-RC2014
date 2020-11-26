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

 
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ula is
port (

CLK28       : in   std_logic;										-- Pin 27 - CLK Input 28.0 MHz, from the board

-- RBG Outputs to AD724JR chip providing composite output to TV																	
VVSync_n    : out  std_logic;										-- Pin 81
HHSync_n    : out  std_logic;										-- Pin 82
RED			: out  std_logic_vector( 3 downto 0);			-- Pins 71 to 74
GREEN			: out  std_logic_vector( 3 downto 0);			-- Pins 66 - 68 & 70
BLUE			: out  std_logic_vector( 3 downto 0);			-- Pins 61,63 to 65

-- Interface to the Z80 CPU
A14         : in   std_logic;										-- Pin 49 - A14 Line Z80
A15         : in   std_logic;										-- Pin 50 - A15 Line Z80
A0	         : in   std_logic;										-- Pin 6  - A0 Line Z80
MREQ        : in   std_logic;										-- Pin 19 - MREQ Line Z80
WR          : in   std_logic;										-- Pin 18 - WR Z80 Line
RD          : in   std_logic;										-- Pin 17 - RD Line Z80
CPU         : out  std_logic;										-- Pin 22 - Clock output with contention to the Z80 CPU 3.5MHz
INT         : out  std_logic;										-- Pin 20 - Interruption of CPU. Occurs every 50Hz or 60Hz (VERT50_60 Depends)

-- Interface to ULA
CS          : in   std_logic;										-- Pin 16 - IORQ - Selects access to port 254 (Should also be ORed with A0)
ULA_D       : inout   std_logic_vector ( 7 downto 0 );	-- Pin 15 to 08 - ULA data bus
KB			   : in   std_logic_vector ( 4 downto 0 );      -- Pins 92 to 96 - Keyboard Input
SOUND       : out  std_logic;										-- Pin 86 - Sound Output 1 bit
MIC         : out  std_logic;										-- pin 86 - Audio Output for tape recorder     
EAR         : in   std_logic;										-- pin 86 - EAR Input 

-- Interface to SRAM
VRAM_A      : out  std_logic_vector ( 13 downto 0 ) := ( OTHERS => '0' );		
RAMCE       : out  std_logic;										-- Pin 04 - RAM enable line
RAMOE       : out  std_logic;										-- Pin 01 - RAM output enable line for reading
RAMWE       : out  std_logic;										-- Pin 06 - RAM write enable line for writing

-- Interface to ROM
ROMCE       : out  std_logic										-- Pin 01 - ROM enable line

    );
end entity;

architecture rtl of ula is

	 -- 14Mhz Clock
	 signal clk14	        : std_logic := '0';
    
	 -- Pixel Clock
	 signal clk7           : std_logic := '0';
	 
	 -- CPU Clock from ULA
    signal CPUClk         : std_logic := '0';

	 -- Horizontal & Vertical display counters
	 signal hc             : unsigned ( 8 downto 0 ) := ( OTHERS => '0' );
    signal vc             : unsigned ( 8 downto 0 ) := ( OTHERS => '0' );
	 
	 -- Latches to hold delayed versions of hc and vc display counters
	 signal c              : unsigned ( 8 downto 0 ) := ( OTHERS => '0' );
	 signal v              : unsigned ( 8 downto 0 ) := ( OTHERS => '0' );
    
	 -- Interrupt Signal
	 signal INT_n          : std_logic := '1';

	 -- Display control signals
    signal Border_n       : std_logic := '1';
    signal Vout           : std_logic := '1';
    signal SLoad          : std_logic := '0';
    signal AL1            : std_logic := '1';
    signal AL2            : std_logic := '1';
    signal AOLatch_n      : std_logic := '1';
    signal BitmapReg      : std_logic_vector ( 7 downto 0 ) := ( OTHERS => '0' );
    signal SRegister      : std_logic_vector ( 7 downto 0 ) := ( OTHERS => '0' );
    signal AttrReg        : std_logic_vector ( 7 downto 0 ) := ( OTHERS => '0' );
    signal AttrOut        : std_logic_vector ( 7 downto 0 ) := ( OTHERS => '0' );
    signal FlashCnt       : unsigned ( 5 downto 0 ) := ( OTHERS => '0' );
    signal Pixel          : std_logic := '0';
    
    signal rI,rR,rG,rB    : std_logic := '0';
	 signal rR_HL,rG_HL,rB_HL : std_logic := '0';
	
	 -- Display synchronisation signals
	 signal VSync_n        : std_logic := '1';
    signal HSync_n        : std_logic := '1';
    signal VBlank_n       : std_logic := '1';
    signal HBlank_n       : std_logic := '1';
	             
	 -- Border Mic and Speaker signals
    signal BorderColor    : std_logic_vector ( 2 downto 0 ) := "000";    
    signal rMic           : std_logic := '0';
    signal rSpk           : std_logic := '0';
	     
    -- IO Request from CPU to ULA
	 signal ioreq_n        : std_logic := '0';
    
	 -- ULA & CPU Contention Signals	 
	 signal CLKContention  : std_logic := '0';
	 signal cpubus_en		  : std_logic := '0';
    signal cdet1          : std_logic := '0';
    signal cdet2          : std_logic := '0';
    signal ioreqtw3       : std_logic := '0';
    signal mreqt23        : std_logic := '0';
	 	 
begin
	 
	 -- Onboard 28Mhz oscillator - CLK14 is 14Mhz Master Clock
    process ( clk28 )
    begin        
        if rising_edge( clk28 ) then
			clk14 <= not clk14;
		  end if;
    end process;

	 -- Clk7 Pixel Clock produced from 14Mhz clock
    process ( clk14 )
    begin        
        if rising_edge( clk14 ) then
			clk7 <= not clk7;
		  end if;
    end process;
	 
	 -- Horizontal counter
	 process ( clk7 )
    begin        
        if rising_edge( clk7 ) then
			 if hc = 447 then
				hc <= ( OTHERS => '0' );
			 else
				hc <= hc + 1;
			 end if;	
        end if;
    end process;
	 
    -- Vertical counter
    process( clk7 )
    begin
        if falling_edge( clk7 ) then
            if ( hc = 447 ) then
                if ( vc = 311 ) then
                     vc <= ( OTHERS => '0' );
                 else
                     vc <= vc + 1;
                 end if;
            end if;
        end if;
    end process;
    
	-- Horizonal Blanking. Duration of 96 clock cycles (13.2us)
    process( clk7 )
    begin        
        if falling_edge( clk7 ) then
            if ( hc = 320 ) then
                HBlank_n <= '0';
            elsif ( hc = 415 ) then
                HBlank_n <= '1';
            end if;
        end if;
    end process;

	-- Horizontal Sync. Occurs within the HBlank and signals the beginning of a new line
	-- It has duration of 32 cycles (4.4us)
    process( clk7 )
    begin
        if falling_edge( clk7 ) then
            if ( hc = 344 ) then
                 HSync_n <= '0';
             elsif ( hc = 375 ) then
                 HSync_n <= '1';
             end if;
        end if;
    end process;
	  
   -- Vertical Blank
    process( clk7 )
    begin
        if falling_edge( clk7 ) then
            if ( vc = 248 ) then
                VBlank_n <= '0';
            elsif ( vc = 255 ) then
                VBlank_n <= '1';
            end if;
        end if;
    end process;
    
    -- Vertical Sync
	 process( clk7 )
    begin
        if falling_edge( clk7 ) then
            if ( vc = 248 ) then
                VSync_n <= '0';
            elsif ( vc = 251 ) then
                VSync_n <= '1';
            end if;
        end if;
    end process;
        
    -- CPU Interrupt occurs every 50Hz
    process( clk7 )
    begin
        if falling_edge( clk7 ) then
            if ( vc = 248 and hc = 4 ) then -- hc is normally 2 - Changed for MACHX02 to hc = 4
                INT_n <= '0';
            elsif ( vc = 248 and hc = 68 ) then  -- hc is normally 66 - Changed for MACHX02 to hc = 68
                INT_n <= '1';
            end if;
        end if;
    end process;
	 	 
	 -- Border Signal. Zero when we're not displaying paper/ink pixels
    process( clk7 )
    begin
        if falling_edge( clk7 ) then
            if ( ( vc( 7 ) = '1' and vc( 6 ) = '1' ) or 						-- If in bottom
				 vc( 8 ) = '1' or															--	or top Border        
				 hc ( 8 ) = '1' ) then													-- If past the rhs of the main display area
                Border_n <= '0';
            else
                Border_n <= '1';
            end if;
         end if;
    end process;
	 
	 -- Video output generation signal(delaying Border 8 clocks)
	 process( clk7 )
    begin
        if falling_edge( clk7 ) then   
			if hc(3) = '1' then
					vout <= not Border_n;
         end if;  
        end if;
    end process;

	 -- DataLatch Generation
	 process( clk7 )
    begin
        if falling_edge( clk7 ) then
            if hc(0) = '1' and hc(1) = '0' and Border_n = '1' and hc(3) = '1' then
                AL1 <= '0';
            else
                AL1 <= '1';
            end if;
        end if;
    end process;
	 
	 -- AttributeLatch Generation
	 process( clk7 )
    begin
        if falling_edge( clk7 ) then
            if hc(0) = '1' and hc(1) = '1' and Border_n = '1' and hc(3) = '1' then
                AL2 <= '0';
            else
                AL2 <= '1';
            end if;
        end if;
    end process;
	  
	 -- Shift Register Load. This signal indicates when the next byte is ready to be sent
	process( clk7 )
    begin
        if falling_edge( clk7 ) then
            if hc( 2 downto 0 ) = "100" and Vout = '0' then
                SLoad <= '1';
            else
                SLoad <= '0';
            end if;
        end if;
    end process;
	 
	 -- AOLatch Generation
	 process( clk7 )
    begin
        if falling_edge( clk7 ) then   
			if hc( 2 downto 0) = "101" then
					AOLatch_n <= '0';
			else
					AOLatch_n <= '1';
         end if;  
        end if;
    end process;
	   	 
	 -- First buffer for bitmap
    process( AL1 )
    begin
        if falling_edge( AL1 ) then
            BitmapReg <= ULA_D;
        end if;
    end process;
	 
	 -- Shift register (second bitmap register)
    process( clk7 )
    begin
        if falling_edge( clk7 ) then
            if ( SLoad = '1' ) then
                SRegister <= BitmapReg;
				else
                SRegister <= SRegister( 6 downto 0 ) & '0';
            end if;
        end if;
    end process;
	 
	 -- First buffer for attribute
	 process( AL2 )
    begin
        if falling_edge( AL2 ) then
            AttrReg <= ULA_D;
        end if;
    end process;
	
	 -- Second buffer for attribute
    process( Vout, AOLatch_n, BorderColor )
    begin
		if falling_edge( AOLatch_n ) then
        if Vout = '0' then
				AttrOut <= AttrReg;
        else
            AttrOut <= "00" & BorderColor & BorderColor;
        end if;
       end if;
    end process;
	 
    -- Counter Flash
    process( VSync_n )
    begin
        if falling_edge( VSync_n ) then
            FlashCnt <= FlashCnt + 1;
        end if;
    end process;
    
  	 -- Paper (Pixel = 0) or Ink (Pixel = 1)
	 -- Only bit 7 is placed on the screen. Next wait for the shift to happen
	 Pixel <= SRegister( 7 ) xor ( AttrOut( 7 ) and FlashCnt( 4 ) );
	 
	 -- RGB generation
    process( HBlank_n, VBlank_n, Pixel, AttrOut )
    begin
        if ( HBlank_n = '1' and VBlank_n = '1' ) then
            if ( Pixel = '1' ) then -- if ink
                rI <= AttrOut( 6 );
                rG <= AttrOut( 2 );
                rR <= AttrOut( 1 );
                rB <= AttrOut( 0 );
            else -- if paper
                rI <= AttrOut( 6 );
                rG <= AttrOut( 5 );
                rR <= AttrOut( 4 );
                rB <= AttrOut( 3 );
            end if;
        else -- During blanking period set to black
            rI <= '0';
            rG <= '0';
            rR <= '0';
            rB <= '0';
        end if;
    end process;
    
	 -- When the ULA is not accessing the SRAM, the CPU can access it
    cpubus_en <=   '0' when Border_n = '1' and hc( 3 downto 0 ) = "0000" else
                   '1' when Border_n = '1' and hc( 3 downto 0 ) = "1000";
						 
    ------------------------------------------------------------------
    -- 																				  --
    -- 			    Generation of CPU clock contention 			     --
    -- 																				  --
    ------------------------------------------------------------------
	
	 -- For clarity in the code, we assign the ULA access pin to a variable
    ioreq_n <= CS or A0;
    
    -- Generates signals IORQ and late MREQ, required to verify the CPU contention
    process( CPUClk )
    begin        
        if rising_edge( CPUClk ) then
            ioreqtw3 <= ioreq_n;
            mreqt23  <= MREQ;
        end if;
    end process;
	 
	 cdet1 <= ( not (a14 or not ioreq_n)) or ( not ( not a15 or not ioreq_n)) or ( not ( hc(2) or hc(3))) or ( not Border_n or not ioreqtw3 or not CPUClk or not mreqt23);
	 cdet2 <= ( not (hc(2) or hc(3) )) or not Border_n or not CPUClk or ioreq_n or not ioreqtw3;
	 CLKContention <= not cdet1 or not cdet2;
	 
	 process( clk14 ) -- CPU running at 7Mhz for MACHX02 T80. Also need to change interrupt timings for the MACHX02 T80. See above -- CPU Interrupt occurs every 50Hz
    begin        
        if falling_edge( clk14 ) then
			if ( CPUClk = '1' and CLKContention = '0' ) then
				CPUClk <= '0';
			else
				CPUClk <= '1';
			end if;
		  end if;
    end process;
	 
    ------------------------------------------------------------------
    --                                                              -
    --                    ULA Port FE                               --
    --                                                              --
    ------------------------------------------------------------------
	 
	 	 
	 process( clk7 )
    begin        
        if falling_edge( clk7 ) then
             -- If the CPU is writing to ULA port FE
            if ( ioreq_n = '0' and WR = '0' and cpubus_en = '0' ) then
                rSpk        <= ULA_D( 4 );              -- Write bit 4 to the sound outpu
                rMic        <= ULA_D( 3 );        		  -- Write bit 3 to the MIC output
                BorderColor <= ULA_D( 2 downto 0 );     -- Write bits 0, 1 and 2 to create the border color
				 -- If the CPU is reading from ULA port FE
            elsif ( ioreq_n = '0' and RD = '0' and cpubus_en = '0' ) then
					 ULA_D <= '1' & EAR & '1' & KB;
				else
					 ULA_D <= (OTHERS => 'Z');
            end if;          
        end if;    
    end process;

    ------------------------------------------------------------------
    --                                                              --
    --                      Video Memory Access                     --
    --                                                              --
    ------------------------------------------------------------------
	 	 
	 -- Generate The ROMCE signal when the CPU wants to access the ROM
    ROMCE <= '0' when MREQ = '0' and A14 = '0' and A15 = '0' and RD = '0' else '1';
	 
	 -- Latches to hold delayed hc and vc counters
	 process( clk7 )
    begin
        if rising_edge( clk7 ) then
            if ( Border_n = '1' and ( hc(3 downto 0) = "0111" or hc(3 downto 0) = "1011")) then -- cycles 7 and 11: load c and v from hc and vc
                c <= hc;
				    v <= vc;
            end if;
        end if;
    end process;
	 
	 -- Address and control line multiplexor ULA/CPU
	 process ( Border_n, vc, hc, v, c )
		begin
		   -- cycles 8 and 12: present display address to SRAM
			-- cycles 9 and 13 load display byte
			if Border_n = '1' and ( hc(3 downto 0) = "1000" or hc(3 downto 0) = "1001" or hc(3 downto 0) = "1100" or hc(3 downto 0) = "1101" ) then
				VRAM_A <= '0' & v(7) & v(6) & v(2) & v(1) & v(0) & v(5) & v(4) & v(3) & c(7) & c(6) & c(5) & c(4) & c(3);
				RAMCE <= '0';
				RAMOE <= not hc(0);
				RAMWE <= '1';
			-- cycles 10 and 14: present attribute address to SRAM
			-- cycles 11 and 15 load attr byte
			elsif	Border_n = '1' and ( hc(3 downto 0) = "1010" or hc(3 downto 0) = "1011" or hc(3 downto 0) = "1110" or hc(3 downto 0) = "1111" ) then
				VRAM_A <= "0110" & v(7) & v(6) & v(5) & v(4) & v(3) & c(7) & c(6) & c(5) & c(4) & c(3);
				RAMCE <= '0';
				RAMOE <= not hc(0);
				RAMWE <= '1';
			else
				-- when SRAM is not in use by the ULA, give it to the CPU
				VRAM_A <= ( OTHERS => 'Z' );
				RAMCE <= A15 or not A14 or mreq;
				RAMOE <= RD;
				RAMWE <= WR;
			end if;
	 end process;    

    ------------------------------------------------------------------
    --                                                              --
    --                    Connect signals to CPLD                   --
    --                                                              --
    ------------------------------------------------------------------
    
	
    -- Contended 3.5Mhz clock to Z80 CPU
	
    CPU <= CPUClk;
	 
	 -- Interrupt
	 INT <= INT_n;
	 
	 -- RGB Output Signals
	 
	 -- Bright Signal. We have to match the color bit to avoid bright black
	 
	 rR_HL <= rR and ( rI and ( rR or rG or rB ));
	 rG_HL <= rG and ( rI and ( rR or rG or rB ));
	 rB_HL <= rB and ( rI and ( rR or rG or rB ));
	 
	 -- 4 bit resistor ladder - Need to confirm how exactly this affects the ZX Spectrum Colours as bit 3 generates a blueish tint
	 RED	 <= rR & rR_HL & '0' & rR;
	 GREEN <= rG & rG_HL & '0' & rG;
	 BLUE	 <= rB & rB_HL & '0' & rB;
	
	 -- Sync signals
	 VVSync_n <= VSync_n;
    HHSync_n <= HSync_n;
		
	-- Tape in/ou
    MIC         <= rMic;
	 
	-- Sound out 
    SOUND       <= rSpk;
    	 	 	 
end architecture;
