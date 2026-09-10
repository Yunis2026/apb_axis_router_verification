#!/usr/bin/env bash

set -u

mkdir -p build

passed=0
failed=0

run_test() {
    local test_name="$1"
    local tb_file="$2"
    shift 2

    echo ""
    echo "========================================"
    echo "Running: ${test_name}"
    echo "========================================"

    if iverilog -g2012 -Wall \
        -s "${test_name}" \
        -o "build/${test_name}.out" \
        rtl/apb_axis_router.sv \
        "$@" \
        "${tb_file}" \
        > "build/${test_name}.compile.log" 2>&1
    then
        if vvp "build/${test_name}.out" \
            > "build/${test_name}.run.log" 2>&1
        then
            if grep -q "PASS:" "build/${test_name}.run.log"; then
                echo "PASS: ${test_name}"
                passed=$((passed + 1))
            else
                echo "FAIL: ${test_name} completed but did not print PASS."
                failed=$((failed + 1))
            fi
        else
            echo "FAIL: ${test_name} simulation failed."
            failed=$((failed + 1))
        fi
    else
        echo "FAIL: ${test_name} compilation failed."
        failed=$((failed + 1))
    fi
}

run_test "router_smoke_tb" \
    "tb/router_smoke_tb.sv"

run_test "router_backpressure_tb" \
    "tb/router_backpressure_tb.sv"

run_test "router_mode_tb" \
    "tb/router_mode_tb.sv"

run_test "router_reset_during_traffic_tb" \
    "tb/router_reset_during_traffic_tb.sv"

run_test "router_disabled_tb" \
    "tb/router_disabled_tb.sv"

run_test "router_illegal_apb_tb" \
    "tb/router_illegal_apb_tb.sv"

run_test "router_apb_readback_tb" \
    "tb/router_apb_readback_tb.sv"

run_test "router_scoreboard_tb" \
    "tb/router_scoreboard_tb.sv" \
    "tb/router_scoreboard.sv"

run_test "router_sva_tb" \
    "tb/router_sva_tb.sv" \
    "tb/router_assertion_checker.sv"

run_test "router_coverage_tb" \
    "tb/router_coverage_tb.sv" \
    "tb/router_coverage_collector.sv"

echo ""
echo "========================================"
echo "          REGRESSION SUMMARY"
echo "========================================"
echo "Passed: ${passed}"
echo "Failed: ${failed}"
echo "Total : $((passed + failed))"
echo "========================================"

if [ "${failed}" -eq 0 ]; then
    echo "REGRESSION PASS"
    exit 0
else
    echo "REGRESSION FAIL"
    exit 1
fi