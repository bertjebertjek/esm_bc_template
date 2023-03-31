
# little helper, not for commit #
# modify the job submission scripts from Abby to my workflow.


target_path=$PWD
echo $target_path




for pbsfile in $target_path/bias_corr_*.pbs; do
    
    # echo " file $(basename $pbsfile )" 

    yr=$(cut -c 11-14<<< $(basename $pbsfile ))
    # echo $yr

    sed -i "s+-N bc+-N bc01-$yr+g" $pbsfile
    sed -i "s+mem=100GB+mem=XX_GB+g" $pbsfile
    sed -i "s+regular+casper+g" $pbsfile

    # sed -i "s+mem=200GB+mem=100GB+g" $target_path/01/bias_corr_*.pbs  # dont forget 01 dir :)
    # sed -i "s+casper+regular+g" $target_path/01/bias_corr_*.pbs


done
