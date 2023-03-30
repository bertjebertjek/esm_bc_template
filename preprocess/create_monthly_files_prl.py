#!/usr/bin/env python
# coding: utf-8


##############################################################################################################
#
#  Script to divide multi-annual netcdf files into 12 monthly files, so they can be bias corrected.
#
#  Modified by Bert Kruyt, original by Abby Smith, Ryan Currier(?), ...  (some original code left in comments)
#
#  Purpose: divide the input GCM files into 12 datasets, one for each month, with 15 days before and after as 
#           a 'buffer'. These can then be bias-corrected by month with code in github directory below.
#
#  Documentation: See README.md in parent dir or on github: https://github.com/bertjebertjek/esm_bc_template
#
#  Bert Kruyt, NCAR RAL, 2023
#
##############################################################################################################


import xarray as xr
import numpy as np
import pandas as pd
import matplotlib
import matplotlib.pyplot as plt
import os
import glob, time, psutil
import multiprocessing as mp
import itertools


######################################     USER SETTINGS    ############################################################

scenarios=['ssp370'] # ['historical', 'ssp585','ssp370']  # ['ssp585', 'ssp370'] # 
modLs=['CESM2'] #['NorESM2-MM'] #
#'CanESM5','CESM2','CMCC-CM2-SR5','MIROC-ES2L','MPI-M.MPI-ESM1-2-LR','NorESM2-MM',  'CNRM-ESM2-1'


# The raw GCM data, decompressed (!), yearly (input) :
dir_raw_decmp = '/glade/scratch/bkruyt/CMIP6/raw/'

# the directory to store the monthly files produced by this script (output):
dir_raw_month = '/glade/scratch/bkruyt/CMIP6/raw_month/'

# parallellize over the 12 months:
Nprocs=12

########################################################################################################################

print("\n"  )
print("Creating monthly GCM files for model(s)" , modLs, )
print(" for scenario(s)" , scenarios )
print("\n"  )


def month_func(month_idx): #, ds=ds):
    """ the function to create a monthly file from the entire dataset. To be called in parallel."""

    print("\n    ----- month ", month_idx, "------")

    month_grouped=ds['time'].dt.month
    month_grouped[month_grouped!=month_idx]=0   # if not the current month, set to zero
    idx=np.where(np.diff(month_grouped.values)!=0)[0]  # the (time) indices where the month changes

    for i in range(len(idx)):
        # print(i)
        month_grouped[idx[i]-(15*4)+1:idx[i]+1]=month_idx*np.ones(15*4) # previous time steps
        if i==0 and month_idx==1:
            month_grouped[idx[i]+1:idx[i]+(15*4)+1]=month_idx*np.ones(15*4) # forward time step
        elif i == len(idx)-1 and month_idx==12:
            print('executed')
            month_grouped=month_grouped # leave as is: dont go forward
        elif i < len(idx)-1:
            # try:  # originally whole try statement was commented out
            #     # month_grouped[ idx[i+1]+1 : idx[i+1]+16 ] = month_idx*np.ones(15)  # org
            #     month_grouped[ idx[i+1]+1 : idx[i+1]+(15*4)+1 ] = month_idx*np.ones(15*4)  # BK addition
            # except:
            #     month_grouped=month_grouped
            month_grouped[idx[i+1]+1:idx[i+1]+(15*4)+1]=month_idx*np.ones(15*4)  # original code. 

    dsGroup=ds.groupby(month_grouped).groups
    ds_month=ds.isel(time=dsGroup[month_idx])

    # validate:
    try:
        print("   ", ds_month.time.values[0].astype('datetime64[D]') ,  ds_month.time.values[-1].astype('datetime64[D]') )
    except: # if calendar is noleap the above will fail and we use:
        print("   ", ds_month.indexes['time'].to_datetimeindex().values.min().astype('datetime64[D]'), 
                     ds_month.indexes['time'].to_datetimeindex().values.max().astype('datetime64[D]'))

    # print mem usage:
    # Getting % usage of virtual_memory ( 3rd field) !!! This gives % of Node, not of mem allocated, so better use absolute amount below:
    # print('   * * *   RAM memory % used:', psutil.virtual_memory()[2], '   * * *   ')
    # Getting usage of virtual_memory in GB ( 4th field)
    print('   * * *   RAM Used (GB):', psutil.virtual_memory()[3]/1000000000, '   * * *   \n')

    # save the monthly file to disk:
    # !!! Note that the esm_bias_correction fortran code expects this time encoding, if it is changed here the output of the bias correction will have the wromg time stamp!!!!
    ds_month.to_netcdf(out_dir+modLs[z]+'_'+str(month_idx).zfill(2)+'.nc'  ,  encoding={'time':{'units':"days since 1900-01-01"}}) 
    # "hours since 1950-01-01T12:00:00"


