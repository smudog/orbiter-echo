#!/usr/bin/env python3

import pandas as pd
from matplotlib import pyplot as plt
import matplotlib as mpl
mpl.use('Agg')
from pyproj import Transformer
import os
import re
from datetime import datetime,timedelta
import argparse

def read_one_utig(args,path):

    with open(path,'r') as f:
        for line in f.readlines():
            if '# YEAR' in line:
                columns = line.rstrip().split()[1:]
                break

    data = pd.read_csv(path,sep='\s+',comment='#',names=columns,index_col=False)
    data['UTC_Time'] = data.apply(lambda r: datetime.strptime(f"{r['YEAR'].astype(int)}-{r['DOY'].astype(int)}", "%Y-%j"), axis=1) + pd.to_timedelta(data['SOD'],unit='s')

    epsg=3031
    if data['LAT'].mean() > -66: 
        if args.arctic:
            epsg=3413
        else:
            return pd.DataFrame()

    elif data['LAT'].mean() < 66:
        if not args.arctic:
            epsg=3031
        else:
            return pd.DataFrame()
            
    to_xy = Transformer.from_crs(4326,epsg,always_xy=True)
    data['X'],data['Y'] = to_xy.transform(data['LON'],data['LAT'])

    return(data)

def get_echo(df):
    if df.empty:
        print('not returning')
        return df

    if 'SRF_REFLECT' in df.columns:
        srf='SRF_REFLECT'
    elif 'SRF_RELFECT' in df.columns:
        srf='SRF_RELFECT'

    df['RELATIVE_ECHO'] = df['PARTIAL_BED_REFLECT'] - df[srf]
    filtered_df = df[df[srf].astype(float) > -20].copy()
    return filtered_df

def get_all_data(args):
    dir_pattern = r'IR[12]HI2'
    f_pattern = r'.txt$'

    all_list = []

    for d in os.listdir(args.data):
        if re.search(dir_pattern,d): 
            for f in os.listdir(os.path.join(args.data,d)):
                if re.search(f_pattern,f):
                    print(f"{d}/{f}")
                    df  = get_echo( read_one_utig(args, os.path.join(args.data,d,f) ) )
                    if df.empty:
                        continue
                    else:
                        all_list.append(df)

    print(f'Combine all')
    all_df = pd.concat(all_list,ignore_index=True)
    return all_df


def plot(all_df):
    plt.scatter(all_df['X']/1000,all_df['Y']/1000,s=1,c=all_df['RELATIVE_ECHO'],cmap='viridis')
    plt.gca().set_aspect('equal')
    plt.xlim((-3000,3000))
    plt.ylim((-3000,3000))
    plt.colorbar()
    plt.savefig('all.png')
    plt.close()
    print(all_df)
    


def main():
    parser = argparse.ArgumentParser(
                    prog='required surface SNR',
                    description='Using HiCARS data, calculate the reiored surface SNR that would be need to detect the bed',
                    epilog="reference: Schroeder, D. M., Bienert, N. L., Culberg, R., MacKie, E. J., Teisberg, T. O., Chu, W., and Young, D. A., 2021, Glaciological Constraints on Link Budgets for Orbital Radar Sounding of Earth's Ice Sheets, 647-650, 10.1109/IGARSS47720.2021.9553237")
    parser.add_argument('--data',help='path to IR2HI2 style data folders',default='/disk/kea/WAIS/targ/comm/DATA/Level2')
    parser.add_argument('--arctic', action='store_true', help='determine if for arctic') 
    args = parser.parse_args()

    plot(get_all_data(args))

if __name__ == '__main__':
    main()


