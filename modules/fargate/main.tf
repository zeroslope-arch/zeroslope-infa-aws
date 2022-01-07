variable "security_groups" {
    type = list(string)
}

variable "subnet_id" {
    type = string
}

resource "aws_ecs_cluster" "app" {
    name = "app"
}

resource "aws_ecs_service" "zeroslope_api" {
    name            = "zeroslope-api"
    task_definition = aws_ecs_task_definition.zeroslop_api.arn
    cluster = aws_ecs_cluster.app.id
    launch_type = "FARGATE"
    network_configuration {
        assign_public_ip = false
        security_groups = var.security_groups
        subnets = [ var.subnet_id ]
    }
}

resource "aws_iam_role" "zeroslope_api_task_execution_role" {
    name               = "zeroslope-api-task-execution-role"
    assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
}

resource "aws_ecs_task_definition" "zeroslop_api" {
    family = "zeroslope-api"

    container_definitions = <<EOF
    [
        {
        "name": "zeroslope-api",
        "image": "594516819925.dkr.ecr.us-west-2.amazonaws.com/zeroslope-repo"
        }
    ]
    EOF

    # These are the minimum values for Fargate containers.
    cpu = 256
    memory = 512
    requires_compatibilities = ["FARGATE"]
    execution_role_arn = aws_iam_role.zeroslope_api_task_execution_role.arn

    # This is required for Fargate containers (more on this later).
    network_mode = "awsvpc"
}

data "aws_iam_policy_document" "ecs_task_assume_role" {
    statement {
        actions = ["sts:AssumeRole"]

        principals {
        type = "Service"
        identifiers = ["ecs-tasks.amazonaws.com"]
        }
    }
}

# Normally we'd prefer not to hardcode an ARN in our Terraform, but since this is
# an AWS-managed policy, it's okay.
data "aws_iam_policy" "ecs_task_execution_role" {
    arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Attach the above policy to the execution role.
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role" {
    role       = aws_iam_role.zeroslope_api_task_execution_role.name
    policy_arn = data.aws_iam_policy.ecs_task_execution_role.arn
}