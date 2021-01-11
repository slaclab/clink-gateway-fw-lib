-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Wrapper for PGPv3 communication
-------------------------------------------------------------------------------
-- This file is part of 'ATLAS ALTIROC DEV'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'ATLAS ALTIROC DEV', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;


library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.Pgp3Pkg.all;

library unisim;
use unisim.vcomponents.all;

library clink_gateway_fw_lib;

entity Pgp3Phy is
   generic (
      TPD_G           : time    := 1 ns;
      SIMULATION_G    : boolean := false;
      AXI_CLK_FREQ_G  : real    := 125.0E+6;  -- units of Hz
      PHY_BASE_ADDR_G : slv(31 downto 0));
   port (
      -- AXI-Lite Interface (axilClk domain)
      axilClk          : out sl;
      axilRst          : out sl;
      axilReadMasters  : out AxiLiteReadMasterArray(1 downto 0);
      axilReadSlaves   : in  AxiLiteReadSlaveArray(1 downto 0);
      axilWriteMasters : out AxiLiteWriteMasterArray(1 downto 0);
      axilWriteSlaves  : in  AxiLiteWriteSlaveArray(1 downto 0);
      -- PHY AXI-Lite Interface (axilClk domain)
      phyReadMaster    : in  AxiLiteReadMasterType;
      phyReadSlave     : out AxiLiteReadSlaveType;
      phyWriteMaster   : in  AxiLiteWriteMasterType;
      phyWriteSlave    : out AxiLiteWriteSlaveType;
      -- Camera Data Interface (axilClk domain)
      dataMasters      : in  AxiStreamMasterArray(1 downto 0);
      dataSlaves       : out AxiStreamSlaveArray(1 downto 0);
      -- UART Interface (axilClk domain)
      txUartMasters    : in  AxiStreamMasterArray(1 downto 0);
      txUartSlaves     : out AxiStreamSlaveArray(1 downto 0);
      rxUartMasters    : out AxiStreamMasterArray(1 downto 0);
      rxUartSlaves     : in  AxiStreamSlaveArray(1 downto 0);
      -- Trigger (axilClk domain)
      pgpTrigger       : out slv(1 downto 0);
      -- Stable Reference IDELAY Clock and Reset
      refClk200MHz     : out sl;
      refRst200MHz     : out sl;
      -- PGP Ports
      pgpClkP          : in  sl;
      pgpClkN          : in  sl;
      pgpRxP           : in  slv(1 downto 0);
      pgpRxN           : in  slv(1 downto 0);
      pgpTxP           : out slv(1 downto 0);
      pgpTxN           : out slv(1 downto 0));
end Pgp3Phy;

