# Verification Testplan and Traceability Matrix

## 1. Purpose

This document defines the verification scope for the APB-Controlled AXI-Stream Router.

The verification objective is to confirm that:

* APB writes correctly configure router state.
* APB reads correctly report control, status, and count values.
* AXI-Stream packets are routed to the correct output.
* Valid-ready handshakes are respected.
* Backpressure is propagated correctly.
* Reset, disable behavior, and illegal APB accesses are handled safely.
* A reusable scoreboard automatically detects output data or destination mismatches.

## 2. DUT Summary

The DUT contains:

* One APB slave interface
* One AXI-Stream input interface
* Two AXI-Stream output interfaces
* A control register containing `enable` and `route_mode`
* A packet counter
* APB readback registers
* Illegal-address error signaling through `pslverr`

## 3. Register Map

| Address | Register        | Access     | Verification Intent                               |
| ------- | --------------- | ---------- | ------------------------------------------------- |
| `0x00`  | CTRL            | Read/Write | Configure and read back `enable` and `route_mode` |
| `0x04`  | STATUS          | Read-only  | Read enable status                                |
| `0x08`  | COUNT           | Read-only  | Read number of accepted packets                   |
| Other   | Illegal address | Read/Write | Assert `pslverr`; preserve state                  |

## 4. Routing Specification

| `route_mode` | Expected Routing                                  |
| ------------ | ------------------------------------------------- |
| `2'b00`      | Use `s_tdest`: `0 → m0`, `1 → m1`                 |
| `2'b01`      | Force every packet to `m0`                        |
| `2'b10`      | Force every packet to `m1`                        |
| `2'b11`      | Reserved; treated as default routing by `s_tdest` |

## 5. Handshake Rules

| Interface        | Transfer Condition       |
| ---------------- | ------------------------ |
| AXI-Stream input | `s_tvalid && s_tready`   |
| Output m0        | `m0_tvalid && m0_tready` |
| Output m1        | `m1_tvalid && m1_tready` |
| APB transfer     | `psel && penable`        |

## 6. Test Matrix

| ID    | Feature / Requirement          | Testbench                           | Check                                                          |
| ----- | ------------------------------ | ----------------------------------- | -------------------------------------------------------------- |
| TP-01 | Reset initializes state        | `router_smoke_tb.sv`                | Reset release allows normal operation                          |
| TP-02 | Default route to m0            | `router_smoke_tb.sv`                | `s_tdest=0` transfers to m0                                    |
| TP-03 | Default route to m1            | `router_smoke_tb.sv`                | `s_tdest=1` transfers to m1                                    |
| TP-04 | Packet counter increments      | `router_smoke_tb.sv`                | COUNT increments after accepted packets                        |
| TP-05 | Backpressure propagation       | `router_backpressure_tb.sv`         | `s_tready=0` when selected output is blocked                   |
| TP-06 | No count while blocked         | `router_backpressure_tb.sv`         | COUNT remains unchanged before input handshake                 |
| TP-07 | Force m0 mode                  | `router_mode_tb.sv`                 | Destination is ignored and packet goes to m0                   |
| TP-08 | Force m1 mode                  | `router_mode_tb.sv`                 | Destination is ignored and packet goes to m1                   |
| TP-09 | Reset during active traffic    | `router_reset_during_traffic_tb.sv` | State clears and router recovers                               |
| TP-10 | Disabled-router behavior       | `router_disabled_tb.sv`             | No input acceptance or output forwarding                       |
| TP-11 | Illegal APB access             | `router_illegal_apb_tb.sv`          | `pslverr=1`; state is not changed                              |
| TP-12 | APB register readback          | `router_apb_readback_tb.sv`         | CTRL, STATUS, COUNT values are correct                         |
| TP-13 | Automatic data checking        | `router_scoreboard_tb.sv`           | Scoreboard checks output packet data                           |
| TP-14 | Automatic destination checking | `router_scoreboard_tb.sv`           | Scoreboard checks selected output                              |
| TP-15 | Scoreboard under backpressure  | `router_scoreboard_tb.sv`           | Packet remains expected until real output handshake            |
| TP-16 | Multiple route scenarios       | `router_scoreboard_tb.sv`           | Default routing and force-route behavior checked automatically |

## 7. Directed Test Descriptions

### 7.1 Smoke Test — `router_smoke_tb.sv`

Purpose:

* Enable the router through APB.
* Send packets with `s_tdest=0` and `s_tdest=1`.
* Verify that packets appear at m0 and m1 respectively.
* Verify packet counter updates.

