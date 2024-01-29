#!/bin/bash
# just because I am too lazy to type these to commands everytime. 
 
k3d cluster delete tinta-cluster-tinta
k3d registry delete k3d-tinta-local-registry
docker network rm k3d-tinta-cluster-tinta