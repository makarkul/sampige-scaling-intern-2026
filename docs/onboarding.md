# Onboarding — Week 1

Welcome. The aim of week 1 is to make sure you can explain the existing setup to a
new joiner and produce one trustworthy baseline number on the target server.

## Accounts and access (day 1)

- GitHub access to this repo, push permission
- SSH access to the 48-core target server
- Access to the existing osmocom `docker compose` setup (clone it into `compose/`
  in this repo as a reference snapshot — do not modify it there)
- Slack / mail group, calendar invite for Friday demos

## Reading list

Don't try to read everything. Skim, build a mental map, come back when you need
details.

### osmocom / GSM (~half a day)

- osmocom project overview: https://osmocom.org/
- "Welcome to Osmocom" intro pages — what BSC, BTS, MSC, HLR, MGW, STP do
- GSM call flow at a high level (any textbook diagram is fine) — you just need to
  know roughly which component talks to which during attach, registration, MO/MT
  call, SMS
- Look at the existing `docker-compose.yml`: list every service, its image, its
  ports, its dependencies, and its config files. Put this in `docs/baseline.md`.

### TTCN-3 (~2 hours)

- TTCN-3 in one paragraph: a standardized test description language; tests are
  compiled and executed by a test runtime
- The osmocom TTCN-3 test suites: https://gitea.osmocom.org/ttcn3/osmo-ttcn3-hacks
- You do **not** need to write TTCN-3. You need to know how to invoke the runner,
  how it talks to the network under test, and how it reports results.

### Kubernetes basics (~half a day)

- Concepts: Pod, Deployment, StatefulSet, Service, ConfigMap, Secret, Namespace, Job
- `kubectl` cheat sheet — get, describe, logs, exec, apply, delete
- k3s install docs: https://docs.k3s.io/quick-start
- Helm in 30 minutes — chart structure, values, templating

## Environment setup (day 1–2)

On your laptop:

- A modern Linux or a Linux VM
- Docker, `kubectl`, `helm`, `k9s` (optional but very nice), `kompose`
- A local kind or minikube to play with manifests off the shared server

On the target server (paired with your mentor the first time):

- Confirm CPU count, RAM, disk, kernel version, `ulimit -n`, `sysctl
  net.netfilter.nf_conntrack_max` and a few similar limits — copy them into
  `docs/baseline.md` under "host capacity"
- Install k3s (week 2 — not day 1)

## Workflow

1. Branch off `main`: `git checkout -b w1/<short-name>`
2. Commit small, push often, open a PR when the slice makes sense
3. Update `tracking.csv`:
   - Set `Status` (Planned / In progress / Blocked / Done)
   - Fill `Start Date`, `End Date`, actual `Hours`
   - One-line `Notes` daily — what you did, what's next
4. Friday: 30-min demo + commit anything new under `results/weekNN/`

## What "good" looks like at the end of week 1

- You can draw the stack on a whiteboard from memory
- You can run the existing suite end-to-end from a clean clone with one command
- `docs/baseline.md` exists with the timing breakdown and host capacity
- One short and one long test case have per-phase timestamps in
  `results/week01/`
- You can name the two phases that dominate wall-clock time — these are what we're
  trying to amortize by running in parallel

## How to ask for help

- Search first (docs, source, git log) for ~30 minutes
- If still stuck, post in the channel with: what you tried, what you expected,
  what happened, the smallest reproducer
- If a blocker is going to cost more than half a day, escalate to your mentor
  immediately — don't sit on it
