# ISE Tcl shell (ISE 13 lab flow):
# xtclsh scripts/build_ise.tcl <part> <board.ucf> <cores-dir> [course|extended]
# Generate the matching ChipScope netlists first; see docs/chipscope.md.

proc fail {message} {
  puts stderr $message
  exit 1
}

if {$argc != 3 && $argc != 4} {
  fail "usage: xtclsh scripts/build_ise.tcl <device-speed-package> <board.ucf> <cores-dir> \[course|extended\]"
}

set part [lindex $argv 0]
set ucf_arg [lindex $argv 1]
set core_arg [lindex $argv 2]
set mode course
if {$argc == 4} {set mode [lindex $argv 3]}
if {$mode ne "course" && $mode ne "extended"} {
  fail "demo mode must be course or extended; got '$mode'"
}
if {![regexp {^(xc3s[0-9]+e)-([0-9]+)-([A-Za-z0-9]+)$} $part -> device speed package]} {
  fail "expected a Spartan-3E part such as xc3s500e-4-fg320; got '$part'"
}

set root [file normalize [file join [file dirname [info script]] ..]]
set ucf [file normalize [file join [pwd] $ucf_arg]]
set core_dir [file normalize [file join [pwd] $core_arg]]
if {![file isfile $ucf]} {
  fail "board UCF not found: $ucf"
}

set sources [list \
  rtl/cache_pkg.vhd \
  rtl/cache_ram.vhd \
  rtl/cache_controller.vhd \
  rtl/cache_system.vhd \
  rtl/demo_memory.vhd \
  rtl/demo_cpu.vhd \
  rtl/demo_monitor.vhd \
  rtl/demo_top.vhd \
  rtl/cache_board_top.vhd]
foreach source $sources {
  if {![file isfile [file join $root $source]]} {
    fail "required source missing: $source"
  }
}
set netlists [list]
foreach core {cache_icon cache_ila cache_vio} {
  set netlist [file join $core_dir "$core.ngc"]
  if {![file isfile $netlist] || [file size $netlist] == 0} {
    fail "generated ChipScope core missing or empty: $netlist (see docs/chipscope.md)"
  }
  lappend netlists $netlist
}

cd $root
file mkdir build/ise_demo
cd build/ise_demo
# Recreate generated project metadata so a different board UCF/core directory
# cannot leave old inputs attached. No source, UCF or core files are deleted.
foreach metadata {demo.xise demo.gise} {
  if {[file exists $metadata]} {file delete $metadata}
}
project new demo.xise
project set family Spartan3E
project set device $device
project set package $package
project set speed -$speed
project set "Preferred Language" VHDL
project set "Top-Level Module Type" HDL
foreach source $sources {
  xfile add [file join $root $source]
}
foreach netlist $netlists {xfile add $netlist}
xfile add $ucf
project set top cache_board_top
set extended false
if {$mode eq "extended"} {set extended true}
project set "Generics, Parameters" "EXTENDED_DEMO=$extended" -process "Synthesize - XST"

# ISE runs synthesis, map, place-and-route, and bitgen through this process.
# The generated reports must still be reviewed for BRAM use, timing, and fit.
set bitstream [file join [pwd] cache_board_top.bit]
# An old bitstream must never be mistaken for the result of this run.
if {[file exists $bitstream]} {file delete $bitstream}
set process_code [catch {
  process run "Generate Programming File" -force rerun_all
} process_result]
if {$process_code != 0} {
  fail "ISE Generate Programming File failed: $process_result"
}
if {![string is boolean -strict $process_result] || !$process_result} {
  fail "ISE could not launch Generate Programming File: $process_result"
}
set status [process get "Generate Programming File" status]
if {$status ne "up_to_date" && $status ne "warnings"} {
  fail "ISE Generate Programming File did not complete successfully: $status"
}
if {![file isfile $bitstream] || [file size $bitstream] == 0} {
  fail "ISE did not produce a new nonempty bitstream: $bitstream"
}
project close
puts "ISE status: $status; bitstream: $bitstream"
