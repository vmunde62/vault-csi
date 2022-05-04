if [ $clusterName = cluster1 ];then
values_file='c1values.yaml';
elif [ $clusterName = cluster2 ];then
values_file='c2values.yaml';
elif [ $clusterName = cluster3 ];then
values_file='c3values.yaml';
fi

echo $values_file