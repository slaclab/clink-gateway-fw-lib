#!/usr/bin/env python3
#-----------------------------------------------------------------------------
# This file is part of the 'Camera link gateway'. It is subject to 
# the license terms in the LICENSE.txt file found in the top-level directory 
# of this distribution and at: 
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
# No part of the 'Camera link gateway', including this file, may be 
# copied, modified, propagated, or distributed except according to the terms 
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import ClinkDev
import sys
import argparse
import time

#################################################################

# Set the argument parser
parser = argparse.ArgumentParser()

# Convert str to bool
argBool = lambda s: s.lower() in ['true', 't', 'yes', '1']

# Add arguments
parser.add_argument(
    "--dev", 
    type     = str,
    required = False,
    default  = '/dev/datadev_0',
    help     = "path to device",
)  

parser.add_argument(
    "--version3", 
    type     = argBool,
    required = False,
    default  = False,
    help     = "true = PGPv3, false = PGP2b",
) 

parser.add_argument(
    "--mcs", 
    type     = str,
    required = True,
    help     = "path to mcs file",
)

parser.add_argument(
    "--lane", 
    type     = int,
    required = True,
    help     = "PGP lane index (range from 0 to 3)",
)  

# Get the arguments
args = parser.parse_args()

#################################################################

cl = ClinkDev.ClinkDev(
    dev      = args.dev,
    version3 = args.version3,
    pollEn   = False,
    initRead = True,
)
    
# Create useful pointers
AxiVersion = cl.ClinkFeb[args.lane].AxiVersion
PROM       = cl.ClinkFeb[args.lane].CypressS25Fl

# Read all the variables
cl.ReadAll()

if (cl.Hardware.PgpMon[args.lane].RxRemLinkReady.get()):
    print ( '###################################################')
    print ( '#                 Old Firmware                    #')
    print ( '###################################################')
    AxiVersion.printStatus()
else:
    # PGP Link down
    raise ValueError(f'Pgp[lane={args.lane}] is down')

# Program the FPGA's PROM
PROM.LoadMcsFile(args.mcs)

if(PROM._progDone):
    print('\nReloading FPGA firmware from PROM ....')
    AxiVersion.FpgaReload()
    time.sleep(5)
    print('\nReloading FPGA done')

    print ( '###################################################')
    print ( '#                 New Firmware                    #')
    print ( '###################################################')
    AxiVersion.printStatus()
else:
    print('Failed to program FPGA')

cl.stop()
exit()
