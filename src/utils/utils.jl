
"""
function get_EUR_to_USD(region::String)

  convert Euro to US dollars
  introduced because the clusters generated by the python script are in EUR for GER
"""
function get_EUR_to_USD(region::String)
   if region =="GER"
     ret = 1.109729
   else
     ret =1
   end
   return ret
end


  """
function sort_centers(centers::Array,weights::Array)

  centers: hours x days e.g.[24x9]
  weights: days [e.g. 9], unsorted
   sorts the centers by weights from largest to smallest
  """
function sort_centers(centers::Array,
                      weights::Array
                      )
  i_w = sortperm(-weights)   # large to small (-)
  weights_sorted = weights[i_w]
  centers_sorted = centers[:,i_w]
  return centers_sorted, weights_sorted
end # function

"""
function z_normalize(data::ClustData;scope="full")
scope: "full", "sequence", "hourly"
"""
function z_normalize(data::ClustData;
                    scope="full"
                    )
 data_norm = Dict{String,Array}()
 mean= Dict{String,Array}()
 sdv= Dict{String,Array}()
 for (k,v) in data.data
   data_norm[k],mean[k],sdv[k] = z_normalize(v,scope=scope)
 end
 return ClustData(data.region,data.K,data.T,data_norm,data.weights;mean=mean,sdv=sdv)
end

"""
function z_normalize(data::Array;scope="full")

z-normalize data with mean and sdv by hour

data: input format: (1st dimension: 24 hours, 2nd dimension: # of days)
scope: "full": one mean and sdv for the full data set; "hourly": univariate scaling: each hour is scaled seperately; "sequence": sequence based scaling
"""
function z_normalize(data::Array;
                    scope="full"
                    )
  if scope == "sequence"
    seq_mean = zeros(size(data)[2])
    seq_sdv = zeros(size(data)[2])
    data_norm = zeros(size(data))
    for i=1:size(data)[2]
      seq_mean[i] = mean(data[:,i])
      seq_sdv[i] = std(data[:,i])
      isnan(seq_sdv[i]) &&  (seq_sdv[i] =1)
        data_norm[:,i] = data[:,i] .- seq_mean[i]
      # handle edge case sdv=0
      if seq_sdv[i]!=0
        data_norm[:,i] = data_norm[:,i]./seq_sdv[i]
      end
    end
    return data_norm,seq_mean,seq_sdv
  elseif scope == "hourly"
    hourly_mean = zeros(size(data)[1])
    hourly_sdv = zeros(size(data)[1])
    data_norm = zeros(size(data))
    for i=1:size(data)[1]
      hourly_mean[i] = mean(data[i,:])
      hourly_sdv[i] = std(data[i,:])
      data_norm[i,:] = data[i,:] .- hourly_mean[i]
      # handle edge case sdv=0
      if hourly_sdv[i] !=0
        data_norm[i,:] = data_norm[i,:]./hourly_sdv[i]
      end
    end
    return data_norm, hourly_mean, hourly_sdv
  elseif scope == "full"
    hourly_mean = mean(data)*ones(size(data)[1])
    hourly_sdv = std(data)*ones(size(data)[1])
    # handle edge case sdv=0
    if hourly_sdv[1] != 0
      data_norm = (data.-hourly_mean[1])/hourly_sdv[1]
    else
      data_norm = (data.-hourly_mean[1])
    end
    return data_norm, hourly_mean, hourly_sdv #TODO change the output here to an immutable struct with three fields - use struct - "composite type"
  else
    @error("scope _ ",scope," _ not defined.")
  end
end # function z_normalize

"""
function undo_z_normalize(data_norm_merged::Array,mn::Dict{String,Array},sdv::Dict{String,Array};idx=[])

provide idx should usually be done as default within function call in order to enable sequence-based normalization, even though optional.
"""
function undo_z_normalize(data_norm_merged::Array,mn::Dict{String,Array},sdv::Dict{String,Array};idx=[])
  T = div(size(data_norm_merged)[1],length(keys(mn))) # number of time steps in one period. div() is integer division like in c++, yields integer (instead of float as in normal division)
  0 != rem(size(data_norm_merged)[1],length(keys(mn))) && @error("dimension mismatch") # rem() checks the remainder. If not zero, throw error.
  data_merged = zeros(size(data_norm_merged))
  i=0
  for (attr,mn_a) in mn
    i+=1
    data_merged[(1+T*(i-1)):(T*i),:]=undo_z_normalize(data_norm_merged[(1+T*(i-1)):(T*i),:],mn_a,sdv[attr];idx=idx)
  end
  return data_merged
