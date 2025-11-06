aws_region     = "us-east-2"
ssh_key_name   = "ca0-keys"
ami_id         = "ami-0ea3c35c5c3284d82"

# Upgraded account - using t3.medium for resource-intensive nodes
master_instance_type   = "t3.medium"   # Control plane + observability (Prometheus/Grafana heavy)
worker_1_instance_type = "t3.medium"   # Data services (Kafka, Zookeeper, MongoDB)
worker_2_instance_type = "t3.small"    # Application services (Producer, Processor - lightweight)

# REQUIRED: Add your public IP for SSH access
# Get it with: curl -s ifconfig.me
my_ip = "2.59.157.106/32"
