# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Check for Vivado version 2018.2 (or later)
if { [VersionCheck 2018.2 ] < 0 } {
   exit -1
}

# Check for submodule tagging
if { [info exists ::env(OVERRIDE_SUBMODULE_LOCKS)] != 1 || $::env(OVERRIDE_SUBMODULE_LOCKS) == 0 } {
   if { [SubmoduleCheck {ruckus} {2.9.2}  ] < 0 } {exit -1}
   if { [SubmoduleCheck {surf}   {2.13.0} ] < 0 } {exit -1}
} else {
   puts "\n\n*********************************************************"
   puts "OVERRIDE_SUBMODULE_LOCKS != 0"
   puts "Ignoring the submodule locks in clink-gateway-fw-lib/ruckus.tcl"
   puts "*********************************************************\n\n"
}

# Load local source Code
loadSource -lib clink_gateway_fw_lib      -dir "$::DIR_PATH/rtl"

# Load local source Code
loadConstraints -path "$::DIR_PATH/xdc/ClinkGateway.xdc"

# Case the timing on communication protocol
if { [info exists ::env(INCLUDE_PGP4_6G)] != 1 || $::env(INCLUDE_PGP4_6G) == 0 } {
   loadConstraints -path "$::DIR_PATH/xdc/Pgp2bTiming.xdc"
} else {
   loadConstraints -path "$::DIR_PATH/xdc/Pgp4Timing.xdc"

}

# Add IP cores
loadIpCore -dir "$::DIR_PATH/ip"

# Updating the impl_1 strategy
set_property strategy Performance_ExplorePostRoutePhysOpt [get_runs impl_1]
