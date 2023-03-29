# tiflash-autoscale-tester

## Step 1: Prepare
Prepare a TiDB test environment.

```shell
cd tiflash-cse-test
bash run.sh t1
```


## Step 2: Set configuration
Set the configuration in `config.toml`.

Some important configurations are listed below.
- `needLoadData`: Whether to load data. If `true`, the data will be loaded before the test.
- `enableAutoScale`: Whether to enable auto-scaling. If `true`, the auto-scaling will be enabled and tested.
- `check`: Periodically determine whether tiflash is ready (TiFlash Replica Available) before starting the test.

Note that `needLoadData`, `enableAutoScale`, and `workload` must be configured in yaml file.

## Step 3: Run
Run the following command to start the test.

```go test -v -cover ./... ```