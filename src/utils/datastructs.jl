### Data structures ###
abstract type InputData end
abstract type TSData <:InputData end
abstract type OptData <: InputData end
abstract type ClustResult end

"FullInputData"
struct FullInputData <: TSData
 region::String
 years::Array{Int64}
 N::Int
 data::Dict{String,Array}
end

"ClustData \n weights: this is the absolute weight. E.g. for a year of 365 days, sum(weights)=365"
struct ClustData <: TSData
 region::String
 years::Array{Int64}
 K::Int
 T::Int
 data::Dict{String,Array}
 weights::Array{Float64}
 mean::Dict{String,Array}
 sdv::Dict{String,Array}
 deltas::Array{Float64,2}
 k_ids::Array{Int64}
end

"ClustDataMerged"
struct ClustDataMerged <: TSData
 region::String
 years::Array{Int64}
 K::Int
 T::Int
 data::Array
 data_type::Array{String}
 weights::Array{Float64}
 mean::Dict{String,Array}
 sdv::Dict{String,Array}
 deltas::Array{Float64,2}
 k_ids::Array{Int64}
end

"ClustResultAll"
struct ClustResultAll <: ClustResult
 best_results::ClustData
 best_ids::Array{Int,1}
 best_cost::Float64
 data_type::Array{String}
 clust_config::Dict{String,Any}
 centers::Array{Array{Float64},1}
 weights::Array{Array{Float64},1}
 clustids::Array{Array{Int,1},1}
 cost::Array{Float64,1}
 iter::Array{Int,1}
end

# TODO: not used yet, but maybe best to implement this one later for users who just want to use clustering but do not care about the locally converged solutions
"ClustResultBest"
struct ClustResultBest <: ClustResult
 best_results::ClustData
 best_ids::Array{Int,1}
 best_cost::Float64
 data_type::Array{String}
 clust_config::Dict{String,Any}
end

"ClustResultSimple"
struct ClustResultSimple <: ClustResult
 best_results::ClustData
 #TODO: clust_data::ClustData
 clust_config::Dict{String,Any}
end

"SimpleExtremeValueDescr"
struct SimpleExtremeValueDescr
   data_type::String
   extremum::String
   peak_def::String
   periods::Int64
   "Replace default constructor to only allow certain entries"
   function SimpleExtremeValueDescr(data_type::String,
                                    extremum::String,
                                    peak_def::String,
                                    periods::Int64)
       # only allow certain entries
       if !(extremum in ["min","max"])
         @error("extremum - "*extremum*" - not defined")
       elseif !(peak_def in ["absolute","integral"])
         @error("peak_def - "*peak_def*" - not defined")
       end
       new(data_type,extremum,peak_def,periods)
   end
end

"""
    SimpleExtremeValueDescr(data_type::String, extremum::String, peak_def::String)
"""
function SimpleExtremeValueDescr(data_type::String,
                                 extremum::String,
                                 peak_def::String)
   return SimpleExtremeValueDescr(data_type, extremum, peak_def, 1)
end

"""
     OptModelCEP
-model::JuMP.Model
-info::Array{String}
-set::Dict{String,Array}
"""
struct OptModelCEP
  model::JuMP.Model
  info::Array{String}
  set::Dict{String,Array}
end

"""
     OptVariable
-`data::Array` - includes the optimization variable output in  form of an array
-`axes_names::Array{String,1}`` - includes the names of the different axes and is equivalent to the sets in the optimization formulation
-`axes::Tuple` - includes the values of the different axes of the optimization variables
-`type::String` - defines the type of the variable being cv - cost variable - dv -design variable - ov - operating variable - sv - slack variable
"""
struct OptVariable{T,N,Ax,L<:NTuple{N,Dict}} <: AbstractArray{T,N}
    data::Array{T,N}
    axes::Ax
    lookup::L
    axes_names::Array{String,1}
    type::String
end

"OptResult"
struct OptResult
 status::Symbol
 objective::Float64
 variables::Dict{String,Any}
 sets::Dict{String,Array}
 opt_config::Dict{String,Any}
 opt_info::Dict{String,Any}