end


"""
function undo_z_normalize(data_norm, mn, sdv; idx=[])

undo z-normalization data with mean and sdv by hour
normalized data: input format: (1st dimension: 24 hours, 2nd dimension: # of days)
hourly_mean ; 24 hour vector with hourly means
hourly_sdv; 24 hour vector with hourly standard deviations
"""
function undo_z_normalize(data_norm::Array, mn::Array, sdv::Array; idx=[])
  if size(data_norm,1) == size(mn,1) # hourly and full- even if idx is provided, doesn't matter if it is hourly
    data = data_norm .* sdv + mn * ones(size(data_norm)[2])'
    return data
  elseif !isempty(idx) && size(data_norm,2) == maximum(idx) # sequence based
    # we obtain mean and sdv for each day, but need mean and sdv for each centroid - take average mean and sdv for each cluster
    summed_mean = zeros(size(data_norm,2))
    summed_sdv = zeros(size(data_norm,2))
    for k=1:size(data_norm,2)
      mn_temp = mn[idx.==k]
      sdv_temp = sdv[idx.==k]
      summed_mean[k] = sum(mn_temp)/length(mn_temp)
      summed_sdv[k] = sum(sdv_temp)/length(sdv_temp)
    end
    data = data_norm * Diagonal(summed_sdv) +  ones(size(data_norm,1)) * summed_mean'
    return data
  elseif isempty(idx)
    @error("no idx provided in undo_z_normalize")
  end
end

"""
function sakoe_chiba_band(r::Int,l::Int)

calculates the minimum and maximum allowed indices for a lxl windowed matrix
for the sakoe chiba band (see Sakoe Chiba, 1978).
Input: radius r, such that |i(k)-j(k)| <= r
length l: dimension 2 of the matrix
"""
function sakoe_chiba_band(r::Int,l::Int)
  i2min = Int[]
  i2max = Int[]
  for i=1:l
    push!(i2min,max(1,i-r))
    push!(i2max,min(l,i+r))
  end
  return i2min, i2max
end

"""
function calc_SSE(data::Array,centers::Array,assignments::Array)

calculates Sum of Squared Errors between cluster representations and the data
"""
function calc_SSE(data::Array,centers::Array,assignments::Array)
  k=size(centers,2) # number of clusters
  n_periods =size(data,2)
  SSE_sum = zeros(k)
  for i=1:n_periods
    SSE_sum[assignments[i]] += sqeuclidean(data[:,i],centers[:,assignments[i]])
  end
  return sum(SSE_sum)
end # calc_SSE

"""
function calc_SSE(data::Array,centers::Array,assignments::Array)

calculates Sum of Squared Errors between cluster representations and the data
"""
function calc_SSE(data::Array,assignments::Array)
  centers=calc_centroids(data, assignments)
  k=size(centers,2) # number of clusters
  n_periods =size(data,2)
  SSE_sum = zeros(k)
  for i=1:n_periods
    SSE_sum[assignments[i]] += sqeuclidean(data[:,i],centers[:,assignments[i]])
  end
  return sum(SSE_sum)
end # calc_SSE

"""
function calc_centroids(data::Array,assignments::Array)

Given the data and cluster assignments, this function finds
the centroid of the respective clusters.
"""
function calc_centroids(data::Array,assignments::Array)
  K=maximum(assignments) #number of clusters
  n_per_period=size(data,1)
  n_periods =size(data,2)
  centroids=zeros(n_per_period,K)
  for k=1:K
    centroids[:,k]=sum(data[:,findall(assignments.==k)];dims=2)/length(findall(assignments.==k))
  end
  return centroids
end

"""
function calc_medoids(data::Array,assignments::Array)

Given the data and cluster assignments, this function finds
the medoids that are closest to the cluster center.
"""
function calc_medoids(data::Array,assignments::Array)
  K=maximum(assignments) #number of clusters
  n_per_period=size(data,1)
  n_periods =size(data,2)
  SSE=Float64[]
  for i=1:K
    push!(SSE,Inf)
  end
  centroids=calc_centroids(data,assignments)
  medoids=zeros(n_per_period,K)
  # iterate through all data points
  for i=1:n_periods
    d = sqeuclidean(data[:,i],centroids[:,assignments[i]])
    if d < SSE[assignments[i]] # if this data point is closer to centroid than the previously visited ones, then make this the medoid
      medoids[:,assignments[i]] = data[:,i]
      SSE[assignments[i]]=d
    end
  end
  return medoids