#-------------------- loop over months and scenarios  ------------------
for z in range(len(modLs)):
    t0 = time.time()
    for scen in scenarios:
        print(modLs[z], scen)
        t1 = time.time()

        # Open the entire raw dataset for this scenatio:
        print(dir_raw_decmp + modLs[z]+'/'+scen+'/'+modLs[z]+'_6hrLev_'+scen+'_*_20150101-20200101_subset_c.nc') # for debugging
        ds = xr.open_mfdataset( dir_raw_decmp + modLs[z]+'/'+scen+'/'+modLs[z]+'_6hrLev_'+scen+'_*_subset_c.nc'  ,combine='by_coords')
        
        # for testing, open just one file (look at years/scen combi)  # NB YEAR!!
        # ds = xr.open_mfdataset( dir_raw_decmp + modLs[z]+'/'+scen+'/'+modLs[z]+'_6hrLev_'+scen+'_*_20150101-20200101_subset_c.nc'  ,combine='by_coords') # 1 file of 5y for testing 
        # ds = xr.open_mfdataset( dir_raw_decmp + modLs[z]+'/'+scen+'/'+modLs[z]+'_6hrLev_'+scen+'_*_19500101-19600101_subset_c.nc'  ,combine='by_coords') # 1 file of 5y for testing 


        ds=ds.sel(time=slice('1950-01-01T12:00','2099-12-31T18:00'))
        ds=ds.sel(time=~ds.get_index("time").duplicated())
        ds['P'] = ds['P'].astype('float32')
        ds['SST'] = ds['SST'].astype('float32')

        gcmP   = ds['P']
        gcmPs  = ds['Ps']
        gcmT   = ds['T']
        gcmHGT = ds['HGT']

        g  = 9.80665
        R  = 8.3144598
        M  = 0.0289644
        Lb = -6.5/1000 #(K/m)

        exponent = ((-g*M)/(R*Lb))
        P_ratio  = gcmP/gcmPs
        T_b      = gcmT[:,0,:,:]
        ds['Z']  = (((T_b*np.exp((np.log(P_ratio)/exponent))))-T_b)/Lb
        ds['Z']  = ds['Z']+gcmHGT
        ds['Z']  = ds['Z'].transpose("time", "lev", "lat", "lon")
        print('computed Z for '+modLs[z])

        # make output directory (w. modLs[z]/scen subdirs) if it doesnt exist:
        out_dir = dir_raw_month + modLs[z] +'/' + scen + '/'
        if not os.path.exists(out_dir):
            # os.mkdir(out_dir)
            os.makedirs(out_dir)  # to make parent + subdirs


        ## Call in parallel :
        with mp.Pool(processes = Nprocs) as p:
            p.map( month_func, range(1,13) )          # for month_idx in range(1,13):


        print(modLs[z], scen, " time: ", time.time() - t1 ) 
    print(modLs[z], " tot time: ", time.time() - t0 ) 

print("\n")
print("************************  Finished creating monthly files **************************")
print("*********        For models: ", modLs, "        ************")
print("*********        and scenarios: ", scenarios, "         ************")
print("************************************************************************************* ")
print("\n")




    



