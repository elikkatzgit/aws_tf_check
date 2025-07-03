resource "aws_sqs_queue" "microservice1" {
  name                      = "microservice1"
  visibility_timeout_seconds = 30
  message_retention_seconds  = 345600
  delay_seconds              = 0
}

output "sqs_queue_url" {
  value = aws_sqs_queue.microservice1.id
}

output "sqs_queue_arn" {
  value = aws_sqs_queue.microservice1.arn
}