end

"""
function resize_medoids(data::Array,centers::Array,weights::Array,assignments::Array)

Takes in centers (typically medoids) and normalizes them such that for all clusters the average of the cluster is the same as the average of the respective original data that belongs to that cluster.

In order to use this method of the resize function, add assignments to the function call (e.g. clustids[5,1]).
"""
function resize_medoids(data::Array,centers::Array,weights::Array,assignments::Array)
    new_centers = zeros(centers)
    for k=1:size(centers)[2] # number of clusters
       is_in_k = assignments.==k
       n = sum(is_in_k)
       new_centers[:,k]=resize_medoids(reshape(data[:,is_in_k],:,n),reshape(centers[:,k] , : ,1),[1.0])# reshape is used for the side case with only one vector, so that resulting vector is 24x1 instead of 24-element
    end
    return new_centers
end


"""
function resize_medoids(data::Array,centers::Array,weights::Array)

This is the DEFAULT resize medoids function

Takes in centers (typically medoids) and normalizes them such that the yearly average of the clustered data is the same as the yearly average of the original data.
"""
function resize_medoids(data::Array,centers::Array,weights::Array)
    mu_data = sum(data)
    mu_clust = 0
    w_tot=sum(weights)
    for k=1:size(centers)[2]
      mu_clust += weights[k]/w_tot*sum(centers[:,k]) # weights[k]>=1
    end
    mu_clust *= size(data)[2]
    mu_data_mu_clust = mu_data/mu_clust
    new_centers = centers* mu_data_mu_clust
    return new_centers
end

"""
function resize_medoids(data::Array,centers::Array,weights::Array)

This is the DEFAULT resize medoids function

Takes in centers (typically medoids) and normalizes them such that the yearly average of the clustered data is the same as the yearly average of the original data.
"""
function resize_medoids(data::ClustData,centers::Array,weights::Array)
    (data.T * length(keys(data.data)) != size(centers,1) ) && @error("dimension missmatch between full input data and centers")
    centers_res = zeros(size(centers))
    # go through the attributes within data
    i=0
    for (k,v) in data.data
      i+=1
      # calculate resized centers for each attribute
      centers_res[(1+data.T*(i-1)):(data.T*i),:] = resize_medoids(v,centers[(1+data.T*(i-1)):(data.T*i),:],weights)
    end
    return centers_res
end


"""
    function calc_weights(clustids::Array{Int}, n_clust::Int)

Calculates weights for clusters, based on clustids that are assigned to a certain cluster. The weights are absolute:    weights[i]>=1
"""
function calc_weights(clustids::Array{Int}, n_clust::Int)
    weights = zeros(n_clust)
    for j=1:length(clustids)
        weights[clustids[j]] +=1
    end
    return weights
end

"""
function find_val_in_df(df::DataFrame,column_of_reference::Symbol,reference::String,value_to_return::Symbol)
  Take DataFrame(df) Look in Column (column_of_reference) for the reference value (reference) and return in same row the value in column (value_to_return)
"""
function find_val_in_df(df::DataFrame,
                    column_of_reference::Symbol,
                    reference::String,
                    value_to_return::Symbol
                    )
    return df[findfirst(df[column_of_reference].==reference),value_to_return]
end

"""
function find_val_in_df(df::DataFrame,column_of_reference::Symbol,reference::String,value_to_return::String)
  Take DataFrame(df) Look in Column (column_of_reference) for the reference value (reference) and return corresponding value in column (value_to_return)
"""
function find_val_in_df(df::DataFrame,
                    column_of_reference::Symbol,
                    reference::String,
                    value_to_return::String
                    )
    return find_val_in_df(df,column_of_reference,reference,Symbol(value_to_return))
end

"""
function find_val_in_df(df::DataFrame,column_of_reference1::Symbol,reference1::String, column_of_reference2::Symbol,reference2::String, value_to_return::Symbol)
  Take DataFrame(df) Look in Column1 and Column2 (column_of_reference1 and 2) for the reference value (reference1 and 2) and return in same row where both values match in column (value_to_return)
"""
function find_val_in_df(df::DataFrame,
                        column_of_reference1::Symbol,
                        reference1::String,
                        column_of_reference2::Symbol,
                        reference2::String,
                        value_to_return::Symbol)
    return df[findfirst((df[column_of_reference1].==reference1).+(df[column_of_reference2].==reference2).==2),value_to_return]
