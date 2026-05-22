# Week 1 Baseline Hints

| Measurement | Observation |
|---|---|
| Short testcase | `TC_26_2_3` |
| Short testcase wall-clock | ~53 seconds |
| Smoke campaign | 3 tests |
| Smoke campaign wall-clock | ~30+ minutes observed |
| Peak container count during single test | Measured using `docker ps \| wc -l` |
| Approximate RAM usage | Measured using `docker stats --no-stream` |
| TTCN-3 verdict | `pass` for `TC_26_2_3` |
| Campaign behavior | Tests executed sequentially |
| Infrastructure overhead | Significant time spent in GSM stack/container bring-up and telecom initialization |

## Notes

- GSM stack startup and subscriber attachment contribute significantly to total execution time.
- Campaign execution appears to reuse telecom infrastructure logic across multiple tests.
- Long-running tests may spend substantial time waiting on telecom signaling procedures or timeout handling.
- Container logs and MTC logs are useful for correlating testcase expectations with actual network behavior.
