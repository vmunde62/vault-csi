if [ ${params.clusterName} = cluster1 ];then
values_file='c1values.yaml';
elif [ ${params.clusterName} = cluster2 ];then
values_file='c2values.yaml';
elif [ ${params.clusterName} = cluster3 ];then
values_file='c3values.yaml';
fi

echo $values_file