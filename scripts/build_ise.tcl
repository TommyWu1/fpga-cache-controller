# Run from the repository root with ISE 14.7:
#   xtclsh scripts/build_ise.tcl xc3s500e-4-fg320 path/to/board.ucf
# Replace the example device with the exact board FPGA and provide its real UCF.

proc fail {message} {
  puts stderr $message
  exit 1
}

if {$argc != 2} {
  fail "usage: xtclsh scripts/build_ise.tcl <device-speed-package> <board.ucf>"
}

set part [lindex $argv 0]
set ucf_arg [lindex $argv 1]
if {![regexp {^(xc3s[0-9]+e)-([0-9]+)-([A-Za-z0-9]+)$} $part -> device speed package]} {
  fail "expected a Spartan-3E part such as xc3s500e-4-fg320; got '$part'"
}

set root [file normalize [file join [file dirname [info script]] ..]]
set ucf [file normalize [file join [pwd] $ucf_arg]]
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
  rtl/demo_top.vhd]
foreach source $sources {
  if {![file isfile [file join $root $source]]} {
    fail "required source missing: $source"
  }
}

cd $root
file mkdir build/ise_demo
cd build/ise_demo
project new demo
project set family Spartan3E
project set device $device
project set package $package
project set speed -$speed
project set "Preferred Language" VHDL
project set "Top-Level Module Type" HDL
project set top demo_top
foreach source $sources {
  xfile add [file join $root $source]
}
xfile add $ucf

# ISE runs synthesis, map, place-and-route, and bitgen through this process.
# The generated reports must still be reviewed for BRAM use, timing, and fit.
set process_code [catch {
  process run "Generate Programming File" -force rerun
} process_result]
if {$process_code != 0} {
  fail "ISE Generate Programming File failed: $process_result"
}
if {[string is integer -strict $process_result] && $process_result != 0} {
  fail "ISE Generate Programming File returned status $process_result"
}
if {[regexp -nocase {(^|[^[:alnum:]_])(error|failed)([^[:alnum:]_]|$)} $process_result]} {
  fail "ISE Generate Programming File reported failure: $process_result"
}
puts "ISE Generate Programming File result: $process_result"
