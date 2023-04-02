#!/usr/bin/env python
# coding: utf-8

import os
import urllib

from osgeo import gdal
from math import floor, ceil
from pyproj import Proj
import matplotlib.pyplot as plt
import xarray as xr
import numpy as np
import pandas as pd
import geopandas as gpd
from shapely.geometry import Point
import cartopy.crs as ccrs
import dask
import glob

import xesmf as xe
import quantile_mapping as qm




def get_latlon_b(ds,lon_str,lat_str,lon_dim,lat_dim):
    #### Longitude East-West Stagger
    diffWestEast    = ds[lon_str].diff(lon_dim)                         # take difference in longitudes across west-east (columns) dimension
    diffWestEast    = np.array(diffWestEast)                            # assign this to numpy array
    padding         = diffWestEast[:,-1].reshape(len(diffWestEast[:,-1]),1)  # get the last column of the differences and reshape so it can be appended
    diffWestEastAll = np.append(diffWestEast, padding, axis=1)/2               # append last value to all_data

    # dimensions now the same as ds
    lon_b_orig      = ds[lon_str]-diffWestEastAll

    # lon_b needs to be staggered - add to the final row to bound
    last_add     = ds[lon_str][:,-1]+diffWestEastAll[:,-1]
    last_add     = np.array(last_add)
    last_add     = last_add.reshape(len(last_add),1)
    lon_b_append = np.append(np.array(lon_b_orig),last_add,1)
    last_add     = lon_b_append[0,:].reshape(1,len(lon_b_append[0,:]))
    lon_b_append = np.append(last_add,lon_b_append,axis=0)


    #### Latitude Stagger
    diffSouthNorth=ds[lat_str].diff(lat_dim)                         # take difference in longitudes across west-east (columns) dimension
    diffSouthNorth=np.array(diffSouthNorth)                            # assign this to numpy array
    padding=diffSouthNorth[0,:].reshape(1,len(diffSouthNorth[0,:]))  # get the last column of the differences and reshape so it can be appended
    diffSouthNorthAll = np.append(padding,diffSouthNorth,axis=0)/2               # append last value to all_data

    # dimensions now the same as ds
    lat_b_orig      = ds[lat_str]-diffSouthNorthAll

    # lat_b needs to be staggered - add to the first row to bound
    last_add     = ds[lat_str][0,:]+diffWestEastAll[0,:]
    last_add     = np.array(last_add)
    last_add     = last_add.reshape(1,len(last_add))
    lat_b_append = np.append(last_add,np.array(lat_b_orig),axis=0)
    last_add     = lat_b_append[:,-1].reshape(len(lat_b_append[:,-1]),1)
    lat_b_append = np.append(lat_b_append,last_add,axis=1)

    
    grid_with_bounds = {'lon': ds[lon_str].values,
                               'lat': ds[lat_str].values,
                               'lon_b': lon_b_append,
                               'lat_b': lat_b_append,
                              }

    return grid_with_bounds

