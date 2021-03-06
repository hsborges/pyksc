#!/bin/bash

if [ $# -lt 3 ]; then
    echo "Please provide me with a time series file, an output folder and a features folder"
    exit 1
fi

IN=$1
BASE_FOLD=$2
FEATURES_FOLDER=$3

K=2
F1=0.5
GAMMA_MAX=20

#Creates output folder
mkdir -p $BASE_FOLD 2> /dev/null

#Generate cross-val
python generate_cross_vals.py $IN $BASE_FOLD

#Cluster dataset
for fold in $BASE_FOLD/*/; do
    mkdir -p $fold/ksc 2> /dev/null
    python cluster.py $IN $fold/ksc $K
done

#Compute agreement between folds
python sim_folds.py $IN $BASE_FOLD

#Precompute probabilities train
for fold in $BASE_FOLD/*/; do
    mkdir -p $fold/probs/ 2> /dev/null
    python classify_pts.py $IN $fold/train.dat $fold/ksc/cents.dat \
        $fold/ksc/assign.dat $fold/probs/ $GAMMA_MAX
done

#Precompute probabilities test
for fold in $BASE_FOLD/*/; do
    mkdir -p $fold/probs-test/ 2> /dev/null
    python classify_pts_test.py $IN $fold/ksc/cents.dat $fold/test.dat \
        $fold/ksc/assign.dat $fold/probs-test/ $GAMMA_MAX
done

#Create the assign for the test
for fold in $BASE_FOLD/*/; do
    python create_test_assign.py $IN $fold/test.dat \
        $fold/ksc/cents.dat > $fold/ksc/test_assign.dat
done

#Learn parameters train
for fold in $BASE_FOLD/*/; do
    mkdir -p $fold/cls-res-fitted-$F1-$GAMMA_MAX-train 2> /dev/null
done
python classify_theta_train.py $IN $BASE_FOLD $F1 cls-res-fitted-$F1-$GAMMA_MAX-train $GAMMA_MAX $K

#Learn parameters test
for fold in $BASE_FOLD/*/; do
    mkdir -p $fold/cls-res-fitted-$F1-$GAMMA_MAX 2> /dev/null
done
python classify_theta.py $IN $BASE_FOLD $F1 cls-res-fitted-$F1-$GAMMA_MAX $GAMMA_MAX $K

#Adding static features
for fold in $BASE_FOLD/*/; do
    python multimodel_class.py $FEATURES_FOLDER $fold cls-res-fitted-$F1-$GAMMA_MAX $GAMMA_MAX
done
