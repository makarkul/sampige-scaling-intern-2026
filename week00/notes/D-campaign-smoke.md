# Campaign Smoke Evidence

## Campaign Executed

smoke

## Tests Included

- TC_26_7_4_5_1
- TC_26_7_4_5_2
- TC_26_7_4_5_3

Total tests: 3

## Per-Test Wall Clock

- TC_26_7_4_5_1: approximately 6-7 minutes
- TC_26_7_4_5_2: exceeded 25 minutes during execution (failed) --> Log dir: `ttcn3/logs/TC_26_7_4_5_2-2026-05-22-113546`
- TC_26_7_4_5_3: not completed

## Observations

- Multiple `osmo-*` containers were started during the campaign.
- The network is brought up per-test looking at the `docker ps` timestamps 
- The second testcase (`TC_26_7_4_5_2`) took significantly longer than the first testcase.
- Campaign execution appears to involve substantial GSM stack initialization and telecom timer waits.

## Reflection

- Most of the wall-clock time appears to come from GSM stack bring-up, subscriber registration, network initialization, and waiting on telecom procedures/timeouts rather than the TTCN-3 logic itself.
- The second testcase appeared to spend a long time in execution and failed.
- Based on container activity and timestamps, the campaign infrastructure overhead seems significant relative to the actual testcase logic.
- The GSM stack is initialised each time.
- Container activity was monitored using `docker ps`.
- Further log inspection may be required for long-running testcase behavior.