end

"""
function find_val_in_df(df::DataFrame,column_of_reference1::Symbol,reference1::String, column_of_reference2::Symbol,reference2::String, value_to_return::String)
  Take DataFrame(df) Look in Column1 and Column2 (column_of_reference1 and 2) for the reference value (reference1 and 2) and return in same row where both values match in column (value_to_return)
"""
function find_val_in_df(df::DataFrame,
                        column_of_reference1::Symbol,
                        reference1::String,
                        column_of_reference2::Symbol,
                        reference2::String,
                        value_to_return::String)
    return find_val_in_df(df, column_of_reference1, reference1, column_of_reference2, reference2, Symbol(value_to_return))
end

"""
function find_cost_in_df(costs::DataFrame,nodes::DataFrame,tech::String,node::String,impact_to_return::String)
  Take DataFrame(df) Look in Column (column_of_reference) for the reference value (reference) and return corresponding value in column (value_to_return)
"""
function find_cost_in_df(costs::DataFrame,
                    nodes::DataFrame,
                    tech::String,
                    node::String,
                    impact_to_return::String
                    )
    if find_val_in_df(costs,:tech,tech,:region)=="all"
      return find_val_in_df(costs,:tech,tech,Symbol(impact_to_return))
    else
      return find_val_in_df(costs,:tech,tech,:region,find_val_in_df(nodes,:nodes,node,:region),Symbol(impact_to_return))
    end
end

"""
function find_line_eff_in_df(lines::DataFrame,techs::DataFrame,line::String,tech::String,eff::Symbol)
  Take DataFrame(lines and techs) look for the length of this line and the efficiency of this line (eff_in or eff_out) per km and calculate total efficiency
"""
function find_line_eff_in_df(lines::DataFrame,
                            techs::DataFrame,
                            line::String,
                            tech::String,
                            eff::Symbol)
    return (1-find_val_in_df(lines,:lines,line,:length)*(1-find_val_in_df(techs, :tech, tech, eff)))
end

"""
function map_set_in_df(df::DataFrame,column_of_reference::Symbol,reference::String,set_to_return::Symbol)
  Take DataFrame(df) Look in Column (column_of_reference) for all cases that match the reference value (reference) and return the corresponding sets in Column (set_to_return)
"""
function map_set_in_df(df::DataFrame,
                    column_of_reference::Symbol,
                    reference::String,
                    set_to_return::Symbol
                    )
    return df[df[column_of_reference].==reference,set_to_return]
end


"""
function get_cep_variable_value(variable::OptVariable,index_set::Array)
  Get the variable data from the specific Scenario by indicating the var_name e.g. "COST" and the index_set like [:;"EUR";"pv"]
"""
function get_cep_variable_value(variable::OptVariable,
                                index_set::Array
                                )
    index_num=[]
    for i in  1:length(index_set)
        if index_set[i]==Colon()
            push!(index_num,Colon())
        elseif typeof(index_set[i])==Int64 || typeof(index_set[i])==UnitRange{Int64}
            push!(index_num,index_set[i])
        else
            new_index_num=findfirst(variable.axes[i].==index_set[i])
            if new_index_num==[]
                throw(@error("$(index_set[i]) not in indexset #$i of Variable $var_name"))
            else
                push!(index_num,new_index_num)
            end
        end
    end
    return getindex(variable.data,Tuple(index_num)...)
end

"""
function get_cep_variable_value(scenario::Scenario,var_name::String,index_set::Array)
  Get the variable data from the specific Scenario by indicating the var_name e.g. "COST" and the index_set like [:;"EUR";"pv"]
"""
function get_cep_variable_value(scenario::Scenario,
                                var_name::String,
                                index_set::Array
                                )
    return get_cep_variable_value(scenario.opt_res.variables[var_name], index_set)
end

"""
function get_cep_variable_set(variable::OptVariable,num_index_set::Int)
  Get the variable set from the specific variable and the num_index_set like 1
"""
function get_cep_variable_set(variable::OptVariable,
                              num_index_set::Int
                              )
    return variable.axes[num_index_set]
end

