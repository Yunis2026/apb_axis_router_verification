# APB-Controlled AXI-Stream Router Verification Testplan

## 1. Purpose

This document defines the verification scope and traceability for the APB-Controlled AXI-Stream Router.

The verification goal is to confirm that APB configuration, AXI-Stream routing, backpressure behavior, reset behavior, error handling, and register readback operate as specified.

## 2. DUT Summary

The DUT is an APB-controlled router with one AXI-Stream input and two AXI-Stream outputs.

* APB configures `enable` and `route_mode`
* AXI-Stream input packets are routed to output 0 or output 1
* Backpressure propagates from the selected output to the input
* A packet counter records successful valid-ready handshakes
* Illegal APB accesses raise `pslverr`
* APB reads return `CTRL`, `STATUS`, and `COUNT` through `prdata`

## 3. Verification Scope

### In Scope

* Reset behavior
* APB register write and readback
* APB illegal-address handling
* Router enable and disable behavior
* Default routing using `s_tdest`
* Force-route mode through `route_mode`
* AXI-Stream valid-ready handshake
* Backpressure propagation
* Packet counter behavior

### Out of Scope

* UVM register model
* Clock-domain crossing verification
* Gate-level timing verification
* Formal verification
* Performance and throughput optimization
* Packet buffering beyond the current simplified router implementation

## 4. Testbench Strategy

The current verification environment uses directed SystemVerilog testbenches.

Each testbench includes:

* Clock and reset generation
* APB transaction driving
* AXI-Stream transaction driving
* Immediate checks using `$fatal`
* VCD waveform generation for debug and evidence

## 5. Traceability Matrix

| ID  | Feature / Requirement                           | Testbench                                                                      | Main Check                                                   | Priority | Status |
| --- | ----------------------------------------------- | ------------------------------------------------------------------------------ | ------------------------------------------------------------ | -------- | ------ |
| F01 | Reset clears router state                       | `router_reset_during_traffic_tb.sv`                                            | `enable_q=0`, output valid signals deassert, counter clears  | P0       | PASS   |
| F02 | Router remains disabled after reset             | `router_disabled_tb.sv`                                                        | `s_tready=0`, no output valid, counter unchanged             | P0       | PASS   |
| F03 | APB enable allows traffic                       | `router_smoke_tb.sv`, `router_disabled_tb.sv`                                  | APB CTRL write sets `enable_q=1`; packet transfers afterward | P0       | PASS   |
| F04 | Default routing follows `s_tdest`               | `router_smoke_tb.sv`                                                           | `tdest=0` routes to m0; `tdest=1` routes to m1               | P0       | PASS   |
| F05 | Force-route mode overrides `s_tdest`            | `router_mode_tb.sv`                                                            | `route_mode=01` forces m0; `route_mode=10` forces m1         | P0       | PASS   |
| F06 | Backpressure blocks input handshake             | `router_backpressure_tb.sv`                                                    | `m0_tready=0` causes `s_tready=0`; packet remains pending    | P0       | PASS   |
| F07 | Packet counter counts successful transfers only | `router_smoke_tb.sv`, `router_backpressure_tb.sv`, `router_apb_readback_tb.sv` | Counter increments only after `tvalid && tready`             | P0       | PASS   |
| F08 | Illegal APB write raises error                  | `router_illegal_apb_tb.sv`                                                     | Illegal write address raises `pslverr` during access phase   | P1       | PASS   |
| F09 | Illegal APB read raises error                   | `router_illegal_apb_tb.sv`                                                     | Illegal read address raises `pslverr` during access phase    | P1       | PASS   |
| F10 | APB CTRL readback is correct                    | `router_apb_readback_tb.sv`                                                    | `prdata` returns reset value and programmed CTRL value       | P1       | PASS   |
| F11 | APB STATUS readback is correct                  | `router_apb_readback_tb.sv`                                                    | `prdata[0]` reflects current enable status                   | P1       | PASS   |
| F12 | APB COUNT readback is correct                   | `router_apb_readback_tb.sv`                                                    | `prdata` returns final packet count                          | P1       | PASS   |

## 6. Directed Test Summary

| Test ID | Testbench                           | Description                                         | Result |
| ------- | ----------------------------------- | --------------------------------------------------- | ------ |
| T01     | `router_smoke_tb.sv`                | Basic APB enable, default routing, and packet count | PASS   |
| T02     | `router_backpressure_tb.sv`         | Output 0 backpressure and delayed packet transfer   | PASS   |
| T03     | `router_mode_tb.sv`                 | Force-route configuration through APB `route_mode`  | PASS   |
| T04     | `router_reset_during_traffic_tb.sv` | Reset while a packet is pending under backpressure  | PASS   |
| T05     | `router_disabled_tb.sv`             | Traffic rejection while router enable is low        | PASS   |
| T06     | `router_illegal_apb_tb.sv`          | Illegal APB read and write error handling           | PASS   |
| T07     | `router_apb_readback_tb.sv`         | APB readback of CTRL, STATUS, and COUNT             | PASS   |

## 7. Current Coverage Status

The following functional scenarios are covered by directed tests:

* Reset before traffic
* Reset during pending traffic
* Router disabled
* Router enabled through APB
* Default destination routing
* Forced output 0 routing
* Forced output 1 routing
* Output backpressure
* Packet counter update
* Illegal APB read and write
* APB register readback

## 8. Closure Criteria

The directed-test phase is considered complete when:

* All P0 and P1 requirements have at least one mapped testbench
* All mapped tests pass
* No known functional failures remain
* Waveform evidence exists for each directed test
* README and testplan provide traceability from feature to test result

## 9. Open Verification Items

The following items are planned for the next verification phase:

* Add reusable protocol checkers
* Add an end-to-end scoreboard
* Add SystemVerilog Assertions
* Add functional coverage
* Add constrained-random traffic and seed-based regression
* Produce a verification closure report
