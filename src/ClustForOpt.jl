# Holger Teichgraeber, 2017

 ######################
 # ClustForOpt
 # Analyzing clustering techniques as input for energy systems optimization
 #
 #####################
 #TODO other way of including module
module ClustForOpt

  using Reexport
  using Distances
  using Clustering
  using JLD2
  using FileIO
  #TODO Update TimeWarp
  #using TimeWarp
  using Statistics
  using LinearAlgebra
  using CSV
  using JuMP
  using Clp
  using Gurobi
  @reexport using DataFrames

   #TODO how to make PyPlot, PyCall, and TimeWarp optional? -> only import when needed

   export run_opt,
          run_clust,
          get_sup_kw_args,
          InputData,
          FullInputData,
          ClustData,
          ClustDataMerged,
          ClustResultAll,
          ClustResultBest,
          SimpleExtremeValueDescr,
          OptDataCEP,
          OptVariable,
          OptResult,
          Scenario,
          get_EUR_to_USD,
          load_input_data,
          plot_clusters,
          subplot_clusters,
          z_normalize,
          undo_z_normalize,
          sakoe_chiba_band,
          kmedoids_exact,
          plot_k_rev,
          plot_k_rev_subplot,
          plot_SSE_rev,
          sort_centers,
          calc_SSE,
          find_medoids,
          resize_medoids,
          load_timeseries_data,
          load_cep_data,
          get_cep_variable_value,
          get_cep_variable_set,
          get_cep_slack_variables,
          get_cep_design_variables,
          get_total_demand


  include(joinpath("utils","datastructs.jl"))
  include(joinpath("utils","utils.jl"))
  include(joinpath("utils","load_data.jl"))
  include(joinpath("optim_problems","run_opt.jl"))
  include(joinpath("optim_problems","opt_cep.jl"))
  include(joinpath("clustering","run_clust.jl"))
  include(joinpath("clustering","exact_kmedoids.jl"))
  include(joinpath("clustering","extreme_vals.jl"))
  include(joinpath("clustering","attribute_weighting.jl"))
  include(joinpath("clustering","intraperiod_segmentation.jl"))

end # module ClustForOpt
