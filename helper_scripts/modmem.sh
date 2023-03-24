
# little helper, not for commit #

target_path=$PWD
echo $target_path

mon="01"


for pbsfile in $target_path/$mon/bias_corr_*.pbs; do
    
    echo " file $pbsfile " 

    sed -i "s+mem=200GB+mem=XX_GB+g" $pbsfile  
    # sed -i "s+casper+regular+g" $pbsfile
    # sed -i "s+mem=200GB+mem=100GB+g" $target_path/01/bias_corr_*.pbs  # dont forget 01 dir :)
    # sed -i "s+casper+regular+g" $target_path/01/bias_corr_*.pbs


done