"""
function get_cep_variable_set(scenario::Scenario,var_name::String,num_index_set::Int)
  Get the variable set from the specific Scenario by indicating the var_name e.g. "COST" and the num_index_set like 1
"""
function get_cep_variable_set(scenario::Scenario,
                              var_name::String,
                              num_index_set::Int
                              )
    return  get_cep_variable_set(scenario.opt_res.variables[var_name], num_index_set)
end

"""
function get_cep_variable_set(scenario::Scenario,var_name::String,num_index_set::Int)
  Get the variable set from the specific Scenario by indicating the var_name e.g. "COST" and the num_index_set like 1
"""
function get_cep_variable_set(scenario::Scenario,
                              var_name::String,
                              num_index_set::Int
                              )
    return  get_cep_variable_set(scenario.opt_res.variables[var_name], num_index_set)
end

"""
function get_cep_design_variables(opt_result::OptResult; capacity_factors::Dict{String,Number}=Dict{String,Number}())
  Returns all design variables in this opt_result mathing the type "dv"
  Additionally you can add capacity factors, which scale the design variables by multiplying it with the value in the Dict
"""
function get_cep_design_variables(opt_result::OptResult; capacity_factors::Dict{String,Number}=Dict{String,Number}())
  design_variables=get_cep_variables(opt_result, "dv")
  techs=design_variables["CAP"].axes[findfirst(design_variables["CAP"].axes_names.=="tech")]
  for (k,v) in capacity_factors
      if k in techs && findfirst(design_variables["CAP"].axes_names.=="tech")==1
          design_variables["CAP"].data[findfirst(techs.==k),:,:].*=v
      else
          @warn("key $k not found in first row of CAP")
      end
  end
  return design_variables
end

"""
function get_cep_slack_variables(opt_result::OptResult)
  Returns all slack variables in this opt_result mathing the type "sv"
"""
function get_cep_slack_variables(opt_result::OptResult)
  return get_cep_variables(opt_result, "sv")
end

"""
function get_cep_variables(opt_result::OptResult, variable_type::String)
  Returns all variables which types match the String of variable_type
"""
function get_cep_variables(opt_result::OptResult, variable_type::String)
  variables=Dict{String,OptVariable}()
  for (key,val) in opt_result.variables
      if val.type==variable_type
          variables[key]=val
      end
  end
  if variables==Dict{String,OptVariable}()
      throw(@error("$variable_type-Variable not provided in $(opt_result.descriptor)"))
  else
      return variables
  end
end

"""
function set_opt_config_cep(opt_data::OptDataCEP; kwargs...)
  kwargs can be whatever you need to run the run_opt
  it can hold
    fixed_design_variables: Dictionary{String,OptVariable}
    transmission: true or false
    generation: true or false
    storage_p: true or false
    storage_e: true or false
    existing_infrastructure: true or false
    descritor: a String like "kmeans-10-co2-500" to describe this CEP-Model
    first_stage_vars: a Dictionary containing the OptVariables from a previous run
  The function also checks if the provided data matches your kwargs options (e.g. it let's you know if you asked for transmission, but you have no tech with it in your data)
  Returning Dictionary with the variables as entries
"""
function set_opt_config_cep(opt_data::OptDataCEP
                            ;kwargs...)
  # Create new Dictionary and set possible unique categories to false to later check wrong setting
  config=Dict{String,Any}("transmission"=>false, "storage_e"=>false, "storage_p"=>false, "generation"=>false)
  # Check the existence of the categ (like generation or storage - see techs.csv) and write it into Dictionary
  for categ in unique(opt_data.techs[:categ])
    config[categ]=true
  end
  # Loop through the kwargs and write them into Dictionary
  for kwarg in kwargs
    # Check for false combination
    if String(kwarg[1]) in keys(config)
      if config[String(kwarg[1])]==false && kwarg[2]
        throw(@error("Option "*String(kwarg[1])*" cannot be selected with input data provided for "*opt_data.region))
      end
    end
    config[String(kwarg[1])]=kwarg[2]
  end

  # Return Directory with the information
  return config
end

"""
function set_opt_config_cep!(config::Dict{String,Any}; kwargs...)
  add or replace items to an existing config
  fixed_design_variables: Dict{String,OptVariable}
  slack_cost: Number
"""
function set_opt_config_cep!(config::Dict{String,Any}
                            ;kwargs...)
  # Loop through the kwargs and add them to Dictionary
  for kwarg in kwargs
    config[String(kwarg[1])]=kwarg[2]
  end

  # Return Directory with the information
  return config