end

"""
     OptDataCEP{region::String, costs::OptVariable, techs::OptVariable, nodes::OptVariable, lines::OptVariabl} <: OptData
-`region::String`          name of state or region data belongs to
-`costs::OptVariable`    costs[tech,node,year,account,impact] - Number
-`techs::OptVariable`    techs[tech] - OptDataCEPTech
-`nodes::OptVariable`    nodes[tech, node] - OptDataCEPNode
-`lines::OptVarible`     lines[tech, line] - OptDataCEPLine
instead of USD you can also use your favorite currency like EUR
"""
struct OptDataCEP <: OptData
   region::String
   costs::OptVariable
   techs::OptVariable
   nodes::OptVariable
   lines::OptVariable
end

#struct LatLon() adapted from Package Geodesy.jl: Copyright (c) 2014-2016: Ted Steiner, Sean Garborg, Yeesian Ng, Andy Ferris, Andrew Smith

#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

#The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
"""
    LatLon(lat, lon)
    LatLon(lat = ϕ, lon = Θ)
Latitude and longitude co-ordinates. *Note:* assumes degrees not radians
"""
struct LatLon{T <: Number}
    lat::T
    lon::T
end
LatLon(lat::Number, lon::Number) = LatLon(promote(lat, lon)...)
LatLon(;lat=NaN,lon=NaN) = LatLon(lat,lon) # Constructor that is independent of storage order
Base.show(io::IO, ll::LatLon) = print(io, "LatLon(lat=$(ll.lat)°, lon=$(ll.lon)°)")
Base.isapprox(ll1::LatLon, ll2::LatLon; atol = 1e-6, kwargs...) = isapprox(ll1.lat, ll2.lat; atol = 180*atol/6.371e6, kwargs...) & isapprox(ll1.lon, ll2.lon; atol = 180*atol/6.371e6, kwargs...) # atol in metres (1μm)

"""
     OptDataCEPNode{value::Number,lat::Number,lon::Number} <: OptData
- `power_ex` existing capacity [MW]
- `power_lim` capacity limit [MW]
- `region`
- `latlon` hold geolocation information [°,°]
"""
struct OptDataCEPNode <: OptData
  power_ex::Number
  power_lim::Number
  region::String
  latlon::LatLon
end

"""
     OptDataCEPLine{node_start::String,node_end::String,reactance::Number,resistance::Number,power::Number,circuits::Int64,voltage::Number,length::Number} <: OptData
- `node_start` Node where line starts
- `node_end` Node where line ends
- `reactance`
- `resistance` [Ω]
- `power_ex`: existing power limit [MW]
- `power_lim`: limit power limit [MW]
- `circuits` [-]
- `voltage` [V]
- `length` [km]
- `eff` [-]
"""
struct OptDataCEPLine <: OptData
  node_start::String
  node_end::String
  reactance::Number
  resistance::Number
  power_ex::Number
  power_lim::Number
  circuits::Int64
  voltage::Number
  length::Number
  eff::Number
end
Base.show(io::IO, line::OptDataCEPLine) = print(io, "LatLon(lat=$(ll.lat)°, lon=$(ll.lon)°)")

"""
     OptDataCEPTech{categ::String,sector::String,eff::Number,time_series::String,lifetime::Number,financial_lifetime::Number,discount_rate::Number, annuityfactor::Number} <: OptData
- `categ`: the category of this technology (is it storage, transmission or generation)
- `sector`: sector of the technology (electricity or heat)
- `eff`: efficiency of this technologies conversion [-]
- `time_series`: time_series name for availability
- `lifetime`: product lifetime [a]
- `financial_lifetime`: financial time to break even [a]
- `discount_rate`: discount rate for technology [a]
- `annuityfactor`: annuity factor, important for cap-costs [-]
"""
struct OptDataCEPTech <: OptData
  categ::String
  sector::String
  eff::Number
  time_series::String
  lifetime::Number
  financial_lifetime::Number
  discount_rate::Number
  annuityfactor::Number