def get_latlon_b_rect(ds,lon_str,lat_str,lon_dim,lat_dim):
    #### Longitude Stagger
    diffWestEast    = ds[lon_str].diff(lon_dim)                         # take difference in longitudes across west-east (columns) dimension
    diffWestEastArr = np.array(diffWestEast).reshape(len(diffWestEast),1)                            # assign this to numpy array
    padding         = diffWestEastArr[-1].reshape(1,1)  # get the last column of the differences and reshape so it can be appended
    diffWestEastAll = np.append(diffWestEastArr, padding, axis=0)/2               # append last value to all_data
    # # dimensions now the same as ds
    lon_b_orig      = ds[lon_str].values.reshape(len(ds[lon_str]),1)-diffWestEastAll

    # lon_b needs to be staggered - add to the final row to bound
    last_add        = ds[lon_str][-1].values+diffWestEastAll[-1]
    last_add        = np.array(last_add).reshape(len(last_add),1)
    last_add        = last_add.reshape(1,1)
    lon_b_append    = np.append(np.array(lon_b_orig),last_add,0)

    #### Latitude Stagger
    diffSouthNorth    = ds[lat_str].diff(lat_dim)                         # take difference in latitudes across west-east (columns) dimension
    diffSouthNorthArr = np.array(diffSouthNorth).reshape(len(diffSouthNorth),1)                            # assign this to numpy array
    padding         = diffSouthNorthArr[-1].reshape(1,1)  # get the last column of the differences and reshape so it can be appended
    diffSouthNorthAll = np.append(diffSouthNorthArr, padding, axis=0)/2               # append last value to all_data
    # # dimensions now the same as ds
    lat_b_orig      = ds[lat_str].values.reshape(len(ds[lat_str]),1)-diffSouthNorthAll

    # lat_b needs to be staggered - add to the final row to bound
    last_add        = ds[lat_str][-1].values+diffSouthNorthAll[-1]
    last_add        = np.array(last_add).reshape(len(last_add),1)
    last_add        = last_add.reshape(1,1)
    lat_b_append    = np.append(np.array(lat_b_orig),last_add,0)

    grid_with_bounds = {'lon': ds[lon_str],
                               'lat': ds[lat_str],
                               'lon_b': lon_b_append.reshape(len(lon_b_append),),
                               'lat_b': lat_b_append.reshape(len(lat_b_append),),
                              }
    return grid_with_bounds



###---------------- SET paths and parameters  ----------------####

# ERAi
# era_path='/glade/u/home/currierw/scratch/erai/convection/erai/clipped_by_month_convert_SST/'
# era_path='/glade/scratch/bkruyt/erai/erai_greatlakes_month/' # not chronological because monthly + buffer
era_path='/glade/scratch/gutmann/icar/forcing/erai_conus/monthly/'  

modelLs       = ['MIROC-ES2L']; i=0
scenarios     = ['ssp585'] #['historical']
# t1= '1950-01-01' 
# t2= '2019-08-31'

raw_dir = '/glade/scratch/bkruyt/CMIP6/raw/' #MIROC-ES2L/historical' 
in_dir = '/glade/scratch/bkruyt/CMIP6/BC_3D_merged/' #MIROC-ES2L/historical' 
out_dir='/glade/scratch/bkruyt/CMIP6/BC_2D_3D/'


# in_dir = '/glade/scratch/abby/temp_forcing/' + modelLs[i] + '/d_'
# out_dir='/glade/scratch/abby/ESM_bias_correction/ref_period_only/FINAL/qm_1to1'



#---------------- Load the ERAi data, crop it and correct the cp ----------------

dsObs=xr.open_mfdataset(era_path + 'erai*.nc',combine='by_coords') 


if ('Note' not in dsObs['cp'].attrs.keys() or 
   dsObs['cp'].attrs['Note'] != 'Converted from mm/time step (6 hours) to mm/s by dividing by 21600'):
    print( 'ERAi cp data has not been converted to mm/sec - converting now ....' )
    dsObs['cp']=dsObs['cp']/21600
    dsObs['cp']=dsObs['cp'].assign_attrs(
        {'long_name': 'Convective Precipitation', 
         'units': 'mm/s','Note':'Converted from mm/time step (6 hours) to mm/s by dividing by 21600'}
    )
else:
    print( 'no correction to ERAi cp' )
    print( dsObs['cp'].attrs )
    
    


