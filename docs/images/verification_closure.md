# Verification Closure Report

## 1. Purpose

This report summarizes the verification status of the APB-Controlled AXI-Stream Router.

The goal is to determine whether the current RTL implementation has sufficient verification evidence for this project release.

## 2. DUT Scope

The DUT is an APB-controlled AXI-Stream router with:

* One APB slave interface
* One AXI-Stream input interface
* Two AXI-Stream output interfaces: m0 and m1
* Enable control
* Default routing based on `s_tdest`
* Force-route modes for m0 and m1
* Valid-ready backpressure handling
* Packet counter
* Active-low asynchronous reset
* APB readback registers
* Illegal APB address response through `pslverr`

## 3. Verification Environment

The verification environment contains:

| Component                     | Purpose                                           |
| ----------------------------- | ------------------------------------------------- |
| Directed testbenches          | Apply focused scenarios for each DUT feature      |
| Waveform evidence             | Visual confirmation of signal-level behavior      |
| Testplan                      | Maps requirements to tests                        |
| Scoreboard                    | Automatically checks packet data and destination  |
| Assertion checker             | Automatically checks protocol properties          |
| Functional coverage collector | Tracks required scenario coverage bins            |
| Regression script             | Runs all tests automatically on the local machine |

## 4. Directed Test Status

| #  | Test                               | Verification Focus                               | Result |
| -- | ---------------------------------- | ------------------------------------------------ | ------ |
| 1  | Smoke test                         | Default routing and packet counter               | PASS   |
| 2  | Backpressure test                  | `s_tready` propagation and held packet behavior  | PASS   |
| 3  | Route mode test                    | Force-m0 and force-m1 configuration              | PASS   |
| 4  | Reset during traffic test          | Reset recovery and state clearing                | PASS   |
| 5  | Disabled router test               | No acceptance or forwarding when disabled        | PASS   |
| 6  | Illegal APB test                   | `pslverr` assertion and state protection         | PASS   |
| 7  | APB readback test                  | CTRL, STATUS, and COUNT readback                 | PASS   |
| 8  | Scoreboard integration test        | Automated end-to-end data and destination checks | PASS   |
| 9  | Assertion checker integration test | Protocol stability and mutual-exclusion checks   | PASS   |
| 10 | Functional coverage test           | Required functional coverage bins                | PASS   |

## 5. Scoreboard Status

The reusable scoreboard verifies each accepted input packet against the completed output transfer.

Checks performed:

* Expected destination is calculated from `route_mode` and `s_tdest`.
* Packet data is stored in an expected queue.
* Output packet data must match the expected input data.
* Output destination must match the expected m0 or m1 route.
* Both outputs must not complete a transfer in the same cycle.
* Queue underflow and unexpected output traffic cause simulation failure.

Scoreboard integration test result:

```text
PASS: scoreboard integration test completed successfully.
```

## 6. Assertion Checker Status

The Icarus-compatible assertion checker monitors core protocol behavior during simulation.

| Property                                            | Status |
| --------------------------------------------------- | ------ |
| Disabled router does not assert `s_tready`          | PASS   |
| m0 data and valid remain stable during backpressure | PASS   |
| m1 data and valid remain stable during backpressure | PASS   |
| m0 and m1 do not transfer simultaneously            | PASS   |

The repository also includes `router_sva.sv`, which expresses equivalent properties using formal SystemVerilog Assertion syntax. The executed Icarus flow uses `router_assertion_checker.sv` because Icarus does not support complete concurrent SVA syntax.

## 7. Functional Coverage Status

The coverage collector tracks the required core functional bins.

| Coverage Bin             | Status |
| ------------------------ | ------ |
| Router disabled          | HIT    |
| Router enabled           | HIT    |
| Default route mode `00`  | HIT    |
| Force-m0 route mode `01` | HIT    |
| Force-m1 route mode `10` | HIT    |
| Destination `0`          | HIT    |
| Destination `1`          | HIT    |
| Output m0 transfer       | HIT    |
| Output m1 transfer       | HIT    |
| Backpressure observed    | HIT    |
| Illegal APB access       | HIT    |

Coverage test result:

```text
Required-bin coverage : 10 / 10
PASS: functional coverage test completed successfully.
```

The required functional coverage model has no open bins for the current project scope.

## 8. Regression Status

The local regression script runs all ten verification tests using Icarus Verilog:

```bash
./scripts/run_regression.sh
```

Latest regression result:

```text
Passed: 10
Failed: 0
Total : 10
REGRESSION PASS
```

## 9. Open Risks and Future Work

This project has achieved closure for its defined directed-test and manual functional-coverage scope. The following items remain future improvements rather than release blockers:

* Run formal concurrent SVA properties using a commercial simulator.
* Add functional cross-coverage, such as `route_mode × s_tdest`.
* Add constrained-random packet and backpressure generation.
* Run multi-seed regression.
* Add code coverage and toggle coverage.
* Extend the scoreboard to support multi-packet ordering stress tests.

## 10. Closure Decision

The current APB-Controlled AXI-Stream Router RTL is considered **verified for the defined project scope**.

Release evidence:

```text
Directed tests       : 10 / 10 PASS
Scoreboard           : PASS
Assertion checker    : PASS
Functional coverage  : 10 / 10 required bins hit
Regression           : 10 / 10 PASS
```

No known blocking failures remain within the current verification scope.

## 11. Sign-Off Summary

| Item                     | Status   |
| ------------------------ | -------- |
| RTL compilation          | PASS     |
| Directed verification    | PASS     |
| Scoreboard checking      | PASS     |
| Assertion-based checking | PASS     |
| Functional coverage      | PASS     |
| Regression               | PASS     |
| Documentation            | COMPLETE |
| Current project closure  | APPROVED |
