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

function load_cep_data_techs(data_path::String)
    tab=CSV.read(joinpath(data_path,"techs.csv"),allowmissing=:none)
    #Check existance of necessary column
    :tech in names(tab) || throw(@error "No column called `tech` in `techs.csv`")
    #Build empty OptVariable
    techs=OptVariable{OptDataCEPTech}(undef, unique(tab[:tech]); type="fv", axes_names=["tech"])
    # loop through all axes
    for tech in axes(techs,"tech")
        #categ
        categ=tab[(:tech,tech),:categ][1]
        #sector::String
        sector=tab[(:tech,tech),:sector][1]
        #eff::Number
        eff=tab[(:tech,tech),:eff][1]
        #time_series::String
        time_series=tab[(:tech,tech),:time_series][1]
        #lifetime::Number
        lifetime=tab[(:tech,tech),:lifetime][1]
        #financial_lifetime::Number
        financial_lifetime=tab[(:tech,tech),:lifetime][1]
        #discount_rate::Number
        discount_rate=tab[(:tech,tech),:discount_rate][1]
        # The time for the cap-investion to be paid back is the minimum of the max. financial lifetime and the lifetime of the product (If it's just good for 5 years, you'll have to rebuy one after 5 years)
        # annuityfactor = (1+i)^y*i/((1+i)^y-1) , i-discount_rate and y-payoff years
        annuityfactor=round((1+discount_rate)^(min(financial_lifetime,lifetime)) *discount_rate/ ((1+discount_rate) ^(min(financial_lifetime,lifetime))-1); sigdigits=4)
        # Add single data entry
        techs[tech]=OptDataCEPTech(categ,sector,eff,time_series,lifetime,financial_lifetime,discount_rate,annuityfactor)
    end
    return techs
end

function load_cep_data_nodes(data_path::String, techs::OptVariable)
    tab=CSV.read(joinpath(data_path,"nodes.csv"),allowmissing=:none)
    # Check exisistance of columns
    check_column(tab,[:node, :infrastruct])
    #Create empty OptVariable
    nodes=OptVariable{OptDataCEPNode}(undef, axes(techs,"tech"), unique(tab[:node]); type="fv", axes_names=["tech", "node"])
    for tech in axes(nodes,"tech")
        for node in axes(nodes,"node")
            #value
            power_ex=tab[(:node,node)][(:infrastruct,"ex"),Symbol(tech)][1]
            power_lim=tab[(:node,node)][(:infrastruct,"lim"),Symbol(tech)][1]
            #region
            region=tab[(:node,node),:region][1]
            #lat and lon
            latlon=LatLon(tab[(:node,node),:lat][1],tab[(:node,node),:lon][1])
            nodes[tech,node]=OptDataCEPNode(power_ex, power_lim, region, latlon)
        end
    end
    return nodes
end

function load_cep_data_lines(data_path::String, techs::OptVariable)
    if isfile(joinpath(data_path,"lines.csv"))
        tab=CSV.read(joinpath(data_path,"lines.csv"),allowmissing=:none)
        #Check existance of necessary column
        check_column(tab, [:line])

        #Create empty OptVariable
        lines=OptVariable{OptDataCEPLine}(undef, unique(tab[:tech]), unique(tab[:line]); type="fv", axes_names=["tech", "line"])
        for tech in axes(lines,"tech")
            for line in axes(lines,"line")
                #node_start
                node_start=tab[(:tech,tech)][(:line,line),:node_start][1]
                #node_end
                node_end=tab[(:tech,tech)][(:line,line),:node_end][1]
                #reactance
                reactance=tab[(:tech,tech)][(:line,line),:reactance][1]
                #resistance
                resistance=tab[(:tech,tech)][(:line,line),:resistance][1]
                #power
                power_ex=tab[(:tech,tech)][(:line,line),:power_ex][1]
                #power
                power_lim=tab[(:tech,tech)][(:line,line),:power_lim][1]
                #circuits
                circuits=tab[(:tech,tech)][(:line,line),:circuits][1]
                #voltage
                voltage=tab[(:tech,tech)][(:line,line),:voltage][1]
                #length
                length=tab[(:tech,tech)][(:line,line),:length][1]
                #eff calculate the efficiency provided as eff/km in techs
                #η=1-l_{line}⋅(1-η_{tech}) [-]
                eff=1-length*(1-techs[tech].eff)
                lines[tech,line]=OptDataCEPLine(node_start,node_end,reactance,resistance,power_ex,power_lim,circuits,voltage,length,eff)
            end
        end
        return lines
    else
        return lines=OptVariable{OptDataCEPLine}(undef, Array{String,1}(), Array{String,1}(); type="fv", axes_names=["tech", "line"])
    end
end

"""
    get_region_data(nodes::OptVariable,tab::DataFrame,tech::String,node::String,account::String)
Return the name of the region `region` or `"all"` that data is provided for in the `tab`
"""
function get_location_data(nodes::OptVariable,tab::DataFrame,tech::String,node::String,account::String)
    #determine region for this technology and node based on infromation in nodes
    region=nodes[tech,node].region
    #determine regions provided for this tech and this account in the data
    locations_data=unique(tab[(:tech,tech)][(:account,account),:location])
    #check if either specific `node`, `region` or a value for `all` regions is given
    if node in locations_data
        return node
    elseif region in locations_data
        return region
    elseif "all" in locations_data
        return "all"
    else
        return @error "region $region not provided in $(repr(tab))"
    end
