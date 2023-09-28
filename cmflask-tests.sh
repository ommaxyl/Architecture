#!/bin/bash

cd terraform

DNSENDPOINT=$(terraform output -raw alb-dns-name)
echo "Testing $DNSENDPOINT"

curl $DNSENDPOINT:5000/
curl $DNSENDPOINT:5000/2
curl -X POST $DNSENDPOINT:5000
