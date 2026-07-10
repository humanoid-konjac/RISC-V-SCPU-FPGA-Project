#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_ROOT="${TMPDIR:-/tmp}/riscv-scpu-voice-tests"
mkdir -p "$TMP_ROOT" "$ROOT/code/simulation/sim_out"

cd "$ROOT"
make -C software

run_test() {
    local name="$1"
    shift
    iverilog -g2012 -I code -s "$name" -o "$TMP_ROOT/$name.out" "$@"
    vvp "$TMP_ROOT/$name.out"
}

run_test mic_pdm_rx_tb \
    code/simulation/mic_pdm_rx_tb.v IO/mic_pdm_rx.v
run_test mic_voice_trigger_tb \
    code/simulation/mic_voice_trigger_tb.v IO/mic_voice_trigger.v
run_test keyboard_game_trigger_tb \
    code/simulation/keyboard_game_trigger_tb.v \
    IO/keyboard_control.v IO/mic_voice_trigger.v
run_test audio_video_mmio_tb \
    code/simulation/audio_video_mmio_tb.v IO/mic_mmio.v IO/video_mmio.v
run_test vga_game_renderer_tb \
    code/simulation/vga_game_renderer_tb.v IO/vga_game_renderer.v
run_test voice_game_system_tb \
    code/simulation/voice_game_system_tb.v \
    code/SCPU.v code/RF.v code/ctrl.v code/EXT.v code/alu.v \
    IO/mic_mmio.v IO/video_mmio.v edf_file/MIO_BUS.V

(
    cd "$ROOT/code/simulation"
    iverilog -g2012 -I .. -s sccomp_tb -o "$TMP_ROOT/sccomp_tb.out" \
        sccomp_tb.v sccomp.v ../SCPU.v ../RF.v ../ctrl.v ../EXT.v \
        ../alu.v ../dm.v ../im.v
    vvp "$TMP_ROOT/sccomp_tb.out"

    iverilog -g2012 -I .. -s sccomp_interrupt_tb \
        -o "$TMP_ROOT/sccomp_interrupt_tb.out" \
        sccomp_interrupt_tb.v ../SCPU.v ../RF.v ../ctrl.v ../EXT.v \
        ../alu.v ../dm.v
    vvp "$TMP_ROOT/sccomp_interrupt_tb.out"

    iverilog -g2012 -s vga_timing_tb -o "$TMP_ROOT/vga_timing_tb.out" \
        vga_timing_tb.v ../../IO/vga_timing.v
    vvp "$TMP_ROOT/vga_timing_tb.out"

    iverilog -g2012 -s vga_keyboard_tb \
        -o "$TMP_ROOT/vga_keyboard_tb.out" \
        vga_keyboard_tb.v ../../IO/vga_timing.v \
        ../../IO/vga_test_pattern.v ../../IO/ps2_keyboard.v \
        ../../IO/keyboard_control.v
    vvp "$TMP_ROOT/vga_keyboard_tb.out"

    iverilog -g2012 -s ps2_keyboard_tb \
        -o "$TMP_ROOT/ps2_keyboard_tb.out" \
        ps2_keyboard_tb.v ../../IO/ps2_keyboard.v \
        ../../IO/keyboard_display.v
    vvp "$TMP_ROOT/ps2_keyboard_tb.out"
)

iverilog -g2012 -I code -s top -o "$TMP_ROOT/top_elab.out" \
    top.v code/SCPU.v code/RF.v code/ctrl.v code/EXT.v code/alu.v \
    code/dm_controller.v IO/Counter_3_IO.v IO/Enter.v IO/clk_div.v \
    IO/ps2_keyboard.v IO/keyboard_display.v IO/keyboard_control.v \
    IO/vga_timing.v IO/vga_test_pattern.v IO/mic_pdm_rx.v \
    IO/mic_voice_trigger.v IO/mic_mmio.v IO/video_mmio.v \
    IO/vga_game_renderer.v edf_file/MIO_BUS.V \
    code/simulation/top_ip_stubs.v

echo "PASS: all RTL, firmware, integration, regression, and top elaboration tests"
