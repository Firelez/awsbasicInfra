provider "aws" {
    region = "us-east-1"
}

resource "aws_vpc" "custom1" {
    cidr_block = "10.0.0.0/16"
    enable_dns_hostnamets = true
}

resource "aws_subnet" "public-subnet1"{
    vpc_id = "${aws_vpc.custom1.id}"
    cidr_block = "10.0.10.0/16"
    map_public_ip_on_launch = true
    availability_zone = "us-east-1a"
}

resource "aws_subnet" "public-subnet2"{
    vpc_id = "${aws_vpc.custom1.id}"
    cidr_block = "10.0.11.0/16"
    map_public_ip_on_launch = true
    availability_zone = "us-east-1b"
}

resource "aws_subnet" "private-subnet1"{
    vpc_id = "${aws_vpc.custom1.id}"
    cidr_block = "10.0.12.0/16"
    map_public_ip_on_launch = false
    availability_zone = "us-east-1a"
}

resource "aws_subnet" "private-subnet1"{
    vpc_id = "${aws_vpc.custom1.id}"
    cidr_block = "10.0.13.0/16"
    map_public_ip_on_launch = false
    availability_zone = "us-east-1b"
}

resource "aws_internet_gateway" "igw" {
    vpc_id = "${aws_vpc.custom1.id}"
}

resource "aws_route_table" "rt"{
    vpc_id = "${aws_vpc.custom1.id}"
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway}"
    }
}

resource "aws_route_table_association" "subnet1rt"{
    subnet_id = "${aws_subnet.public-subnet1.id}"
    route_table_id = "${aws_route_table.rt.id}"
}

resource "aws_route_table_association" "subnet2rt"{
    subnet_id = "${aws_subnet.public-subnet2.id}"
    route_table_id = "${aws_route_table.rt.id}"
}

resource "aws_route_table_association" "subnetp1rt"{
    subnet_id = "${aws_subnet.private-subnet1.id}"
    route_table_id = "${aws_route_table.rt.id}"
}

resource "aws_route_table_association" "subnetp2rt"{
    subnet_id = "${aws_subnet.private-subnet2.id}"
    route_table_id = "${aws_route_table.rt.id}"
}