-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-------------------------------------------------------------------------------
-- This file is part of 'Camera link gateway'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'Camera link gateway', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.std_logic_arith.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.AxiLitePkg.all;
use surf.SsiPkg.all;
use surf.Pgp4Pkg.all;
use surf.ClinkPkg.all;

entity CLinkWrapper is
   generic (
      TPD_G            : time := 1 ns;
      AXIL_BASE_ADDR_G : slv(31 downto 0));
   port (
      -- Clink Ports
      cbl0Half0P      : inout slv(4 downto 0);  --  2,  4,  5,  6, 3
      cbl0Half0M      : inout slv(4 downto 0);  -- 15, 17, 18, 19 16
      cbl0Half1P      : inout slv(4 downto 0);  --  8, 10, 11, 12,  9
      cbl0Half1M      : inout slv(4 downto 0);  -- 21, 23, 24, 25, 22
      cbl0SerP        : out   sl;               -- 20
      cbl0SerM        : out   sl;               -- 7
      cbl1Half0P      : inout slv(4 downto 0);  --  2,  4,  5,  6, 3
      cbl1Half0M      : inout slv(4 downto 0);  -- 15, 17, 18, 19 16
      cbl1Half1P      : inout slv(4 downto 0);  --  8, 10, 11, 12,  9
      cbl1Half1M      : inout slv(4 downto 0);  -- 21, 23, 24, 25, 22
      cbl1SerP        : out   sl;               -- 20
      cbl1SerM        : out   sl;               -- 7
      -- CLINK Status
      clinkUp         : out   sl;
      -- Stable Reference IDELAY Clock and Reset
      refClk200MHz    : in    sl;
      refRst200MHz    : in    sl;
      -- Camera Control Bits
      camCtrl         : in    slv(3 downto 0);
      -- Camera Data Interface
      dataMaster      : out   AxiStreamMasterType;
      dataSlave       : in    AxiStreamSlaveType;
      -- UART Interface
      rxUartMaster    : in    AxiStreamMasterType;
      rxUartSlave     : out   AxiStreamSlaveType;
      txUartMaster    : out   AxiStreamMasterType;
      txUartSlave     : in    AxiStreamSlaveType;
      -- Axi-Lite Interface
      axilClk         : in    sl;
      axilRst         : in    sl;
      axilReadMaster  : in    AxiLiteReadMasterType;
      axilReadSlave   : out   AxiLiteReadSlaveType;
      axilWriteMaster : in    AxiLiteWriteMasterType;
      axilWriteSlave  : out   AxiLiteWriteSlaveType);
end CLinkWrapper;

architecture mapping of CLinkWrapper is

   signal camStatus : ClChanStatusArray(1 downto 0);

begin

   U_ClinkTop : entity surf.ClinkTop
      generic map (
         TPD_G              => TPD_G,
         CHAN_COUNT_G       => 1,
         UART_READY_EN_G    => true,
         COMMON_AXIL_CLK_G  => true,
         COMMON_DATA_CLK_G  => true,
         DATA_AXIS_CONFIG_G => PGP4_AXIS_CONFIG_C,
         UART_AXIS_CONFIG_G => PGP4_AXIS_CONFIG_C,
         AXIL_BASE_ADDR_G   => AXIL_BASE_ADDR_G)
      port map (
         -- Clink Ports
         cbl0Half0P      => cbl0Half0P,
         cbl0Half0M      => cbl0Half0M,
         cbl0Half1P      => cbl0Half1P,
         cbl0Half1M      => cbl0Half1M,
         cbl0SerP        => cbl0SerP,
         cbl0SerM        => cbl0SerM,
         cbl1Half0P      => cbl1Half0P,
         cbl1Half0M      => cbl1Half0M,
         cbl1Half1P      => cbl1Half1P,
         cbl1Half1M      => cbl1Half1M,
         cbl1SerP        => cbl1SerP,
         cbl1SerM        => cbl1SerM,
         -- Delay clock and reset, 200Mhz
         dlyClk          => refClk200MHz,
         dlyRst          => refRst200MHz,
         -- System clock and reset, > 100 Mhz
         sysClk          => axilClk,
         sysRst          => axilRst,
         -- Camera Control Bits & status, async
         camCtrl(0)      => camCtrl,
         camStatus       => camStatus,
         -- Camera data
         dataClk         => axilClk,
         dataRst         => axilRst,
         dataMasters(0)  => dataMaster,
         dataSlaves(0)   => dataSlave,
         -- UART data
         uartClk         => axilClk,
         uartRst         => axilRst,
         sUartMasters(0) => rxUartMaster,
         sUartSlaves(0)  => rxUartSlave,
         mUartMasters(0) => txUartMaster,
         mUartSlaves(0)  => txUartSlave,
         -- Axi-Lite Interface
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave);

   clinkUp <= camStatus(0).running;

end mapping;
