"""Exercise the real build script without a licensed ISE installation."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]

# Only vendor commands are replaced. Argument parsing, input checks, project
# selection, output cleanup and success/failure decisions run from the script.
ISE_STUB = r'''
proc project {args} {
  if {[lindex $args 0] eq "open"} {error "stale project was reopened"}
  if {[lindex $args 0] eq "new"} {
    set f [open demo.xise w]
    puts $f "fresh project"
    close $f
  }
  if {[lindex $args 0] eq "set" && [lindex $args 1] eq "top"} {
    if {[lindex $args 2] ne "cache_board_top"} {error "wrong physical top"}
  }
  if {[lindex $args 0] eq "set" && [lindex $args 1] eq "Generics, Parameters"} {
    set f [open selected_mode.txt w]
    puts $f [lindex $args 2]
    close $f
  }
}
proc xfile {args} {}
proc process {args} {
  if {[lindex $args 0] eq "run"} {
    if {$::env(TEST_CREATE_BIT) eq "1"} {
      set f [open cache_board_top.bit w]
      puts $f "fresh test bitstream"
      close $f
    }
    return $::env(TEST_LAUNCH)
  }
  if {[lindex $args 0] eq "get" && [lindex $args 2] eq "status"} {
    return $::env(TEST_STATUS)
  }
  error "unexpected process call"
}
source [lindex $argv 0]
'''


class BuildIseTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "scripts").mkdir()
        (self.root / "rtl").mkdir()
        for source in (ROOT / "rtl").glob("*.vhd"):
            shutil.copy(source, self.root / "rtl" / source.name)
        shutil.copy(ROOT / "scripts/build_ise.tcl", self.root / "scripts")
        (self.root / "board.ucf").write_text('NET "clk" LOC = "P1";\n')
        self.cores = self.root / "cores"
        self.cores.mkdir()
        for name in ("cache_icon", "cache_ila", "cache_vio"):
            (self.cores / (name + ".ngc")).write_bytes(b"test fixture")
        self.stub = self.root / "ise_stub.tcl"
        self.stub.write_text(ISE_STUB)

    def run_build(self, launch="true", status="up_to_date", bit=True,
                  mode=None, cores=True):
        argv = ["xc3s500e-4-fg320", "board.ucf"]
        if cores:
            argv.append("cores")
        if mode is not None:
            argv.append(mode)
        env = dict(os.environ, TEST_LAUNCH=launch, TEST_STATUS=status,
                   TEST_CREATE_BIT="1" if bit else "0")
        # The sourced script sees its own argv, rather than the stub's path.
        script = self.stub.read_text().replace(
            "source [lindex $argv 0]",
            'set argv [lrange $argv 1 end]\nset argc [llength $argv]\n'
            'source scripts/build_ise.tcl')
        self.stub.write_text(script)
        return subprocess.run(
            ["tclsh", str(self.stub), "unused"] + argv,
            cwd=self.root, env=env, text=True, capture_output=True)

    def test_success_requires_wrapper_final_status_and_new_bitstream(self):
        result = self.run_build()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.root / "build/ise_demo/cache_board_top.bit").is_file())

    def test_accepts_numeric_true(self):
        result = self.run_build(launch="1", status="warnings")
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_second_run_does_not_reuse_old_project_inputs(self):
        first = self.run_build()
        self.assertEqual(first.returncode, 0, first.stderr)
        second = self.run_build(mode="extended")
        self.assertEqual(second.returncode, 0, second.stderr)
        mode = self.root / "build/ise_demo/selected_mode.txt"
        self.assertEqual(mode.read_text().strip(), "EXTENDED_DEMO=true")

    def test_rejects_failed_launch(self):
        for launch in ("false", "0"):
            with self.subTest(launch=launch):
                result = self.run_build(launch=launch)
                self.assertNotEqual(result.returncode, 0)

    def test_rejects_failed_or_incomplete_process(self):
        for status in ("errors", "aborted", "running", "never_run", "out_of_date"):
            with self.subTest(status=status):
                result = self.run_build(status=status)
                self.assertNotEqual(result.returncode, 0)

    def test_rejects_absent_bitstream_and_removes_stale_bitstream(self):
        build = self.root / "build/ise_demo"
        build.mkdir(parents=True)
        (build / "cache_board_top.bit").write_text("stale")
        result = self.run_build(bit=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((build / "cache_board_top.bit").exists())

    def test_rejects_missing_generated_core(self):
        (self.cores / "cache_ila.ngc").unlink()
        result = self.run_build()
        self.assertNotEqual(result.returncode, 0)

    def test_rejects_old_command_without_cores(self):
        result = self.run_build(cores=False)
        self.assertNotEqual(result.returncode, 0)

    def test_rejects_unknown_demo_mode(self):
        result = self.run_build(mode="typo")
        self.assertNotEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main()
