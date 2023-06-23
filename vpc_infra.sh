#!/bin/bash

# Set AWS region and VPC CIDR 
AWS_REGION="us-east-1"
VPC_CIDR="10.0.0.0/16"

# Create VPC
VPC_ID=$(aws ec2 create-vpc --cidr-block $VPC_CIDR --region $AWS_REGION --output text --query 'Vpc.VpcId')
echo "VPC created with ID: $VPC_ID"

# Enable DNS hostnames for the VPC
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames

# Create an Internet Gateway
IGW_ID=$(aws ec2 create-internet-gateway --region $AWS_REGION --output text --query 'InternetGateway.InternetGatewayId')
echo "Internet Gateway created with ID: $IGW_ID"

# Attach the Internet Gateway to the VPC
aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID

# Create a public subnet
PUBLIC_SUBNET_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block "10.0.0.0/24" --availability-zone $AWS_REGIONa --output text --query 'Subnet.SubnetId')
echo "Public subnet created with ID: $PUBLIC_SUBNET_ID"

# Create a private subnet
PRIVATE_SUBNET_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block "10.0.1.0/24" --availability-zone $AWS_REGIONa --output text --query 'Subnet.SubnetId')
echo "Private subnet created with ID: $PRIVATE_SUBNET_ID"

# Create a route table for the public subnet
PUBLIC_ROUTE_TABLE_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --region $AWS_REGION --output text --query 'RouteTable.RouteTableId')
echo "Public route table created with ID: $PUBLIC_ROUTE_TABLE_ID"

# Associate the public subnet with the public route table
aws ec2 associate-route-table --route-table-id $PUBLIC_ROUTE_TABLE_ID --subnet-id $PUBLIC_SUBNET_ID

# Create a route for internet traffic to the public route table
aws ec2 create-route --route-table-id $PUBLIC_ROUTE_TABLE_ID --destination-cidr-block "0.0.0.0/0" --gateway-id $IGW_ID

# Create a security group for the RDS instance
RDS_SECURITY_GROUP_ID=$(aws ec2 create-security-group --group-name "rds-security-group" --description "RDS Security Group" --vpc-id $VPC_ID --region $AWS_REGION --output text --query 'GroupId')
echo "RDS security group created with ID: $RDS_SECURITY_GROUP_ID"

# Configure security group inbound rules for RDS
aws ec2 authorize-security-group-ingress --group-id $RDS_SECURITY_GROUP_ID --protocol tcp --port 3306 --source-group $RDS_SECURITY_GROUP_ID

# Create an RDS instance in the private subnet
RDS_SUBNET_GROUP_NAME="rds-subnet-group"
aws rds create-db-subnet-group --db-subnet-group-name $RDS_SUBNET_GROUP_NAME --db-subnet-group-description "RDS Subnet Group" --subnet-ids $PRIVATE_SUBNET_ID
RDS_INSTANCE_ID=$(aws rds create-db-instance --db-instance-identifier "my-rds-instance" --db-instance-class "db.t2.micro" --engine "mysql" --allocated-storage 20 --master-username "admin" --master-user-password "password" --vpc-security-group-ids $RDS_SECURITY_GROUP_ID --availability-zone $AWS_REGIONa --db-subnet-group-name $RDS_SUBNET_GROUP_NAME --output text --query 'DBInstance.DBInstanceIdentifier')
echo "RDS instance created with ID: $RDS_INSTANCE_ID"

# Create a route table for the private subnet
PRIVATE_ROUTE_TABLE_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --region $AWS_REGION --output text --query 'RouteTable.RouteTableId')
echo "Private route table created with ID: $PRIVATE_ROUTE_TABLE_ID"

# Associate the private subnet with the private route table
aws ec2 associate-route-table --route-table-id $PRIVATE_ROUTE_TABLE_ID --subnet-id $PRIVATE_SUBNET_ID

# Create a route to the Internet Gateway for the private route table
aws ec2 create-route --route-table-id $PRIVATE_ROUTE_TABLE_ID --destination-cidr-block "0.0.0.0/0" --gateway-id $IGW_ID

# Output the created resource IDs
echo "VPC ID: $VPC_ID"
echo "Public Subnet ID: $PUBLIC_SUBNET_ID"
echo "Private Subnet ID: $PRIVATE_SUBNET_ID"
echo "RDS Instance ID: $RDS_INSTANCE_ID"