end

function load_cep_data_costs(data_path::String, techs::OptVariable, nodes::OptVariable)
    tab=CSV.read(joinpath(data_path,"costs.csv"),allowmissing=:none)
    check_column(tab,[:tech, :location, :year, :account])
    impacts=String.(names(tab)[findfirst(names(tab).==:account)+1:end])
    #Create empty OptVariable
    costs=OptVariable{Number}(undef, axes(techs,"tech"), axes(nodes,"node"), unique(tab[:year]), ["cap_fix", "var"], impacts; type="fv", axes_names=["tech", "node", "year", "account", "impact"])
    for tech in axes(costs,"tech")
        for node in axes(costs,"node")
            for year in axes(costs,"year")
                for impact in axes(costs, "impact")
                    #Addition of capacity costs and fix maintanance cost - For numerical benefit in solving
                    account="cap_fix"
                        cap_location=get_location_data(nodes,tab,tech,node,"cap")
                        total_cap_cost=tab[(:tech,tech)][(:location,cap_location)][(:account,"cap")][(:year,year),Symbol(impact)][1]
                        #First impact shall always be currency - Currency of capacity cost is annulized with annuityfactor
                        if impact==axes(costs,"impact")[1]
                            annulized_cap_cost=round(total_cap_cost*techs[tech].annuityfactor;sigdigits=4)
                        else #Emissions of capacity cost are annulized with total lifetime
                            annulized_cap_cost=round(total_cap_cost/techs[tech].lifetime;sigdigits=4)
                        end
                        fix_location=get_location_data(nodes,tab,tech,node,"fix")
                        fix_cost=tab[(:tech,tech)][(:location,fix_location)][(:account,"fix")][(:year,year),Symbol(impact)][1]
                        costs[tech,node,year,account,impact]=annulized_cap_cost+fix_cost
                    #Variable cost is seperate
                    account="var"
                        var_location=get_location_data(nodes,tab,tech,node,account)
                        var_cost=tab[(:tech,tech)][(:location,fix_location)][(:account,account)][(:year,year),Symbol(impact)][1]
                        costs[tech,node,year,account,impact]=var_cost
                end
            end
        end
    end
    return costs
end

"""
    load_cep_data(region::String)
Loading from .csv files in a the folder ../ClustForOpt/data/CEP/{region}/
Follow instructions for the CSV-Files:
-`region::String`: name of state or region data belongs to
-`costs::OptVariable`: costs[tech,node,year,account,impact] - annulized costs [USD in USD/MW_el, CO2 in kg-CO₂-eq./MW_el]`
-`techs::OptVariable`: techs[tech] - OptDataCEPTech -
-`nodes::OptVariable`: nodes[tech,node] - OptDataCEPNode
-`lines::OptVarible`: lines[tech,line] - OptDataCEPLine
for regions:
- `"GER_1"`: Germany 1 node
- `"GER_18"`: Germany 18 nodes
- `"CA_1"`: California 1 node
- `"CA_14"`: California 14 nodes
- `"TX_1"`: Texas 1 node
"""
function load_cep_data(region::String)
  data_path=normpath(joinpath(dirname(@__FILE__),"..","..","data","CEP",region))
  techs=load_cep_data_techs(data_path)
  nodes=load_cep_data_nodes(data_path, techs)
  lines=load_cep_data_lines(data_path, techs)
  costs=load_cep_data_costs(data_path, techs, nodes)
  return OptDataCEP(region,costs,techs,nodes,lines)
end #load_pricedata

#= Interpolation
"""
    get_number_interpolation(numbers_data::Array{Number,1}, number::Number)
find the neighboring values to do an interpolation of `number` in `numbers_data`
if `number` has no higher or lower neighbor, return the closest neighbor twice
"""
function get_number_interpolation(numbers_data::Array, number::Number)
    #Find numbers being greater and lower than the current numb
    numbers_g=numbers_data[numbers_data.>=number]
    numbers_l=numbers_data[numbers_data.<=number]
    #Create numbers for interpolation
    number_int=Tuple()
    number_int[1]= isempty(numbers_l) ? minimum(numbers_g) : maximum(numbers_l)
    number_int[2]= isempty(numbers_g) ? maximum(numbers_l) : minimum(numbers_g)
    return number_int
end

function get_interpolation(tab::DataFrame,col_val_ind::Tuple{Symbol,Number},colon_ind::Symbol)
    col_int=col_val_ind[1]
    val_int=col_val_ind[2]
    neighbors_int=get_number_interpolation(tab[col_int],val_int)
    if neighbors_int[1]==neighbors_int[2]
        return tab[(col_int,neighbors_int[1]),colon_ind][1]
    else
        #interpolation
        res_1=tab[(col_int,neighbors_int[1]),colon_ind]
        res_2=tab[(col_int,neighbors_int[2]),colon_ind]
        return res_1+(res_2-res_1)*(val_int-neighbors_int[1])/(neighbors_int[2]-neighbors_int[1])
    end
end
=#
