# Create AWS Environment

1. Create VPC
2. Create Inter Gateway
3. Create Custom Route Table
4. Create Subnet
5. Associate Subnet with Route table
6. Create Security Group to allow port 22, 80, 443
7. Create a network interface with an ip in the subnet that created in step 4
8. Assign an elastic IP to the network interface created in step 7
9. Create centos server and install/enable apache2