end

"""
  is_in(k::Symbol,table::DataFrame,alt_value::Any)
is Symbol `k` in `table`? Lookup value if true, return `alt_value` if false
"""
function is_in(k::Symbol,table::DataFrame,alt_value::Any)
  if k in names(table)
    return table[k][1]
  else
    @warn "$k not provided in $(repr(table))"
    return alt_value
  end
end


"""
     Scenario{descriptor::String,clust_res::ClustResult,opt_res::OptResult}
-`descriptor::String`
-`clust_res::ClustResult`
-`opt_res::OptResult`
"""
struct Scenario
 descriptor::String
 clust_res::ClustResult
 opt_res::OptResult
end


#### Constructors for data structures###

"""
    FullInputData(region::String,
                        N::Int;
                        el_price::Array=[],
                        el_demand::Array=[],
                        solar::Array=[],
                        wind::Array=[]
                        )
Constructor for FullInputData with optional data input
"""
function FullInputData(region::String,
                      N::Int;
                      el_price::Array=[],
                      el_demand::Array=[],
                      solar::Array=[],
                      wind::Array=[]
                      )
 dt = Dict{String,Array}()
 !isempty(el_price) && (dt["el_price"]=el_price)
 !isempty(el_demand) &&  (dt["el_demand"]=el_demand)
 !isempty(wind) && (dt["wind"]=wind)
 !isempty(solar) && (dt["solar"]=solar)
 # TODO: Check dimensionality of N and supplied input data streams Nx1
 isempty(dt) && @error("Need to provide at least one input data stream")
 FullInputData(region,N,dt)
end

"""
  ClustData(region::String,
                         years::Array{Int64,1},
                         K::Int,
                         T::Int;
                         el_price::Array=[],
                         el_demand::Array=[],
                         solar::Array=[],
                         wind::Array=[],
                         weights::Array{Float64}=ones(K),
                         mean::Dict{String,Array}=Dict{String,Array}(),
                         sdv::Dict{String,Array}=Dict{String,Array}(),
                         deltas::Array{Float64,2}=ones(T,K),
                         k_ids::Array{Int64,1}=collect(1:K)
                         )
constructor 1 for ClustData: provide data individually
"""
function ClustData(region::String,
                         years::Array{Int64,1},
                         K::Int,
                         T::Int;
                         el_price::Array=[],
                         el_demand::Array=[],
                         solar::Array=[],
                         wind::Array=[],
                         weights::Array{Float64}=ones(K),
                         mean::Dict{String,Array}=Dict{String,Array}(),
                         sdv::Dict{String,Array}=Dict{String,Array}(),
                         deltas::Array{Float64,2}=ones(T,K),
                         k_ids::Array{Int64,1}=collect(1:K)
                         )
   dt = Dict{String,Array}()
   mean_sdv_provided = ( !isempty(mean) && !isempty(sdv))
   if !isempty(el_price)
     dt["el_price"]=el_price
     if !mean_sdv_provided
       mean["el_price"]=zeros(T)
       sdv["el_price"]=ones(T)
     end
   end
   if !isempty(el_demand)
     dt["el_demand"]=el_demand
     if !mean_sdv_provided
       mean["el_demand"]=zeros(T)
       sdv["el_demand"]=ones(T)
     end
   end
   if !isempty(wind)
     dt["wind"]=wind
     if !mean_sdv_provided
       mean["wind"]=zeros(T)
       sdv["wind"]=ones(T)
     end
   end
   if !isempty(solar)
     dt["solar"]=solar
     if !mean_sdv_provided
       mean["solar"]=zeros(T)
       sdv["solar"]=ones(T)
     end
   end
   isempty(dt) && @error("Need to provide at least one input data stream")
   # TODO: Check dimensionality of K T and supplied input data streams KxT
   ClustData(region,years,K,T,dt,weights,mean,sdv,deltas,k_ids)
end

