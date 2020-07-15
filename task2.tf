// aws + terraform //

// providing credentials in form of profile for better securities//

provider "aws"{
 
 region = "ap-south-1"
 
 profile = "vik_iam1"

 
}


// creating key

resource  "tls_private_key" "mykey" {
  algorithm   = "RSA"
}

resource "aws_key_pair" "generated_key"{
  
  key_name = "mykey"

  public_key = "${tls_private_key.mykey.public_key_openssh}"

  depends_on = [

      tls_private_key.mykey
  ]

}

resource "local_file" "key-file" {

    content= "${tls_private_key.mykey.private_key_pem}"
    filename = "mykey.pem"
    depends_on = [

        tls_private_key.mykey

    ]
}

// now creating vpc //

resource "aws_vpc" "main" {

  cidr_block       = "192.168.0.0/16"
  
  instance_tenancy = "default"

  enable_dns_hostnames = "true"

  assign_generated_ipv6_cidr_block = "true"
  
  tags = {
    Name = "my-vpc"
  }
}

//creating security groups //

resource "aws_security_group" "my_rules" {

     depends_on = [aws_vpc.main]

  name        = "my_rules"
  description = "allowing ssh and http"
  vpc_id      = "${aws_vpc.main.id}"

  ingress {
    description = "allowing ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

ingress {
    description = "allowing http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "allowing mysql database"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allowing_selected inbound rules"
  }
 
}

// launching subnets //

//creating public sunet//
resource "aws_subnet" "subnet1" {

depends_on = [aws_vpc.main]

vpc_id= "${aws_vpc.main.id}"

cidr_block = "192.168.0.0/24"

availability_zone = "ap-south-1a"

tags = {

    Name = "public_subnet"
}
}


// creating private subnet

resource "aws_subnet" "subnet2" {

    
depends_on = [aws_vpc.main]

vpc_id= "${aws_vpc.main.id}"

cidr_block = "192.168.1.0/24"

availability_zone = "ap-south-1b"

tags = {

    Name = "private_subnet"
}
}

//code for internet gateway //

resource "aws_internet_gateway" "ig" {

    
depends_on = [aws_vpc.main]

vpc_id = "${aws_vpc.main.id}"

  tags = {
    Name = "my gateway"
  }

}

//code for updating routing table

resource "aws_route_table" "routing" {

    
depends_on = [ aws_vpc.main, aws_internet_gateway.ig ]

     vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.ig.id}"
  }
  tags = {
   
   Name = "route-tableig"
  }
}

resource "aws_route_table_association" "tosubnet1" {

    depends_on = [ aws_vpc.main, aws_internet_gateway.ig ,aws_route_table.routing]

subnet_id = "${aws_subnet.subnet1.id}"

route_table_id = "${aws_route_table.routing.id}"
}

resource "aws_instance" "wordpress" {

    depends_on = [tls_private_key.mykey,aws_vpc.main, aws_security_group.my_rules,aws_internet_gateway.ig ,aws_route_table.routing]
 
 ami = "ami-7e257211"

 instance_type = "t2.micro"

 key_name = "${aws_key_pair.generated_key.key_name}"

 vpc_security_group_ids = [aws_security_group.my_rules.id]

 associate_public_ip_address = "true"

subnet_id = "${aws_subnet.subnet1.id}"

}

 resource "aws_instance" "my-sql" {

     depends_on = [tls_private_key.mykey,aws_vpc.main, aws_security_group.my_rules,aws_internet_gateway.ig ,aws_route_table.routing]
 
 ami = "ami-08706cb5f68222d09"

 instance_type = "t2.micro"

 key_name = "${aws_key_pair.generated_key.key_name}"

 vpc_security_group_ids = [aws_security_group.my_rules.id]

 associate_public_ip_address = "true"

subnet_id = "${aws_subnet.subnet2.id}"

}