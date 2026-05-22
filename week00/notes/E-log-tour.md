# TTCN-3 Log Reading

## Useful Commands

### 1. Overall verdict (one line per test)
grep "Overall verdict" */MTC.log

### 2. Where did it fail?
grep "setverdict(fail\|setverdict(error" TC_XX/MTC.log

### 3. What was the test doing?
grep "USER" TC_XX/MTC.log | grep -v "Warning\|HEARTBEAT" | tail -30

### 4. Was the mobile alive?
grep -E "new state|Failed|refused|restart" TC_XX/container-logs/campaign-mobile.log | tail -20

### 5. Did the network side see anything?
tail -30 TC_XX/container-logs/campaign-msc-stub.log

The key intuition: MTC.log tells you what the test expected; container-logs tell you what actually happened in the network. Mismatches between the two are where bugs live.
