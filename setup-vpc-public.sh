#!/bin/sh

if [ ! "$1" ]; then
  echo "Usage: $0 env_file"
  exit
fi

set -u
set -e

readonly FILE_ENV="$1"

. ${FILE_ENV}

cat << ETX
[ENV]
AWS_DEFAULT_REGION: ${AWS_DEFAULT_REGION}
VPC_SUBNET_AZ:      ${VPC_SUBNET_AZ}
VPC_CIDR:           ${VPC_CIDR}
VPC_SUBNET_CIDR:    ${VPC_SUBNET_CIDR}

ETX

# export
export AWS_DEFAULT_REGION

# check
AWS_SUPPORT_PLATFORMS=$( \
         aws ec2 describe-account-attributes \
           --query 'AccountAttributes[?AttributeName == `supported-platforms`].AttributeValues[].AttributeValue' \
           --output text \
)

cat << ETX
[AWS_SUPPORT_PLATFORMS]
${AWS_SUPPORT_PLATFORMS}

ETX


# create vpc
aws ec2 create-vpc \
        --cidr-block ${VPC_CIDR}
VPC_ID=$( \
        aws ec2 describe-vpcs \
          --filters Name=cidr,Values=${VPC_CIDR} \
          --query 'Vpcs[].VpcId' \
          --output text \
)

cat << ETX
[VPC]
VPC_ID: ${VPC_ID}

ETX


# create igw
aws ec2 create-internet-gateway 
VPC_IGW_ID=$( \
        aws ec2 describe-internet-gateways \
          --query 'InternetGateways[?Attachments == `[]`].InternetGatewayId' \
          --output text \
        | sed 's/        .*$//g' \
)
cat << ETX
[IGW]
VPC_IGW_ID: ${VPC_IGW_ID}

ETX

echo 'y'
aws ec2 attach-internet-gateway \
        --internet-gateway-id ${VPC_IGW_ID} \
        --vpc-id ${VPC_ID}
echo 'z'

# create subnet
aws ec2 create-subnet \
        --vpc-id ${VPC_ID} \
        --cidr-block ${VPC_SUBNET_CIDR} \
        --availability-zone ${VPC_SUBNET_AZ}

VPC_SUBNET_ID=$( \
        aws ec2 describe-subnets \
          --filters Name=cidrBlock,Values=${VPC_SUBNET_CIDR} \
          --query 'Subnets[].SubnetId' \
          --output text \
)

cat << ETX
[Subnet]
VPC_SUBNET_ID: ${VPC_SUBNET_ID}

ETX


# create route table
aws ec2 create-route-table \
        --vpc-id ${VPC_ID}

VPC_ROUTE_TABLE_ID=$( \
        aws ec2 describe-route-tables \
          --query 'RouteTables[?Associations == `[]`].RouteTableId' \
          --output text \
)

cat << ETX
[RouteTable]
VPC_ROUTE_TABLE_ID: ${VPC_ROUTE_TABLE_ID}

ETX


# add route
VPC_CIDR_DEST='0.0.0.0/0'

aws ec2 create-route \
        --route-table-id ${VPC_ROUTE_TABLE_ID} \
        --destination-cidr-block ${VPC_CIDR_DEST} \
        --gateway-id ${VPC_IGW_ID}

# associate route-table with subnet
aws ec2 associate-route-table \
        --subnet-id ${VPC_SUBNET_ID} \
        --route-table-id ${VPC_ROUTE_TABLE_ID}


cat << ETX
[end]
ETX