# ---------------- Run the 2d bias correction: ----------------
for i in range(0,len(modelLs)):
    for scen in scenarios:
        t0 =time.time()
        print(str(i+1)+' '+modelLs[i] + ' ' + scen)

        # Load the 3D bc GCM data, onto which we will add the SST and cp 
        dsFull = xr.open_mfdataset(in_dir + modelLs[i] +'/'+ scen +'/'+modelLs[i] + '*.nc',combine='by_coords').load()

        # Get SST and cp from the original (raw) GCM data:
        dsRaw = xr.open_mfdataset(raw_dir + modelLs[i] +'/'+ scen +'/'+modelLs[i] + '*.nc',combine='by_coords')
        dsCp_in = dsRaw['prec'] #.sel(time=slice(t1,t2)) ## WHY slice??? not generic. 
        dsSST_in = dsRaw['SST'] #.sel(time=slice(t1,t2))
        # dsCp_in=dsCp_in.sel(time=~dsCp_in.get_index("time").duplicated())
        # dsSST_in=dsSST_in.sel(time=~dsSST_in.get_index("time").duplicated())
        print("   GCM data loaded")



        # Need to do a interpolation here with xesmf
        cp_grid_with_bounds   = get_latlon_b_rect(dsCp_in,lon_str='lon',lat_str='lat',lon_dim='lon',lat_dim='lat')
        # sst_grid_with_bounds  = get_latlon_b_rect(dsSST_in,lon_str='lon',lat_str='lat',lon_dim='lon',lat_dim='lat')         # redundant, should be same grid?
        erai_grid_with_bounds = get_latlon_b_rect(dsObs['sst'],lon_str='lon',lat_str='lat',lon_dim='lon',lat_dim='lat')
        regridder = xe.Regridder(cp_grid_with_bounds, erai_grid_with_bounds, 'bilinear') # input grid, gird you want to resample to, method

        dsCp_out = regridder(dsCp_in).load()
        dsSST_out = regridder(dsSST_in).load()

        dsObs['cp']  = dsObs['cp'].load()
        dsObs['sst'] = dsObs['sst'].load()

        # the reference dataset should always be historical:
        if scen=='historical':
            dsCp_ref=dsCp_out.sel(time=slice('1979-09-01','2019-08-31'))
            dsSST_ref=dsSST_out.sel(time=slice('1979-09-01','2019-08-31'))
        else:  # load the historical GCM, regrid, ...
            dsRaw_ref = xr.open_mfdataset(raw_dir + modelLs[i] +'/historical/'+modelLs[i] + '*.nc',combine='by_coords')
            dsCp_ref =  regridder(dsRaw_ref['prec']).sel(time=slice('1979-09-01','2019-08-31')).load()
            dsSST_ref =  regridder(dsRaw_ref['SST']).sel(time=slice('1979-09-01','2019-08-31')).load()
          
        dsSST_out=dsSST_out.interpolate_na(dim='time')
        print("   Regridded")

        # Bias Correct Convective Precipitation
        daPrecQm=qm.quantile_mapping_by_group(  dsCp_out,
                                                dsCp_ref, # this should always be hist period?
                                                dsObs['cp'].sel(time=slice('1979-09-01','2019-08-31')),
                                                grouper='time.month',detrend=False,use_ref_data=True,extrapolate='1to1',n_endpoints=50)
        daPrecQm = xr.where(dsCp_out <= 0, 0, daPrecQm)
        daPrecQm.attrs = dsCp_in.attrs
        daCpQm=daPrecQm.to_dataset(name='cp').load()
        # check/ add attrs?
        print(daPrecQm.attrs)
        print("   BC cp")


        # Bias Correct Sea Surface Temperature
        daSSTQm=qm.quantile_mapping_by_group(   dsSST_out,
                                                dsSST_ref,
                                                dsObs['sst'].sel(time=slice('1979-09-01','2019-08-31')),
                                                grouper='time.month',detrend=True,use_ref_data=True,extrapolate='1to1',n_endpoints=50)
        daSSTQm.attrs = dsSST_in.attrs
        daSSTQm=daSSTQm.to_dataset(name='tskin').load()
        print("   BC SST")
        print("   total BC time: ", time.time()-t0, "\n") 
        
        if scen == 'historical':
            time_s = np.arange(1950, 2015, 10)
            time_f = np.arange(1959, 2099, 10)
        else:
            time_s = np.arange(2015, 2099, 10)
            time_f = np.arange(2024, 2100, 10)

        if not os.path.exists(out_dir):
            os.makedirs(out_dir)

            
        ## Call in parallel :
        with mp.Pool(processes = Nprocs) as p:
            [p.apply(write_to_file, args=(dsFull, daCpQm, daSSTQm, time_start )) for time_start in time_s] 

                  
 