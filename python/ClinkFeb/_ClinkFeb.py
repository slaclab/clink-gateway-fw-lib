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

import pyrogue as pr

import surf.axi             as axiVer
import surf.xilinx          as xil
import surf.devices.cypress as prom
import surf.devices.linear  as linear
import surf.devices.nxp     as nxp
import surf.protocols.clink as cl
import surf.protocols.pgp   as pgp

class ClinkTrigCtrl(pr.Device):
    def __init__(   self,       
            name        = "ClinkTrigCtrl",
            description = "Trigger Controller Container",
            **kwargs):
        super().__init__(name=name, description=description, **kwargs) 

        ##############################
        # Variables
        ##############################
        self.add(pr.RemoteVariable(    
            name         = "EnableTrig",
            description  = "Enable triggering",
            offset       = 0x000,
            bitSize      = 1,
            base         = pr.Bool,
            mode         = "RW",
        ))   

        self.add(pr.RemoteVariable(    
            name         = "InvCC",
            description  = "Inverter the 4-bit camCtrl bus",
            offset       = 0x004,
            bitSize      = 1,
            base         = pr.Bool,
            mode         = "RW",
        ))    

        self.add(pr.RemoteVariable(    
            name         = "TrigMap",
            description  = "0x0: map trigger to channel A, 0x1: map trigger to channel B",
            offset       = 0x008,
            bitSize      = 1,
            mode         = "RW",
            enum         = {
                0x0: 'ChA', 
                0x1: 'ChB', 
            },            
        ))

        self.add(pr.RemoteVariable(    
            name         = "TrigPulseWidth",
            description  = "Sets the trigger pulse width on the 4-bit camCtrl bus",
            offset       = 0x00C,
            bitSize      = 16,
            mode         = "RW",
            units        = '1/125MHz',          
        ))     

        self.add(pr.RemoteVariable(    
            name         = "TrigMask",
            description  = "Sets the trigger mask on the 4-bit camCtrl bus",
            offset       = 0x010,
            bitSize      = 4,
            mode         = "RW",
        ))
        
        self.add(pr.RemoteVariable(    
            name         = "TrigRate",
            description  = "Trigger Rate",
            offset       = 0x0F4,
            units        = 'Hz',
            disp         = '{:d}',
            mode         = "RO",
            pollInterval = 1,
        ))
        
        self.add(pr.RemoteVariable(    
            name         = "TrigCnt",
            description  = "Trigger Counter",
            offset       = 0x0F8,
            disp         = '{:d}',
            mode         = "RO",
            pollInterval = 1,
        ))           

        self.add(pr.RemoteVariable(
            name         = "CntRst",                 
            description  = "Counter Reset",
            mode         = 'WO',
            offset       = 0x0FC,
            hidden       = True,
        ))          
        
    def hardReset(self):
        self.CntRst.set(0x1)

    def softReset(self):
        self.CntRst.set(0x1)

    def countReset(self):
        self.CntRst.set(0x1)            
        
class ClinkFeb(pr.Device):
    def __init__(   self,       
            name        = "ClinkFeb",
            description = "ClinkFeb Container",
            serialA     = None,
            serialB     = None,
            version3    = False, # true = PGPv3, false = PGP2b
            **kwargs):
        super().__init__(name=name, description=description, **kwargs) 

        # Add devices
        self.add(axiVer.AxiVersion( 
            name        = 'AxiVersion', 
            offset      = 0x00000000, 
            expand      = False,
        ))
        
        self.add(prom.CypressS25Fl(
            name        = 'CypressS25Fl', 
            offset      = 0x00001000, 
            hidden      = True, # Hidden in GUI because indented for scripting
        ))
        
        self.add(nxp.Sa56004x(      
            name        = 'BoardTemp', 
            description = 'This device monitors the board temperature and FPGA junction temperature', 
            offset      = 0x00002000, 
            expand      = False,
        ))
        
        self.add(linear.Ltc4151(
            name        = 'BoardPwr', 
            description = 'This device monitors the board power, input voltage and input current', 
            offset      = 0x00002400, 
            senseRes    = 20.E-3, # Units of Ohms
            expand      = False,
        ))
        
        self.add(xil.Xadc(
            name        = 'Xadc', 
            offset      = 0x00003000, 
            expand      = False,
        ))        
        
        self.add(cl.ClinkTop(
            offset      = 0x00010000,
            serialA     = serialA,
            serialB     = serialB,
            expand      = False,
        ))

        self.add(ClinkTrigCtrl(      
            name        = 'TrigCtrl[0]', 
            description = 'Channel A trigger control', 
            offset      = 0x00020000, 
            expand      = False,
        )) 

        self.add(ClinkTrigCtrl(      
            name        = 'TrigCtrl[1]', 
            description = 'Channel B trigger control', 
            offset      = 0x00020100, 
            expand      = False,
        ))     

        for i in range(2):
        
            if (version3):
                self.add(pgp.Pgp3AxiL(            
                    name    = (f'PgpMon[{i}]'), 
                    offset  = (0x00040000 + i*0x2000), 
                    numVc   = 4,
                    writeEn = False,
                    expand  = False,
                )) 
            else:
                self.add(pgp.Pgp2bAxi(            
                    name    = (f'PgpMon[{i}]'), 
                    offset  = (0x00040000 + i*0x2000), 
                    writeEn = False,
                    expand  = False,
                ))           
