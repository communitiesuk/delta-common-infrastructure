output "queue_url" { value = aws_sqs_queue.email.url }
output "dead_letter_queue_url" { value = aws_sqs_queue.dead_letter.url }
