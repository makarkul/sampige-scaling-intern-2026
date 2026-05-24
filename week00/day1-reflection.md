# Day 1 — reflection

Fill in by end of day. Bullets are fine. Keep it short — this is what
Makarand reviews on Friday, not a writeup.

Reference the evidence files under `week00/notes/` rather than pasting logs
inline.

---

## 1. What the stack looks like to me now

In your own words, what does the existing demo actually do when you run
`./virtual-um-demo.sh start`? Aim for a diagram or a 5–10 line description.

- When `./virtual-um-demo.sh start` is executed, it starts a complete GSM network environment using Docker containers.
- It brings up components such as HLR, MSC, BSC, MGW, BTS, STP, VirtPHY and a MS.
- The script creates the Docker network, starts all required services and starts communication between them.
- During startup, a test subscriber can be registered in the HLR database.
- The mobile station then performs network registration and location updating.
- Once the attach procedure succeeds and the mobile reaches "normal service" state, the system becomes ready for GSM protocol testing and TTCN-3 test execution.

- Components that come up:
  -  Container osmo-mgw
  -  Container osmo-stp
  -  Container osmo-hlr
  -  Container osmo-msc
  -  Container osmo-bsc
  -  Container osmo-bts-virtual
  -  Container osmo-virtphy
  -  Container osmo-mobile-ms1
 
- The MS attaches to the network via:
  - MS → Virtual Um → BTS → BSC → MSC → HLR → MS Attached → Normal Service
- The TTCN-3 suite plugs in where: The TTCN-3 suite sits at the MSC layer

 # TTCN-3 Test Runner Connections

| Connection | Target | Protocol | Purpose |
|------------|----------|-----------|-----------|
| MSC port | `172.20.0.12:5000` | TCP/JSON | Commands to `msc-test-stub` (send LU Accept, Identity Request, etc.) |
| VTY port | `172.20.0.22:4247` | Telnet/VTY | Controls `osmo-mobile` (trigger MS actions, read state) |
| L / GSMTAP | `127.0.0.1:4729` send / `0.0.0.0:4730` listen | UDP/GSMTAP | Sniffs Layer-2/3 frames mirrored from the mobile |

## Containers involved

- **msc-test-stub (`172.20.0.12`)**  
  Python MSC simulator; the test drives it via JSON to inject network-side messages (LU Accept, paging, etc.) over M3UA into the BSC/mobile path.

- **osmo-mobile (`172.20.0.22`)**  
  OsmocomBB MS; the test controls it via VTY to trigger actions (MS restart, shutdown) and reads MM/RR state.

- **GSMTAP mirror**  
  One-way communication: `osmo-mobile` broadcasts a copy of every L2/L3 frame to UDP `4730`; the TTCN-3 L port listens there for passive observation without injecting traffic.

## 2. What I ran today

- Section B (virtual-um demo end-to-end): worked
  - Bring-up time observed: 51.761750865 seconds
  - Teardown time observed: 44.256717467 seconds
- Section C (single TC_26_2_3): Pass — wall-clock 53 seconds
- Section D (campaign `smoke`): Paritally worked — wall-clock 6-7 minutes for test 1, test 2 failed (over 25 minutes) and test 3 was not started.

Evidence: `week00/notes/`.

## 3. The two phases that look most expensive

The internship is about amortizing the parts of a test run that don't depend
on test logic. Based on what you saw today, which phases look like they
dominate wall-clock?

The phases that appear to dominate wall-clock time are mostly infrastructure and network setup rather than the TTCN-3 test logic itself.

- Phase 1: Container startup + image loading + Docker network creation + service initialization.
- Phase 2: GSM stack bring-up before the mobile station becomes usable.
- Phase 3: Container teardown and cleanup.

The TTCN-3 logic itself seems relatively short compared to startup, network initialization, and attachment procedures. 
This suggests that reducing repeated stack bring-up and reusing infrastructure across multiple tests could significantly reduce total runtime.

## 4. Surprises and stuck points

Anything that was different from what you expected, or that you had to work
around. One bullet per surprise; link the relevant log path.

- <surprise / sticking point> → <how you handled it / what you'd ask>
- Test 2 of `smoke` campaign failing. I asked you whether the test was still going on or whether it had failed. → I then checked the logs and understood how to read the logs and check where it failed.

## 5. Questions for Makarand

The cheapest time to ask these is now.

- What kind of tests are present in the TTCN-3 test suite? What components are they trying to test exactly?
- For the week 1 baseline, what numbers matter the most: wall-clock time, RAM usage, container count, or something else?

## 6. Plan for tomorrow (day 2)

Two or three concrete things you intend to do. This becomes input to
`tracking.csv` and `docs/baseline.md`.

- Start with week 2 
