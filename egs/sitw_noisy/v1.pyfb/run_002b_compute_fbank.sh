#!/bin/bash
# Copyright
#                2018   Johns Hopkins University (Author: Jesus Villalba)
#                2017   David Snyder
#                2017   Johns Hopkins University (Author: Daniel Garcia-Romero)
#                2017   Johns Hopkins University (Author: Daniel Povey)
# Apache 2.0.
#
. ./cmd.sh
. ./path.sh
set -e
nodes=fs01 #by default it puts fbank in /export/fs01/jsalt19
storage_name=$(date +'%m_%d_%H_%M')
fbankdir=`pwd`/fbank
vaddir=`pwd`/fbank  # energy VAD

stage=1
config_file=default_config.sh

. parse_options.sh || exit 1;
. $config_file

# Make filterbanks and compute the energy-based VAD for each dataset

if [ $stage -le 1 ]; then
    # Prepare to distribute data over multiple machines
    if [[ $(hostname -f) == *.clsp.jhu.edu ]] && [ ! -d $fbankdir/storage ]; then
	dir_name=$USER/hyp-data/sitw_noisy/v1/$storage_name/fbank/storage
	if [ "$nodes" == "b0" ];then
	    utils/create_split_dir.pl \
			    utils/create_split_dir.pl \
		/export/b{04,05,06,07}/$dir_name $fbankdir/storage
	elif [ "$nodes" == "b1" ];then
	    utils/create_split_dir.pl \
		/export/b{14,15,16,17}/$dir_name $fbankdir/storage
	else 
	    utils/create_split_dir.pl \
		/export/fs01/jsalt19/$dir_name $fbankdir/storage
	fi
    fi
fi

#Train datasets
if [ $stage -le 2 ];then 
    for name in voxceleb1 voxceleb2_train
    do
	steps_pyfe/make_fbank.sh --write-utt2num-frames true --fbank-config conf/pyfb_16k.conf --nj 40 --cmd "$train_cmd" \
			   data/${name} exp/make_fbank $fbankdir
	utils/fix_data_dir.sh data/${name}
    done
fi

# Combine voxceleb
if [ $stage -le 3 ];then 
  utils/combine_data.sh --extra-files "utt2num_frames" data/voxceleb data/voxceleb1 data/voxceleb2_train
  utils/fix_data_dir.sh data/voxceleb

  if [ "$nnet_data" == "voxceleb_div2" ] || [ "$plda_data" == "voxceleb_div2" ];then
      #divide the size of voxceleb
      utils/subset_data_dir.sh data/voxceleb $(echo "1236567/2" | bc) data/voxceleb_div2
  fi
fi


#SITW
if [ $stage -le 4 ];then 
    for name in sitw_dev_enroll sitw_dev_test sitw_eval_enroll sitw_eval_test
    do
	steps_pyfe/make_fbank.sh --write-utt2num-frames true --fbank-config conf/pyfb_16k.conf --nj 40 --cmd "$train_cmd" \
			   data/${name} exp/make_fbank $fbankdir
	utils/fix_data_dir.sh data/${name}
    done
fi