architecture mapping of Pgp3Phy is

   constant NUM_AXIL_MASTERS_C : natural := 5;

   constant XBAR_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXIL_MASTERS_C-1 downto 0) := genAxiLiteConfig(NUM_AXIL_MASTERS_C, PHY_BASE_ADDR_G, 20, 14);

   signal phyReadMasters  : AxiLiteReadMasterArray(NUM_AXIL_MASTERS_C-1 downto 0);
   signal phyReadSlaves   : AxiLiteReadSlaveArray(NUM_AXIL_MASTERS_C-1 downto 0)  := (others => AXI_LITE_READ_SLAVE_EMPTY_SLVERR_C);
   signal phyWriteMasters : AxiLiteWriteMasterArray(NUM_AXIL_MASTERS_C-1 downto 0);
   signal phyWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXIL_MASTERS_C-1 downto 0)  := (others => AXI_LITE_WRITE_SLAVE_EMPTY_SLVERR_C);

   signal pgpRxIn  : Pgp3RxInArray(1 downto 0)  := (others => PGP3_RX_IN_INIT_C);
   signal pgpRxOut : Pgp3RxOutArray(1 downto 0) := (others => PGP3_RX_OUT_INIT_C);

   signal pgpTxIn  : Pgp3TxInArray(1 downto 0)  := (others => PGP3_TX_IN_INIT_C);
   signal pgpTxOut : Pgp3TxOutArray(1 downto 0) := (others => PGP3_TX_OUT_INIT_C);

   signal pgpTxMasters : AxiStreamMasterArray(7 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal pgpTxSlaves  : AxiStreamSlaveArray(7 downto 0)  := (others => AXI_STREAM_SLAVE_FORCE_C);
   signal pgpRxMasters : AxiStreamMasterArray(7 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal pgpRxSlaves  : AxiStreamSlaveArray(7 downto 0)  := (others => AXI_STREAM_SLAVE_FORCE_C);
   signal pgpRxCtrl    : AxiStreamCtrlArray(7 downto 0)   := (others => AXI_STREAM_CTRL_UNUSED_C);

   signal pgpClk : slv(1 downto 0);
   signal pgpRst : slv(1 downto 0);

   signal pgpRefClkDiv2    : sl;
   signal pgpRefClkDiv2Rst : sl;

   signal sysClk : sl;
   signal sysRst : sl;

begin

   axilClk <= sysClk;
   axilRst <= sysRst;

   U_PwrUpRst : entity surf.PwrUpRst
      generic map(
         TPD_G         => TPD_G,
         SIM_SPEEDUP_G => SIMULATION_G)
      port map (
         clk    => pgpRefClkDiv2,
         rstOut => pgpRefClkDiv2Rst);

   U_MMCM : entity surf.ClockManager7
      generic map(
         TPD_G              => TPD_G,
         SIMULATION_G       => SIMULATION_G,
         TYPE_G             => "MMCM",
         INPUT_BUFG_G       => false,
         FB_BUFG_G          => false,
         RST_IN_POLARITY_G  => '1',
         NUM_CLOCKS_G       => 2,
         -- MMCM attributes
         BANDWIDTH_G        => "OPTIMIZED",
         CLKIN_PERIOD_G     => 6.4,     -- 156.25 MHz
         CLKFBOUT_MULT_F_G  => 8.00,    -- VCO = 1250MHz
         CLKOUT0_DIVIDE_F_G => 6.25,    -- 200 MHz = 1250MHz/6.25
         CLKOUT1_DIVIDE_G   => 10)      -- 125 MHz = 1250MHz/10
      port map(
         clkIn     => pgpRefClkDiv2,
         rstIn     => pgpRefClkDiv2Rst,
         clkOut(0) => refClk200MHz,
         clkOut(1) => sysClk,
         rstOut(0) => refRst200MHz,
         rstOut(1) => sysRst);

   U_XBAR : entity surf.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => NUM_AXIL_MASTERS_C,
         MASTERS_CONFIG_G   => XBAR_CONFIG_C)
      port map (
         axiClk              => sysClk,
         axiClkRst           => sysRst,
         sAxiWriteMasters(0) => phyWriteMaster,
         sAxiWriteSlaves(0)  => phyWriteSlave,
         sAxiReadMasters(0)  => phyReadMaster,
         sAxiReadSlaves(0)   => phyReadSlave,
         mAxiWriteMasters    => phyWriteMasters,
         mAxiWriteSlaves     => phyWriteSlaves,
         mAxiReadMasters     => phyReadMasters,
         mAxiReadSlaves      => phyReadSlaves);

   U_PGPv3 : entity surf.Pgp3Gtx7Wrapper
      generic map(
         TPD_G                => TPD_G,
         ROGUE_SIM_EN_G       => SIMULATION_G,
         ROGUE_SIM_PORT_NUM_G => 8000,
         NUM_LANES_G          => 2,
         NUM_VC_G             => 4,
         RATE_G               => "10.3125Gbps",
         REFCLK_TYPE_G        => PGP3_REFCLK_312_C,
         EN_PGP_MON_G         => true,
         EN_GT_DRP_G          => false,
         EN_QPLL_DRP_G        => false,
         AXIL_BASE_ADDR_G     => XBAR_CONFIG_C(0).baseAddr,
         AXIL_CLK_FREQ_G      => AXI_CLK_FREQ_G)
      port map (
         -- Stable Clock and Reset
         stableClk         => sysClk,
         stableRst         => sysRst,
         -- Gt Serial IO
         pgpGtTxP          => pgpTxP,
         pgpGtTxN          => pgpTxN,
         pgpGtRxP          => pgpRxP,
         pgpGtRxN          => pgpRxN,
         -- GT Clocking
         pgpRefClkP        => pgpClkP,
         pgpRefClkN        => pgpClkN,
         pgpRefClkDiv2Bufg => pgpRefClkDiv2,
         -- Clocking
         pgpClk            => pgpClk,
         pgpClkRst         => pgpRst,
         -- Non VC Rx Signals
         pgpRxIn           => pgpRxIn,
         pgpRxOut          => pgpRxOut,
         -- Non VC Tx Signals
         pgpTxIn           => pgpTxIn,
         pgpTxOut          => pgpTxOut,
         -- Frame Transmit Interface
         pgpTxMasters      => pgpTxMasters,
         pgpTxSlaves       => pgpTxSlaves,
         -- Frame Receive Interface
         pgpRxMasters      => pgpRxMasters,
         pgpRxCtrl         => pgpRxCtrl,
         pgpRxSlaves       => pgpRxSlaves,
         -- AXI-Lite Register Interface (axilClk domain)
         axilClk           => sysClk,
         axilRst           => sysRst,
         axilReadMaster    => phyReadMasters(0),
         axilReadSlave     => phyReadSlaves(0),
         axilWriteMaster   => phyWriteMasters(0),
         axilWriteSlave    => phyWriteSlaves(0));

   GEN_VEC :
   for i in 1 downto 0 generate

      U_SyncTrig : entity surf.SynchronizerOneShot
         generic map (
            TPD_G => TPD_G)
         port map (
            clk     => sysClk,
            dataIn  => pgpRxOut(i).opCodeEn,
            dataOut => pgpTrigger(i));

      U_PgpVcWrapper : entity clink_gateway_fw_lib.PgpVcWrapper
         generic map (
            TPD_G            => TPD_G,
            SIMULATION_G     => SIMULATION_G,
            GEN_SYNC_FIFO_G  => false,
            PHY_AXI_CONFIG_G => PGP3_AXIS_CONFIG_C)
         port map (
            -- Clocks and Resets
            sysClk          => sysClk,
            sysRst          => sysRst,
            pgpTxClk        => pgpClk(i),
            pgpTxRst        => pgpRst(i),
            pgpRxClk        => pgpClk(i),
            pgpRxRst        => pgpRst(i),
            -- AXI-Lite Interface (sysClk domain)
            axilReadMaster  => axilReadMasters(i),
            axilReadSlave   => axilReadSlaves(i),
            axilWriteMaster => axilWriteMasters(i),
            axilWriteSlave  => axilWriteSlaves(i),
            -- Camera Data Interface (sysClk domain)
            dataMaster      => dataMasters(i),
            dataSlave       => dataSlaves(i),
            -- UART Interface (sysClk domain)
            txUartMaster    => txUartMasters(i),
            txUartSlave     => txUartSlaves(i),
            rxUartMaster    => rxUartMasters(i),
            rxUartSlave     => rxUartSlaves(i),
            -- Frame TX Interface (pgpTxClk domain)
            pgpTxMasters    => pgpTxMasters(4*i+3 downto 4*i),
            pgpTxSlaves     => pgpTxSlaves(4*i+3 downto 4*i),
            -- Frame RX Interface (pgpRxClk domain)
            pgpRxMasters    => pgpRxMasters(4*i+3 downto 4*i),
            pgpRxCtrl       => pgpRxCtrl(4*i+3 downto 4*i),
            pgpRxSlaves     => pgpRxSlaves(4*i+3 downto 4*i));

   end generate GEN_VEC;

end mapping;
