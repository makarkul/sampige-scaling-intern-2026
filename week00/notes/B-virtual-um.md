# Virtual-Um Demo Results

## Timings

t_start_to_ready = 51.761750865 seconds  
t_attach = 5.643241464 seconds  
t_teardown = 44.256717467 seconds  

## Step Notes

- `./virtual-um-demo.sh start` worked successfully.
- All `osmo-*` containers showed `Up` status in `./virtual-um-demo.sh status`.
- `./virtual-um-demo.sh subscriber` successfully registered IMSI `901700000000001`.
- Connected to BSC VTY using `telnet localhost 4242`.
- `show subscriber all` command worked on the BSC interface.
- Mobile attachment was confirmed through `docker logs osmo-mobile-ms1`.
- Observed successful `LOCATION UPDATING ACCEPT`.
- Observed transition to `MM IDLE, normal service`.
- Observed `imsi_attached=1` in mobile logs.
- `./virtual-um-demo.sh stop` completed successfully.
- `docker ps -a | grep osmo-` returned no output, confirming clean teardown.

## Observations

- The Virtual Um demo automatically registered a subscriber during startup.
- Docker containers for the GSM stack started correctly and exposed expected VTY ports.
- Mobile station successfully attached to the simulated GSM network.
