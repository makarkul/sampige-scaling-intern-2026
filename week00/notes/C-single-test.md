# TTCN-3 Single Test Run

## Test Executed

TC_26_2_3

## Verdict Output

```text
2026/May/22 04:52:57.450292 EXECUTOR - TTCN Logger v2.2 options: TimeStampFormat:=DateTime; LogEntityName:=No; LogEventTypes:=Yes; SourceInfoFormat:=Single; LogSensitiveData:=No; *.FileMask:=LOG_ALL; *.ConsoleMask:=ERROR | TESTCASE | USER | VERDICTOP | WARNING; LogFileSize:=0; LogFileNumber:=1; DiskFullAction:=Error
2026/May/22 04:52:57.450688 TESTCASE TC_26_2_3.ttcn3:42 Test case TC_26_2_3 started.
2026/May/22 04:53:50.796109 VERDICTOP TC_26_2_3.ttcn3:497 setverdict(pass): none -> pass
2026/May/22 04:53:50.797461 VERDICTOP TC_26_2_3.ttcn3:512 Setting final verdict of the test case.
2026/May/22 04:53:50.797536 VERDICTOP TC_26_2_3.ttcn3:512 Local verdict of MTC: pass
2026/May/22 04:53:50.797578 VERDICTOP TC_26_2_3.ttcn3:512 No PTCs were created.
2026/May/22 04:53:50.797600 TESTCASE TC_26_2_3.ttcn3:512 Test case TC_26_2_3 finished. Verdict: pass
2026/May/22 04:53:50.797760 STATISTICS - Verdict statistics: 0 none (0.00 %), 1 pass (100.00 %), 0 inconc (0.00 %), 0 fail (0.00 %), 0 error (0.00 %).
2026/May/22 04:53:50.797820 STATISTICS - Test execution summary: 1 test case was executed. Overall verdict: pass
```

## Reflection
- Most of the wall-clock time appears to be spent in GSM stack bring-up, container initialization, and subscriber attachment. 
- The actual TTCN-3 testcase execution itself seemed shorter compared to the setup and teardown phases.
