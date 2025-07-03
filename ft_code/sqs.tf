resource "aws_sqs_queue" "sqs" {
  name                      = "sqs"
  visibility_timeout_seconds = 30
  message_retention_seconds  = 345600
  delay_seconds              = 0
}

output "sqs_queue_url" {
  value = aws_sqs_queue.sqs.id
}

output "sqs_queue_arn" {
  value = aws_sqs_queue.sqs.arn
}
