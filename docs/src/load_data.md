# Load Data
## Load Timeseries Data
`load_timeseries_data()` loads the data for a given `application` and `region`.
Possible applications are
- `DAM`: Day ahead market price data
- `CEP`: Capacity Expansion Problem data

Possible regions are:
- `GER`: Germany
- `CA`: California
- `TX`: Texas

The optional input parameters to `load_timeseries_data()` are the number of periods `K` and the number of time steps per period `T`. By default, they are chosen such that they result in daily time slices.

```@docs
load_timeseries_data
```
### Example loading timeseries data
```@example
using ClustForOpt
state="GER_1"
# laod ts-input-data
ts_input_data, = load_timeseries_data("CEP", state; T=24)

using Plots
plot(ts_input_data.data["solar-germany"], legend=false, linestyle=:dot, xlabel="Time [h]", ylabel="Solar availability factor [%]")
```


## Load CEP Data
`load_cep_data()` lodes the extra data for the `CEP` and can take the following regions:
- `GER`: Germany
- `CA`: California
- `TX`: Texas

```@docs
load_cep_data
```
### Example loading CEP Data
```@example
using ClustForOpt
state="GER_1"
# laod ts-input-data
cep_data = load_cep_data(state)
cep_data.fix_costs
```
