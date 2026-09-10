# APB-Controlled AXI-Stream Router Verification

A SystemVerilog verification project for a simplified APB-controlled AXI-Stream router.

## Overview

The DUT receives packets from one AXI-Stream input interface and routes each packet to output `m0` or `m1`.

* APB is the control plane: it configures `enable` and `route_mode`.
* AXI-Stream is the data plane: it transfers packets using the `valid-ready` handshake.
* The project includes directed tests, waveform evidence, a testplan, and a reusable scoreboard.

```mermaid
flowchart LR
    APB["APB Master"] -->|"enable / route_mode"| DUT["APB-Controlled<br/>AXI-Stream Router"]
    SRC["AXI-Stream Source"] -->|"s_tdata / s_tdest / s_tvalid"| DUT
    DUT -->|"m0_tdata / m0_tvalid"| M0["Output m0"]
    DUT -->|"m1_tdata / m1_tvalid"| M1["Output m1"]
```

## DUT Features

* APB control register for `enable` and `route_mode`
* APB readback for CTRL, STATUS, and packet COUNT registers
* One AXI-Stream input interface
* Two AXI-Stream output interfaces
* Default routing based on `s_tdest`
* Force-route modes for output `m0` or `m1`
* Valid-ready backpressure propagation
* Packet counter
* Active-low asynchronous reset
* Illegal APB address error response through `pslverr`

## APB Register Map

| Address | Register | Description                                     |
| ------- | -------- | ----------------------------------------------- |
| `0x00`  | CTRL     | `enable` is bit 0; `route_mode` is bits `[2:1]` |
| `0x04`  | STATUS   | Readback of enable status                       |
| `0x08`  | COUNT    | Number of accepted AXI-Stream packets           |

## Route Mode Encoding

| `route_mode` | Behavior                                        |
| ------------ | ----------------------------------------------- |
| `2'b00`      | Route according to `s_tdest`                    |
| `2'b01`      | Force all packets to `m0`                       |
| `2'b10`      | Force all packets to `m1`                       |
| `2'b11`      | Reserved; DUT uses default routing by `s_tdest` |

## AXI-Stream Handshake

A packet transfer occurs only when:

```text
s_tvalid && s_tready
```

For an output interface, a packet is consumed only when:

```text
m*_tvalid && m*_tready
```

If the selected output is not ready, the router propagates backpressure by deasserting `s_tready`.

## Repository Structure

```text
.
├── rtl/
│   └── apb_axis_router.sv
├── tb/
│   ├── router_smoke_tb.sv
│   ├── router_backpressure_tb.sv
│   ├── router_mode_tb.sv
│   ├── router_reset_during_traffic_tb.sv
│   ├── router_disabled_tb.sv
│   ├── router_illegal_apb_tb.sv
│   ├── router_apb_readback_tb.sv
│   ├── router_scoreboard.sv
│   └── router_scoreboard_tb.sv
├── docs/
│   ├── testplan.md
│   └── images/
│       ├── smoke_test_waveform.png
│       ├── backpressure_test_waveform.png
│       ├── route_mode_test_waveform.png
│       ├── reset_during_traffic_waveform.png
│       ├── disabled_router_waveform.png
│       ├── illegal_apb_waveform.png
│       ├── apb_readback_waveform.png
│       ├── scoreboard_integration_waveform.png
│       ├── assertion_checker_waveform.png
│
└── README.md
```

## Directed Test Results

| # | Testbench                           | Scenario                                                     | Result |
| - | ----------------------------------- | ------------------------------------------------------------ | ------ |
| 1 | `router_smoke_tb.sv`                | Default routing using `s_tdest`; checks packet counter       | PASS   |
| 2 | `router_backpressure_tb.sv`         | Selected output is not ready; checks `s_tready` backpressure | PASS   |
| 3 | `router_mode_tb.sv`                 | Checks force-`m0` and force-`m1` route modes                 | PASS   |
| 4 | `router_reset_during_traffic_tb.sv` | Applies reset during traffic and verifies recovery           | PASS   |
| 5 | `router_disabled_tb.sv`             | Router disabled; verifies no packet is accepted or forwarded | PASS   |
| 6 | `router_illegal_apb_tb.sv`          | Invalid APB address; checks `pslverr` response               | PASS   |
| 7 | `router_apb_readback_tb.sv`         | Reads CTRL, STATUS, and COUNT through APB                    | PASS   |
| 8 | `router_scoreboard_tb.sv`           | Automated end-to-end checking with a reusable scoreboard     | PASS   |
| 9 | `router_sva_tb.sv` | Assertion-based protocol checker: disabled state, backpressure stability, and no simultaneous output transfers | PASS |

