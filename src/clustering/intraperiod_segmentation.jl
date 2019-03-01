
function intraperiod_segmentation(data_merged::ClustDataMerged;
                n_seg::Int=24,
                iterations::Int=300,
                norm_scope::String="full")
  #For easy access
  K=data_merged.K
  T=data_merged.T
  data=data_merged.data
  #Prepare matrices
  data_seg=zeros(n_seg*length(data_merged.data_type),K)
  deltas_seg=zeros(n_seg,K)
  #Loop over each period
  for k in 1:K
    #Take single period and reshape it to have t (1:T) as columns and types (solar-germany, wind-germany...) as rows
    period=permutedims(reshape(data[:,k],(T,length(data_merged.data_type))))
    #Run hierarchical clustering
    centers,weights,clustids,cost,iter=run_clust_segmentation(period;n_seg=n_seg,iterations=iterations,norm_scope=norm_scope)
    #Assign values back to matrices to match types*n_seg x K
    data_seg[:,k]=reshape(permutedims(centers),(size(data_seg,1),1))
    #Assign values back to matrices to match n_seg x K
    deltas_seg[:,k]=weights
  end
  return ClustDataMerged(data_merged.region,data_merged.years,K,n_seg,data_seg,data_merged.data_type,data_merged.weights,data_merged.k_ids;deltas=deltas_seg,)
end

function run_clust_segmentation(period::Array{Float64,2};
                n_seg::Int=24,
                iterations::Int=300,
                norm_scope::String="full")
  norm_period, typely_mean, typely_sdv=z_normalize(period;scope=norm_scope)
  #x,weights,clustids,x,iter= run_clust_hierarchical(norm_period,n_seg,iterations)
  data=norm_period
  clustids=run_clust_hierarchical_partitional(data::Array, n_seg::Int64)
  weights = calc_weights(clustids,n_seg)


  centers_norm = calc_centroids(norm_period,clustids)
  cost = calc_SSE(norm_period,centers_norm,clustids)
  centers = undo_z_normalize(centers_norm,typely_mean,typely_sdv;idx=clustids)
  return centers,weights,clustids,cost,1
end

function get_clustids(ends::Array{Int64,1})
  clustids=collect(1:size(data,2))
  j=1
  for i in 1:size(data,2)
    clustids[i]=j
    if i in ends
      j+=1
    end
  end
  return clustids
end

"""
function run_clust_hierarchical_partitional(data::Array, n_seg::Int64)
  Usees provided data and number of segments to aggregate them together

Beginning implementation Bahl
function run_clust_hierarchical_partitional(data::Array,
                                            n_seg::Int64)
  ends_all=LHCoptim((size(data,2)-1),(n_seg-1),1000)[1]
  distance_runs=[]
  clustids_runs=[]
  for e in 1:size(ends_all,1)
    ends=ends_all[e,:]
    for n in 1:100
      global clustids=get_clustids(ends)
      #Calculate mean of data: The number of columns is kept the same, mean is calculated for aggregated columns and the same in all with same clustid
      global means_data=get_mean_data(data,clustids)
      ends_prev=ends
      for i in 1:length(ends)
        #
        if sum(abs.(data[:,ends[i]]-means_data[:,ends[i]]))>sum(abs.(data[:,ends[i]]-means_data[:,min(ends[i]+1,size(data,2))]))
          global ends[i]+=1
          #break
        end
      end
      if ends_prev==ends
        #break
      end
    end
    distance=sum(pairwise(SqEuclidean(),means_data,data))
    push!(distance_runs,distance)
    push!(clustids_runs,clustids)
  end
  #return clustids_runs[findfirst(distance_runs.==minimum(distance_runs))]
  return clustids_runs, distance_runs
end
"""

"""
function run_clust_hierarchical_partitional(data::Array, n_seg::Int64)
  Usees provided data and number of segments to aggregate them together
"""
function run_clust_hierarchical_partitional(data::Array,
                                            n_seg::Int64)
  _dist= SqEuclidean()
  #Assign each timeperiod it's own cluster
  clustids=collect(1:size(data,2))
  #While aggregation not finished, aggregate
  #Calculate the sq distance
  d_mat=pairwise(_dist,data)
  while clustids[end]>n_seg
    #Calculate mean of data: The number of columns is kept the same, mean is calculated for aggregated columns and the same in all with same clustid
    #Initially no index is selected and distance is Inf
    NNnext=0
    NNdist=Inf
    # loop through the sq distance matrix to check:
    for i=1:(clustids[end]-1)
      # if the distance between this index [i] and it's neighbor [i+1] is lower than the minimum found so far
       #distance=sum(d_mat[findall(clustids.==i),findall(clustids.==i+1)])
      clustids_test=deepcopy(clustids)
      merge_clustids!(clustids_test,findlast(clustids.==i))
      distance=calc_SSE(data,clustids_test)
      #println(distance)
      if distance < NNdist
        #Save this index and the distance
        NNnext=findlast(clustids.==i)
        NNdist=distance
      end
    end
    # Aggregate the clustids that were closest to each other
    merge_clustids!(clustids,NNnext)
  end
  return clustids
end

"""
function merge_clustids!(clustids::Array{Int64,1},index::Int64)
Calculate the new clustids by merging the cluster of the index provided with the cluster of index+1
"""
function merge_clustids!(clustids::Array{Int64,1},index::Int64)
  clustids[index+1]=clustids[index]
  clustids[index+2:end].-=1
end

"""
function get_mean_data(data::Array, clustids::Array{Int64,1})
Calculate mean of data: The number of columns is kept the same, mean is calculated for aggregated columns and the same in all with same clustid
"""
function get_mean_data(data::Array,
                    clustids::Array{Int64,1})
  mean_data=zeros(size(data))
  for i in 1:size(data,2)
    mean_data[:,i]=mean(data[:,findall(clustids.==clustids[i])], dims=2)
  end
  return mean_data
end
