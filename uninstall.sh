#!/bin/bash
# just because I am too lazy to type these to commands everytime. 
 
k3d cluster delete trivago-cluster-tinta
k3d registry delete k3d-trivago-local-registry
docker network rm k3d-trivago-cluster-tinta