end

"""
function check_opt_data_cep(opt_data::OptDataCEP)
  Check the consistency of the data
"""
function check_opt_data_cep(opt_data::OptDataCEP)
  # Check tech
  for tech in opt_data.techs[:tech]
    if !(in(tech,opt_data.cap_costs[:tech]))
      throw(@error("Technology "*tech*" not included in Cap_cost-Data"))
    elseif !(in(tech,opt_data.var_costs[:tech]))
      throw(@error("Technology "*tech*" not included in Var_cost-Data"))
    elseif !(in(tech,opt_data.fix_costs[:tech]))
      throw(@error("Technology "*tech*" not included in Fix_cost-Data"))
    elseif !(in(Symbol(tech),names(opt_data.nodes)))
      throw(@error("Technology "*tech*" not included in nodes-Data"))
    end
  end
  # Check lines
  # Only when Data provided
  if opt_data.lines!=DataFrame()
    # Check existence of start and end node
    for node in opt_data.lines[:node_end]
      if !(in(node,opt_data.nodes[:nodes]))
        throw(@error("Node "*node*" set as ending node, but not included in nodes-Data"))
      end
    end
  end
end


 """
 set_clust_config(;kwargs...)
     Add kwargs to a new Dictionary with the variables as entries
 """
function set_clust_config(;kwargs...)
  #Create new Dictionary
  config=Dict{String,Any}()
  # Loop through the kwargs and write them into Dictionary
  for kwarg in kwargs
    config[String(kwarg[1])]=kwarg[2]
  end
  # Return Directory with the information of kwargs
  return config
end

"""
function get_total_demand(cep::OptModelCEP, ts_data::ClustData)
  Return the total demand by multiplying demand with deltas and weights for the OptModel CEP
"""
function get_total_demand(cep::OptModelCEP,
                          ts_data::ClustData)
  ## DATA ##
  set=cep.set
  #ts          Dict( tech-node ): t x k
  ts=ts_data.data
  #ts_weights: k - weight of each period:
  ts_weights=ts_data.weights
  #ts_deltas:  t x k - Δt of each segment x period
  ts_deltas=ts_data.deltas
  total_demand=0
  for node in set["nodes"]
    for t in set["time_T"]
      for k in set["time_K"]
        total_demand+=ts["el_demand-"*node][t,k]*ts_deltas[t,k]*ts_weights[k]
      end
    end
  end

  return total_demand
end

"""
function get_cost_series(cep_data::OptDataCEP,clust_res::ClustResultBest, opt_res::OptResult)
  Return an array for the time series of costs in all the impact dimensions and the set of impacts
"""
function get_cost_series(nodes::DataFrame,
                        var_costs::DataFrame,
                       clust_res::ClustResultBest,
                       set::Dict{String,Array},
                       variables::Dict{String,OptVariable})
  ## DATA ##
  # ts_ids:   n_clustered periods
  ts_ids=clust_res.best_ids
  #ts_weights: k - weight of each period:
  ts_weights=clust_res.best_results.weights
  #ts_deltas:  t x k - Δt of each segment x period
  ts_deltas=clust_res.best_results.deltas

  #emision at each period-step
  cost_ts=zeros(length(ts_ids)+1,length(set["impact"]))
  #At the beginning yearly fixed and cap costs
  cost_ts[1,:]=sum(get_cep_variable_value(variables["COST"],["cap_fix",:,:]),dims=2)

  for n in 1:length(ts_ids)
        var_cost=zeros(length(set["impact"]))
        i=1
        for impact in set["impact"]
          for tech in set["tech"]
            for node in set["nodes"]
              var_cost[i] += find_cost_in_df(var_costs,nodes,tech,node,impact)*  sum(get_cep_variable_value(variables["GEN"],["el",tech,:,ts_ids[n],node])' * ts_deltas[:,ts_ids[n]])
            end
          end
          i+=1
        end
        cost_ts[n+1,:]=cost_ts[n,:]+var_cost
  end
  return cost_ts, set["impact"]
end

"""
function get_cost_series(cep_data::OptDataCEP,scenario::Scenario)
  Return an array for the time series of costs in all the impact dimensions and the set of impacts
"""
function get_cost_series(cep_data::OptDataCEP,scenario::Scenario)
  return get_cost_series(cep_data.nodes,cep_data.var_costs,scenario.clust_res, scenario.opt_res.model_set,scenario.opt_res.variables)
end
