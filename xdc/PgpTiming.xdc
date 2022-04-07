##############################################################################
## This file is part of 'Camera link gateway'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'Camera link gateway', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

create_clock -period 6.400 -name pgp4RxClk  [get_pins {U_Core/U_PGP/U_PGP2b/Gtx7Core_1/gtxe2_i/RXOUTCLK}]
create_clock -period 6.400 -name pgp2bRxClk [get_pins {U_Core/U_PGP/U_PGP2b/MuliLane_Inst/GTX7_CORE_GEN[0].Gtx7Core_Inst/gtxe2_i/RXOUTCLK}]

set_clock_groups -asynchronous \
   -group [get_clocks -of_objects [get_pins U_Core/U_PGP/U_MMCM/MmcmGen.U_Mmcm/CLKOUT0]] \
   -group [get_clocks -of_objects [get_pins U_Core/U_PGP/U_MMCM/MmcmGen.U_Mmcm/CLKOUT1]] \
   -group [get_clocks -of_objects [get_pins U_Core/U_PGP/U_IBUFDS_GTE2/ODIV2]]

set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins U_Core/U_PGP/U_MMCM/MmcmGen.U_Mmcm/CLKOUT0]] -group [get_clocks -of_objects [get_pins U_Core/U_semClk100MHz/O]]
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins U_Core/U_PGP/U_MMCM/MmcmGen.U_Mmcm/CLKOUT1]] -group [get_clocks -of_objects [get_pins U_Core/U_semClk100MHz/O]]

set_clock_groups -asynchronous \
    -group [get_clocks -include_generated_clocks -of_objects [get_pins -hier -filter {name=~*gt0_Pgp3Gtx7Ip6G_i*gtxe2_i*TXOUTCLK}]] \
    -group [get_clocks -include_generated_clocks -of_objects [get_pins -hier -filter {name=~*gt0_Pgp3Gtx7Ip6G_i*gtxe2_i*RXOUTCLK}]]

set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins U_Core/U_PGP/U_MMCM/MmcmGen.U_Mmcm/CLKOUT1]] -group [get_clocks -of_objects [get_pins U_Core/U_PGP/U_PGPv4/REAL_PGP.U_TX_PLL/PllGen.U_Pll/CLKOUT1]]
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins U_Core/U_PGP/U_MMCM/MmcmGen.U_Mmcm/CLKOUT1]] -group [get_clocks pgp4RxClk]
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins U_Core/U_PGP/U_PGPv4/INT_REFCLK.U_pgpRefClk/ODIV2]] -group [get_clocks pgp4RxClk]
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins {U_Core/U_PGP/U_PGPv4/REAL_PGP.GEN_LANE[0].U_Pgp/U_Pgp3Gtx7IpWrapper/U_RX_PLL/PllGen.U_Pll/CLKOUT1}]] -group [get_clocks -of_objects [get_pins U_Core/U_PGP/U_MMCM/MmcmGen.U_Mmcm/CLKOUT1]]
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins U_Core/U_PGP/U_PGPv4/REAL_PGP.U_TX_PLL/PllGen.U_Pll/CLKOUT1]] -group [get_clocks -of_objects [get_pins U_Core/U_PGP/U_MMCM/MmcmGen.U_Mmcm/CLKOUT1]]
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins U_Core/U_PGP/U_PGPv4/INT_REFCLK.U_pgpRefClk/ODIV2]] -group [get_clocks -of_objects [get_pins U_Core/U_PGP/U_MMCM/MmcmGen.U_Mmcm/CLKOUT2]]
set_clock_groups -asynchronous -group [get_clocks pgp4RxClk] -group [get_clocks -of_objects [get_pins U_Core/U_PGP/U_MMCM/MmcmGen.U_Mmcm/CLKOUT2]]
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins U_Core/U_PGP/U_MMCM/MmcmGen.U_Mmcm/CLKOUT1]] -group [get_clocks -of_objects [get_pins U_Core/U_PGP/U_MMCM/MmcmGen.U_Mmcm/CLKOUT2]]

set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins U_Core/U_PGP/U_PLL/PllGen.U_Pll/CLKOUT0]] -group [get_clocks -of_objects [get_pins U_Core/U_PGP/U_PGPv4/INT_REFCLK.U_pgpRefClk/ODIV2]]
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins U_Core/U_PGP/U_PLL/PllGen.U_Pll/CLKOUT0]] -group [get_clocks -of_objects [get_pins U_Core/U_PGP/U_MMCM/MmcmGen.U_Mmcm/CLKOUT1]]
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins U_Core/U_PGP/U_PLL/PllGen.U_Pll/CLKOUT0]] -group [get_clocks -of_objects [get_pins U_Core/U_PGP/U_MMCM/MmcmGen.U_Mmcm/CLKOUT2]]
