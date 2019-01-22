# This file exemplifies the workflow from data input to optimization result generation

include(normpath(joinpath(dirname(@__FILE__),"..","src","ClustForOpt_priv_development.jl")))

## LOAD DATA ##
state="GER_1" # or "GER_18" or "CA_1" or "TX_1"
# laod ts-data
ts_input_data, = load_timeseries_data("CEP", state; K=365, T=24) #CEP
# load cep-data
cep_data = load_cep_data(state)

## CLUSTERING ##
# run aggregation with kmeans
ts_clust_data = run_clust(ts_input_data;method="kmeans",representation="centroid",n_init=1000,n_clust=5) # default k-means make sure that n_init is high enough otherwise the results could be crap and drive you crazy

# run aggregation with kmeans and have periods segmented
ts_seg_data = run_clust(ts_input_data;method="kmeans",representation="centroid",n_init=1000,n_clust=5, n_seg=4) # default k-means make sure that n_init is high enough otherwise the results could be crap and drive you crazy

# run no aggregation just get ts_full_data
ts_full_data = run_clust(ts_input_data;method="kmeans",representation="centroid",n_init=1,n_clust=365) # default k-means

## OPTIMIZATION EXAMPLES##
# select solver
solver=GurobiSolver(OutputFlag=0)

# tweak the CO2 level
co2_result = run_opt(ts_clust_data.best_results,cep_data;solver=solver,descriptor="co2",co2_limit=1000) #generally values between 1250 and 10 are interesting

# Include a Slack-Variable
slack_result = run_opt(ts_clust_data.best_results,cep_data;solver=solver,descriptor="slack",lost_el_load_cost=1e6, lost_CO2_emission_cost=700)


# Include existing infrastructure at no COST
ex_result = run_opt(ts_clust_data.best_results,cep_data;solver=solver,descriptor="ex",existing_infrastructure=true)

# Intraday storage (just within each period, same storage level at beginning and end)
simplestor_result = run_opt(ts_clust_data.best_results,cep_data;solver=solver,descriptor="simple storage",storage="simple")

# Interday storage (within each period & between the periods)
#TODO move k_ids
seasonalstor_result = run_opt(ts_clust_data.best_results,cep_data;solver=solver,descriptor="seasonal storage",storage="seasonal",k_ids=ts_clust_data.best_ids)

# Transmission
transmission_result = run_opt(ts_clust_data.best_results,cep_data;solver=solver,descriptor="transmission",transmission=true)

# Segmentation
seg_result = run_opt(ts_seg_data.best_results,cep_data;solver=solver,descriptor="segmentation")

# Desing with clusered data and operation with ts_full_data
# First solve the clustered case
design_result = run_opt(ts_clust_data.best_results,cep_data;solver=solver,descriptor="design&operation", co2_limit=50)

#capacity_factors
design_variables=get_cep_design_variables(design_result, capacity_factors=Dict{String,Number}("pv"=>1.2, "wind"=>1.0))

# Use the design variable results for the operational run
operation_result = run_opt(ts_full_data.best_results,cep_data,design_result.opt_config,design_variables;solver=solver,lost_el_load_cost=1e6,lost_CO2_emission_cost=700)