Expected result:

* Both packets are transferred to the correct output.
* COUNT increments once per accepted input packet.
* Test prints `PASS`.

### 7.2 Backpressure Test — `router_backpressure_tb.sv`

Purpose:

* Block the selected output by deasserting its `tready`.
* Present a valid input packet.
* Verify that the router deasserts `s_tready`.
* Re-enable output readiness and verify transfer completion.

Expected result:

* No input handshake occurs while selected output is blocked.
* Packet counter does not increment while blocked.
* Packet transfers after output readiness returns.
* Test prints `PASS`.

### 7.3 Route Mode Test — `router_mode_tb.sv`

Purpose:

* Program `route_mode=01` and send a packet with `s_tdest=1`.
* Program `route_mode=10` and send a packet with `s_tdest=0`.

Expected result:

* First packet goes to m0 despite destination bit being 1.
* Second packet goes to m1 despite destination bit being 0.
* Test prints `PASS`.

### 7.4 Reset During Traffic Test — `router_reset_during_traffic_tb.sv`

Purpose:

* Start traffic.
* Assert active-low reset during traffic.
* Release reset.
* Re-enable router and send a recovery packet.

Expected result:

* Router state is cleared during reset.
* Packet count is reset.
* Router resumes correct operation after reset release.
* Test prints `PASS`.

### 7.5 Disabled Router Test — `router_disabled_tb.sv`

Purpose:

* Keep the router disabled.
* Present valid input traffic.

Expected result:

* `s_tready` remains low.
* No output valid signal is asserted.
* Packet counter remains unchanged.
* Test prints `PASS`.

### 7.6 Illegal APB Access Test — `router_illegal_apb_tb.sv`

Purpose:

* Perform APB access to an unsupported address.

Expected result:

* `pslverr` asserts during the illegal APB access.
* CTRL state and packet count do not change.
* Test prints `PASS`.

### 7.7 APB Readback Test — `router_apb_readback_tb.sv`

Purpose:

* Configure CTRL through APB.
* Read CTRL, STATUS, and COUNT registers through APB.

Expected result:

* `prdata` returns the expected CTRL, STATUS, and COUNT values.
* Read operations do not modify the registers.
* Test prints `PASS`.

### 7.8 Scoreboard Integration Test — `router_scoreboard_tb.sv`

Purpose:

* Instantiate the reusable `router_scoreboard.sv`.
* Send four packets through default and forced route modes.
* Include one backpressure scenario.
* Verify packet counter equals four.

Expected result:

* Scoreboard captures every accepted input packet.
* Scoreboard checks packet data and expected output at each output handshake.
* No queue underflow, data mismatch, wrong destination, or dual-output transfer occurs.
* Simulation log prints `[SB] PASS` for every packet.
* Test prints `PASS: scoreboard integration test completed successfully.`

## 8. Scoreboard Checking Strategy

The scoreboard maintains two expected queues:

| Queue               | Stored Value                   |
| ------------------- | ------------------------------ |
| `expected_data_q`   | Input packet data              |
| `expected_output_q` | Expected destination: m0 or m1 |

For each accepted input packet, expected routing is calculated as:

```text
route_mode = 01 → m0
route_mode = 10 → m1
otherwise      → s_tdest
```

For each output handshake, the scoreboard verifies:

1. There is an expected packet in the queue.
2. Exactly one output completes a transfer in the cycle.
3. Actual output matches expected output.
4. Actual output data matches expected data.

Any failure causes `$fatal`, so simulation stops immediately with an error message.

## 9. Verification Status

| Category                        | Status  |
| ------------------------------- | ------- |
| APB write control               | PASS    |
| APB readback                    | PASS    |
| Default routing                 | PASS    |
| Force routing                   | PASS    |
| AXI-Stream backpressure         | PASS    |
| Reset during traffic            | PASS    |
| Disabled router                 | PASS    |
| Illegal APB access              | PASS    |
| Packet counter                  | PASS    |
| Reusable scoreboard integration | PASS    |
| Functional coverage             | Planned |
| Assertions (SVA)                | Planned |
| Constrained-random regression   | Planned |

## 10. Planned Improvements

* Add SVA assertions for AXI-Stream stability, valid-ready behavior, packet counting, and APB error handling.
* Add functional coverage for route mode, destination, enable state, reset, and APB address combinations.
* Add constrained-random input traffic and random backpressure.
* Run multi-seed regressions.
* Create a verification closure report summarizing test, coverage, and assertion status.
