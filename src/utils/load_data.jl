"""
    load_timeseries_data(application::String, region::String, T-#Segments,
years::Int64=# year to be selected for the time series, att::Array{String,1}=# attributes to be loaded)
Loading from .csv files in a the folder ../ClustForOpt/data/{application}/{region}/TS
Loads all attributes if the `att`-Array is empty or only the ones specified in it
Timestamp-column has to be called Timestamp
Other columns have to be called with the location/node name
for application:
- `DAM`: Day Ahead Market
- `CEP`: Capacity Expansion Problem
and regions:
- `"GER_1"`: Germany 1 node
- `"GER_18"`: Germany 18 nodes
- `"CA_1"`: California 1 node
- `"CA_14"`: California 14 nodes
- `"TX_1"`: Texas 1 node
"""
function load_timeseries_data( application::String,
                              region::String;
                              T::Int64=24,
                              years::Int64=2016,
                              att::Array{String,1}=Array{String,1}())
    return load_timeseries_data(application, region; T=T, years=[years], att=att)
end

"""
    load_timeseries_data(application::String, region::String, T-#Segments,
years::Array{Int64,1}=# years to be selected for the time series, att::Array{String,1}=# attributes to be loaded)
Loading from .csv files in a the folder ../ClustForOpt/data/{application}/{region}/TS
Loads all attributes if the `att`-Array is empty or only the ones specified in it
Timestamp-column has to be called Timestamp
Other columns have to be called with the location/node name
for application:
- `DAM`: Day Ahead Market
- `CEP`: Capacity Expansion Problem
and regions:
- `"GER_1"`: Germany 1 node
- `"GER_18"`: Germany 18 nodes
- `"CA_1"`: California 1 node
- `"CA_14"`: California 14 nodes
- `"TX_1"`: Texas 1 node
"""
function load_timeseries_data( application::String,
                              region::String;
                              T::Int64=24,
                              years::Array{Int64,1}=[2016],
                              att::Array{String,1}=Array{String,1}())
  dt = Dict{String,Array}()
  num=0
  K=0
  # Generate the data path based on application and region
  data_path=normpath(joinpath(dirname(@__FILE__),"..","..","data",application,region,"TS"))
  #Loop through all available files
  for fulldataname in readdir(data_path)
      dataname=split(fulldataname,".")[1]
      #
      if isempty(att) || dataname in att
          #Load the data
          data_df=CSV.read(joinpath(data_path,fulldataname);allowmissing=:none)
          # Add it to the dictionary
          K=add_timeseries_data!(dt,dataname, data_df; K=K, T=T, years=years)
      end
  end
  # Store the data
  ts_input_data =  ClustData(FullInputData(region, years, num, dt),K,T)
  return ts_input_data
end #load_timeseries_data

"""
    add_timeseries_data!(dt::Dict{String,Array}, data::DataFrame; K::Int64=0, T::Int64=24, years::Array{Int64,1}=[2016])
selects first the years and second the data_points so that their number is a multiple of T and same with the other timeseries
"""
function add_timeseries_data!(dt::Dict{String,Array},
                            dataname::SubString,
                            data::DataFrame;
                            K::Int64=0,
                            T::Int64=24,
                            years::Array{Int64,1}=[2016])
    # find the right years to select
    data_selected=data[in.(data[:year],[years]),:]
    for column in eachcol(data_selected, true)
        # check that this column isn't time or year
        if !(column[1] in [:Timestamp,:time,:Time,:Zeit,:year])
            K_calc=Int(floor(length(column[2])/T))
            if K_calc!=K && K!=0
                @error("The time_series $(column[1]) has K=$K_calc != K=$K of the previous")
            else
                K=K_calc
            end
            dt[dataname*"-"*string(column[1])]=Float64.(column[2][1:(Int(T*K))])
        end
    end
    return K
end