## Scoreboard

`router_scoreboard.sv` is a reusable checker connected to the DUT interfaces.

When an input packet is accepted, the scoreboard:

1. Captures the expected packet data.
2. Calculates the expected output from `route_mode` and `s_tdest`.
3. Stores both values in an expected queue.
4. Waits for an output handshake.
5. Checks that the packet appears on the expected output with unchanged data.
6. Reports an error with `$fatal` if data or destination does not match.

This separates expected behavior from the testbench stimulus and makes the verification environment more scalable.

## Waveform Evidence

<details>
<summary><b>1. Smoke Test — Default Routing</b></summary>

Verifies default packet routing based on `s_tdest` and packet counter updates.

![Smoke test waveform](docs/images/smoke_test_waveform.png)

</details>

<details>
<summary><b>2. Backpressure Test</b></summary>

Verifies that the router deasserts `s_tready` and does not count a packet while selected output `m0` is not ready.

![Backpressure test waveform](docs/images/backpressure_test_waveform.png)

</details>

<details>
<summary><b>3. Route Mode Test</b></summary>

Verifies APB-programmable force-route behavior for `m0` and `m1`.

![Route mode test waveform](docs/images/route_mode_test_waveform.png)

</details>

<details>
<summary><b>4. Reset During Traffic Test</b></summary>

Verifies that reset clears router state and the router correctly accepts new traffic after reset release.

![Reset during traffic waveform](docs/images/reset_during_traffic_waveform.png)

</details>

<details>
<summary><b>5. Disabled Router Test</b></summary>

Verifies that no traffic is accepted or forwarded while `enable_q` is low.

![Disabled router waveform](docs/images/disabled_router_waveform.png)

</details>

<details>
<summary><b>6. Illegal APB Access Test</b></summary>

Verifies that an unsupported APB address asserts `pslverr` and does not modify router state.

![Illegal APB waveform](docs/images/illegal_apb_waveform.png)

</details>

<details>
<summary><b>7. APB Readback Test</b></summary>

Verifies readback values from the CTRL, STATUS, and COUNT registers.

![APB readback waveform](docs/images/apb_readback_waveform.png)

</details>

<details>
<summary><b>8. Scoreboard Integration Test</b></summary>

Verifies default routing, force routing, backpressure behavior, packet counting, and automatic data/destination checking using a reusable scoreboard.

![Scoreboard integration waveform](docs/images/scoreboard_integration_waveform.png)


<details>
<summary><b>9. Assertion Checker Integration Test</b></summary>

Verifies key protocol properties automatically using an Icarus-compatible assertion checker:

- A disabled router must not accept input traffic.
- Output data and valid must remain stable while the selected output is backpressured.
- The router must not complete transfers to m0 and m1 in the same cycle.
- Default routing, force routing, backpressure, and packet counting are exercised together.

> Note: `router_sva.sv` contains the equivalent formal SystemVerilog Assertion (SVA) properties.  
> `router_assertion_checker.sv` is the Icarus-compatible procedural implementation used for this simulation.

![Assertion checker waveform](docs/images/assertion_checker_waveform.png)

</details>



</details>

## Key Verification Findings

* A packet is accepted only when `s_tvalid && s_tready`.
* A selected output must assert both `tvalid` and `tready` to complete a transfer.
* Backpressure from the selected output propagates to the AXI-Stream input through `s_tready`.
* `enable_q = 0` prevents packet acceptance and forwarding.
* `presetn = 0` clears router control state and packet count.
* APB reads expose configured control and status values.
* Illegal APB accesses assert `pslverr`.
* The scoreboard independently checks expected destination and packet data for every completed transfer.

## How to Run

1. Open [EDA Playground](https://www.edaplayground.com/).
2. Select **SystemVerilog / Icarus Verilog**.
3. Paste `rtl/apb_axis_router.sv` and, for the scoreboard test, `tb/router_scoreboard.sv` into the **Design** panel.
4. Paste one testbench from `tb/` into the **Testbench** panel.
5. Enable waveform generation with `$dumpfile` and `$dumpvars`.
6. Click **Run**.
7. Check the simulation log for `PASS` and inspect the waveform in EPWave.

## Next Steps

* Add SystemVerilog Assertions (SVA) for protocol properties.
* Add functional coverage for route modes, destinations, enable state, and APB accesses.
* Create constrained-random packet stimulus.
* Run multiple random seeds as a regression.
* Add a regression script and verification closure report.
