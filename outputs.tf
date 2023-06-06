output "splunk_public_ip" {
  value = aws_eip.splunk_public_ip.public_ip
}

output "splunk_default_username" {
  value = "admin"
}

output "splunk_default_password" {
  value = "SPLUNK-${aws_instance.splunk.id}"
}


