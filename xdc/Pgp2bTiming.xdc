##############################################################################
## This file is part of 'Camera link gateway'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'Camera link gateway', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

set_clock_groups -asynchronous \
   -group [get_clocks -of_objects [get_pins U_Core/GEN_PGP2b.U_PGP/U_MMCM/MmcmGen.U_Mmcm/CLKOUT0]] \
   -group [get_clocks -of_objects [get_pins U_Core/GEN_PGP2b.U_PGP/U_MMCM/MmcmGen.U_Mmcm/CLKOUT1]] \
   -group [get_clocks -of_objects [get_pins U_Core/GEN_PGP2b.U_PGP/U_MMCM/MmcmGen.U_Mmcm/CLKOUT2]] \
   -group [get_clocks -of_objects [get_pins U_Core/GEN_PGP2b.U_PGP/U_IBUFDS_GTE2/ODIV2]]

create_clock -period 6.400 -name pgpRxClk0 [get_pins {U_Core/GEN_PGP2b.U_PGP/GEN_VEC[0].U_PGP/Gtx7Core_1/gtxe2_i/RXOUTCLK}]
create_clock -period 6.400 -name pgpRxClk1 [get_pins {U_Core/GEN_PGP2b.U_PGP/GEN_VEC[1].U_PGP/Gtx7Core_1/gtxe2_i/RXOUTCLK}]

set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins U_Core/GEN_PGP2b.U_PGP/U_MMCM/MmcmGen.U_Mmcm/CLKOUT1]] -group [get_clocks pgpRxClk0]
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins U_Core/GEN_PGP2b.U_PGP/U_MMCM/MmcmGen.U_Mmcm/CLKOUT1]] -group [get_clocks pgpRxClk1]

set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins U_Core/GEN_PGP2b.U_PGP/U_MMCM/MmcmGen.U_Mmcm/CLKOUT2]] -group [get_clocks pgpRxClk0]
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins U_Core/GEN_PGP2b.U_PGP/U_MMCM/MmcmGen.U_Mmcm/CLKOUT2]] -group [get_clocks pgpRxClk1]

set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins U_Core/GEN_PGP2b.U_PGP/U_IBUFDS_GTE2/ODIV2]] -group [get_clocks pgpRxClk0]
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins U_Core/GEN_PGP2b.U_PGP/U_IBUFDS_GTE2/ODIV2]] -group [get_clocks pgpRxClk1]
