#!/bin/bash

# source ../local.env

jx create cluster iks \
   -n jx-fra04 \
   -r eu-de \
   -z fra04 \
   -m b2c.4x16 \
   --workers=2 \
   --kube-version=1.15.8 \
   --namespace='jx'