"""
    ClustData(region::String,
                      years::Array{Int64,1},
                      K::Int,
                      T::Int,
                      data::Dict{String,Array},
                      weights::Array{Float64},
                      deltas::Array{Float64,2},
                      k_ids::Array{Int64,1};
                      mean::Dict{String,Array}=Dict{String,Array}(),
                      sdv::Dict{String,Array}=Dict{String,Array}()
                      )
constructor 2 for ClustData: provide data as dict
"""
function ClustData(region::String,
                       years::Array{Int64,1},
                       K::Int,
                       T::Int,
                       data::Dict{String,Array},
                       weights::Array{Float64},
                       deltas::Array{Float64,2},
                       k_ids::Array{Int64,1};
                       mean::Dict{String,Array}=Dict{String,Array}(),
                       sdv::Dict{String,Array}=Dict{String,Array}()
                       )
 isempty(data) && @error("Need to provide at least one input data stream")
 mean_sdv_provided = ( !isempty(mean) && !isempty(sdv))
 if !mean_sdv_provided
   for (k,v) in data
     mean[k]=zeros(T)
     sdv[k]=ones(T)
   end
 end
 # TODO check if right keywords are used
 ClustData(region,years,K,T,data,weights,mean,sdv,deltas,k_ids)
end

"""
    ClustData(data::ClustDataMerged)
constructor 3: Convert ClustDataMerged to ClustData
"""
function ClustData(data::ClustDataMerged)
 data_dict=Dict{String,Array}()
 i=0
 for (k,v) in data.mean
   i+=1
   data_dict[k] = data.data[(1+data.T*(i-1)):(data.T*i),:]
 end
 ClustData(data.region,data.years,data.K,data.T,data_dict,data.weights,data.mean,data.sdv,data.deltas,data.k_ids)
end

"""
    ClustData(data::FullInputData,K,T)
constructor 4: Convert FullInputData to ClustData
"""
function ClustData(data::FullInputData,
                                 K::Int,
                                 T::Int)
  data_reshape = Dict{String,Array}()
  for (k,v) in data.data
     data_reshape[k] =  reshape(v,T,K)
  end
  return ClustData(data.region,data.years,K,T,data_reshape,ones(K),ones(T,K),collect(1:K))
end

"""
    ClustDataMerged(region::String,
                        years::Array{Int64,1},
                        K::Int,
                        T::Int,
                        data::Array,
                        data_type::Array{String},
                        weights::Array{Float64},
                        k_ids::Array{Int64,1};
                        mean::Dict{String,Array}=Dict{String,Array}(),
                        sdv::Dict{String,Array}=Dict{String,Array}()
                        )
constructor 1: construct ClustDataMerged
"""
function ClustDataMerged(region::String,
                       years::Array{Int64,1},
                       K::Int,
                       T::Int,
                       data::Array,
                       data_type::Array{String},
                       weights::Array{Float64},
                       k_ids::Array{Int64,1};
                       deltas::Array{Float64}=ones(T,K),
                       mean::Dict{String,Array}=Dict{String,Array}(),
                       sdv::Dict{String,Array}=Dict{String,Array}()
                       )
 mean_sdv_provided = ( !isempty(mean) && !isempty(sdv))
 if !mean_sdv_provided
   for dt in data_type
     mean[dt]=zeros(T)
     sdv[dt]=ones(T)
   end
 end
 ClustDataMerged(region,years,K,T,data,data_type,weights,mean,sdv,deltas,k_ids)
end

"""
    ClustDataMerged(data::ClustData)
constructor 2: convert ClustData into merged format
"""
function ClustDataMerged(data::ClustData)
 n_datasets = length(keys(data.data))
 data_merged= zeros(data.T*n_datasets,data.K)
 data_type=String[]
 i=0
 for (k,v) in data.data
   i+=1
   data_merged[(1+data.T*(i-1)):(data.T*i),:] = v
   push!(data_type,k)
 end
 if maximum(data.deltas)!=1
   throw(@error "You cannot recluster data with different Δt")
 end
 ClustDataMerged(data.region,data.years,data.K,data.T,data_merged,data_type,data.weights,data.mean,data.sdv,data.deltas,data.k_ids)
end
