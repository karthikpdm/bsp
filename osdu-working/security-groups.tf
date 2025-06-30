
# SecurityGroup for communication between Worker and Control plane
resource "aws_security_group" "osdu-ir-eks-node-sg" {
  name        = "osdu-ir-eks-node-sg"
  description = "Allow EKS worker nodes to talk to EKS control Plane"
  vpc_id      = aws_vpc.osdu-ir-vpc.id

  # Allow full traffic from worker to control plane
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]

  }
  tags = {
    Name = "osdu-ir-eks-node-sg"
  }
}

# Security group for Istio
resource "aws_security_group" "osdu-ir-istio-sg" {
  name        = "osdu-ir-istio-sg"
  description = "Security group for Istio ingress and internal mesh"
  vpc_id      = aws_vpc.osdu-ir-vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Ingress for internal mesh traffic (e.g., sidecar communication)
  ingress {
    from_port   = 15000
    to_port     = 15999
    protocol    = "tcp"
    cidr_blocks = ["10.13.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "osdu-ir-istio-sg"
  }
}

# Security group for keycloak 
resource "aws_security_group" "osdu-ir-keycloak-sg" {
  name        = "osdu-ir-keycloak-sg"
  description = "Security group for Keycloak (internal access only)"
  vpc_id      = aws_vpc.osdu-ir-vpc.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["10.13.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "osdu-ir-keycloak-sg"
  }
}

#Security group for Elastic Search
resource "aws_security_group" "osdu-ir-elasticsearch-sg" {
  name        = "osdu-ir-elasticsearch-sg"
  description = "Security group for Elastic Search"
  vpc_id      = aws_vpc.osdu-ir-vpc.id

  ingress {
    from_port   = 9200
    to_port     = 9200
    protocol    = "tcp"
    cidr_blocks = ["10.13.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "osdu-ir-elasticsearch-sg"
  }
}

#Security group for PostgreSql
resource "aws_security_group" "osdu-ir-postgresql-sg" {
  name        = "osdu-ir-postgresql-sg"
  description = "Security group for PostgreSql DB"
  vpc_id      = aws_vpc.osdu-ir-vpc.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.13.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "osdu-ir-postgresql-sg"
  }
}

#Security group for RabbitMQ
resource "aws_security_group" "osdu-ir-rabbitmq-sg" {
  name        = "osdu-ir-rabbitmq-sg"
  description = "Security group for "
  vpc_id      = aws_vpc.osdu-ir-vpc.id

  # AMQP protocol for service communication
  ingress {
    from_port   = 5672
    to_port     = 5672
    protocol    = "tcp"
    cidr_blocks = ["10.13.0.0/16"]
  }

  # Optional HTTP UI access (for internal diagnostics)
  ingress {
    from_port   = 15672
    to_port     = 15672
    protocol    = "tcp"
    cidr_blocks = ["10.13.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "osdu-ir-rabbitmq-sg"
  }
}

#Security group for MinIO
resource "aws_security_group" "osdu-ir-minio-sg" {
  name        = "osdu-ir-minio-sg"
  description = "Security group for MinIO"
  vpc_id      = aws_vpc.osdu-ir-vpc.id

  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["10.13.0.0/16"]
  }

  ingress {
    from_port   = 9001
    to_port     = 9001
    protocol    = "tcp"
    cidr_blocks = ["10.13.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "osdu-ir-minio-sg"
  }
}

#Security group for Redis
resource "aws_security_group" "osdu-ir-redis-sg" {
  name        = "osdu-ir-redis-sg"
  description = "Security group for Redis"
  vpc_id      = aws_vpc.osdu-ir-vpc.id

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["10.13.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "osdu-ir-redis-sg"
  }
}

#Security group for Apache Airflow
resource "aws_security_group" "osdu-ir-airflow-sg" {
  name        = "osdu-ir-airflow-sg"
  description = "Security group for Apache Airflow"
  vpc_id      = aws_vpc.osdu-ir-vpc.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["10.13.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "osdu-ir-airflow-sg"
  }
}

#Security group for OSDU MicroServices
resource "aws_security_group" "osdu-ir-microservices-sg" {
  name        = "osdu-ir-microservices-sg"
  description = "Security group for MicroServices"
  vpc_id      = aws_vpc.osdu-ir-vpc.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["10.13.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "osdu-ir-microservices-sg"
  }
}
