# Open issues

---

## ISSUE-001 — MSC stub closes TCP connection mid-test → LU wait timeout

**Status:** Open  
**Affects:** TC_26_2_3 (confirmed), likely any test that power-cycles the mobile  
**Evidence:** `results/week02/run20260528-115031-N1/TC_26_2_3/ttcn3-pod.log`

### Symptom

TC_26_2_3 FAILs on k8s (`FAIL: No Location Update Request within 90s`).
Same test PASSes on docker-compose.

### What happens

1. Test power-cycles the mobile via VTY to trigger a fresh LU.
2. VTY fails (`Connection refused`) — mobile process is mid-restart.
3. ~49 s into the 90 s LU wait: **`MSC_Port: Connection closed by stub`**.
4. With no MSC connection the LU can never be received → timeout → FAIL.

On docker-compose, `docker restart` is used instead of VTY. The mobile
comes back faster and the stub doesn't drop the connection in time.

### Hypotheses

1. MSC stub has an idle timeout that fires during the mobile restart gap.
2. MSC stub crashes/restarts when the BSC-side SS7 link goes quiet.
3. Mobile restart is slower in k8s (pcscd + jcardsim chain).

### To investigate

- Check MSC stub logs during a failing run: `kubectl logs -n <ns> deployment/msc-test-stub`
- Check whether the stub has a configurable idle timeout.
- Check how long the mobile actually takes to restart in k8s vs docker-compose.
- Ask Makarand: was the VTY power-cycle k8s path intended to work, or left as a stub?