"""
        combine_timeseries_weather_data(ts::ClustData,ts_weather::ClustData)
-`ts` is the shorter timeseries with e.g. the demand
-`ts_weather` is the longer timeseries with the weather information
The `ts`-timeseries is repeated to match the number of periods of the longer `ts_weather`-timeseries.
If the number of periods of the `ts_weather` data isn't a multiple of the `ts`-timeseries, the necessary number of the `ts`-timeseries periods 1 to x are attached to the end of the new combined timeseries.
"""
function combine_timeseries_weather_data(ts::ClustData,
                                        ts_weather::ClustData)
    ts.T==ts_weather.T || throw(@error "The number of timesteps per period is not the same: `ts.T=$(ts.T)≢$(ts_weather.T)=ts_weather.T`")
    ts.K<=ts_weather.K || throw(@error "The number of timesteps in the `ts`-timeseries isn't shorter or equal to the ones in the `ts_weather`-timeseries.")
    ts_weather.K%ts.K==0 || @warn "The number of periods of the `ts_weather` data isn't a multiple of the other `ts`-timeseries: periods 1 to $(ts_weather.K%ts.K) are attached to the end of the new combined timeseries."
    ts_data=deepcopy(ts_weather.data)
    ts_mean=deepcopy(ts_weather.mean)
    ts_sdv=deepcopy(ts_weather.sdv)
    for (k,v) in ts.data
        ts_data[k]=repeat(v, 1, ceil(Int,ts_weather.K/ts.K))[:,1:ts_weather.K]
    end
    for (k,v) in ts.mean
        ts_mean[k]=v
    end
    for (k,v) in ts.sdv
        ts_sdv[k]=v
    end

    return ClustData(ts.region, ts_weather.years, ts_weather.K, ts_weather.T, ts_data, ts_weather.weights, ts_mean, ts_sdv, ts_weather.deltas, ts_weather.k_ids)
end

"""
    load_cep_data(region::String)
Loading from .csv files in a the folder ../ClustForOpt/data/CEP/{region}/
Follow instructions for the CSV-Files:
- `nodes`:       `nodes x region, infrastruct, capacity-of-different-tech... in MW_el`
- `var_costs`:     `tech x [USD for fossils: in USD/MWh_el, CO2 in kg-CO₂-eq./MWh_el]` # Variable costs per year
- `fix_costs`:     `tech x [USD in USD/MW_el, CO2 in kg-CO₂-eq./MW_el]` # Fixed costs per year
- `cap_costs`:     `tech x [USD in USD/MW_el, CO2 in kg-CO₂-eq./MW_el]` # Entire (NOT annulized) Costs per Investment in technology
- `techs`:        `tech x [categ,sector,lifetime in years,effic in %,fuel]`
- `lines`:       `lines x [node_start,node_end,reactance,resistance,power,voltage,circuits,length]`
for regions:
- `"GER_1"`: Germany 1 node
- `"GER_18"`: Germany 18 nodes
- `"CA_1"`: California 1 node
- `"CA_14"`: California 14 nodes
- `"TX_1"`: Texas 1 node
"""
function load_cep_data(region::String)
  data_path=normpath(joinpath(dirname(@__FILE__),"..","..","data","CEP",region))
  nodes=CSV.read(joinpath(data_path,"nodes.csv"),allowmissing=:none)
  var_costs=CSV.read(joinpath(data_path,"var_costs.csv"),allowmissing=:none)
  fix_costs=CSV.read(joinpath(data_path,"fix_costs.csv"),allowmissing=:none)
  cap_costs=CSV.read(joinpath(data_path,"cap_costs.csv"),allowmissing=:none)
  techs=CSV.read(joinpath(data_path,"techs.csv"),allowmissing=:none)
  if isfile(joinpath(data_path,"lines.csv"))
      lines=CSV.read(joinpath(data_path,"lines.csv"),allowmissing=:none)
  else
      lines=DataFrame()
  end
  # The time for the cap-investion to be paid back is the minimum of the max. financial lifetime and the lifetime of the product (If it's just good for 5 years, you'll have to rebuy one after 5 years)
  # annuityfactor = (1+i)^y*i/((1+i)^y-1) , i-discount_rate and y-payoff years
  techs[:annuityfactor]=map((lifetime,financial_lifetime,discount_rate) -> (1+discount_rate)^(min(financial_lifetime,lifetime))*discount_rate/((1+discount_rate)^(min(financial_lifetime,lifetime))-1), techs[:lifetime],techs[:financial_lifetime],techs[:discount_rate])
  # The capital costs (given by currency value in column 4) are adjusted by the annuity factor"
  cap_costs[4]=map((tech, EUR) -> find_val_in_df(techs,:tech,tech,:annuityfactor)*EUR, cap_costs[:tech], cap_costs[4])
  # Emissions (column 5 and on) are just devided by the lifetime, without discount_rate
  for name in names(cap_costs)[5:end]
      cap_costs[name]=map((tech, emission) -> emission/find_val_in_df(techs,:tech,tech,:lifetime), cap_costs[:tech], cap_costs[name])
  end
  return OptDataCEP(region,nodes,var_costs,fix_costs,cap_costs,techs,lines)
end #load_pricedata
