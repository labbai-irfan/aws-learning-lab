#!/usr/bin/env bash
# Create the HRMS severity-tiered alarm set + composite user-impact alarm.
# Prereq: SNS topics ops-page (Sev1) and ops-notify (Sev2) exist.
# Replace ACCT, the ALB/target-group suffixes, instance id, and DB id before running.
set -euo pipefail

ACCT="111122223333"
REGION="us-east-1"
PAGE="arn:aws:sns:${REGION}:${ACCT}:ops-page"
NOTIFY="arn:aws:sns:${REGION}:${ACCT}:ops-notify"
ALB="app/hrms/abc"
TG="targetgroup/hrms/xyz"
EC2="i-0abc"
DB="hrms-db"

echo "== Sev1: ALB 5xx rate via metric math =="
aws cloudwatch put-metric-alarm --alarm-name hrms-api-5xx-high \
  --comparison-operator GreaterThanThreshold --threshold 1 \
  --evaluation-periods 3 --datapoints-to-alarm 2 --treat-missing-data notBreaching \
  --alarm-actions "$PAGE" --ok-actions "$PAGE" \
  --metrics '[
    {"Id":"r","MetricStat":{"Metric":{"Namespace":"AWS/ApplicationELB","MetricName":"RequestCount","Dimensions":[{"Name":"LoadBalancer","Value":"'"$ALB"'"}]},"Period":300,"Stat":"Sum"},"ReturnData":false},
    {"Id":"e","MetricStat":{"Metric":{"Namespace":"AWS/ApplicationELB","MetricName":"HTTPCode_Target_5XX_Count","Dimensions":[{"Name":"LoadBalancer","Value":"'"$ALB"'"}]},"Period":300,"Stat":"Sum"},"ReturnData":false},
    {"Id":"rate","Expression":"100*(e/r)","Label":"5xx %","ReturnData":true}]'

echo "== Sev2: p99 latency =="
aws cloudwatch put-metric-alarm --alarm-name hrms-api-latency-high \
  --namespace AWS/ApplicationELB --metric-name TargetResponseTime \
  --dimensions Name=LoadBalancer,Value="$ALB" \
  --extended-statistic p99 --period 300 --threshold 1 \
  --comparison-operator GreaterThanThreshold --evaluation-periods 3 --datapoints-to-alarm 2 \
  --treat-missing-data notBreaching --alarm-actions "$NOTIFY"

echo "== Sev1: unhealthy hosts =="
aws cloudwatch put-metric-alarm --alarm-name hrms-unhealthy-hosts \
  --namespace AWS/ApplicationELB --metric-name UnHealthyHostCount \
  --dimensions Name=TargetGroup,Value="$TG" Name=LoadBalancer,Value="$ALB" \
  --statistic Maximum --period 60 --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold --evaluation-periods 2 \
  --treat-missing-data breaching --alarm-actions "$PAGE"

echo "== Sev1: EC2 system status check -> auto-recover =="
aws cloudwatch put-metric-alarm --alarm-name hrms-ec2-autorecover \
  --namespace AWS/EC2 --metric-name StatusCheckFailed_System \
  --dimensions Name=InstanceId,Value="$EC2" --statistic Maximum --period 60 \
  --threshold 1 --comparison-operator GreaterThanOrEqualToThreshold --evaluation-periods 2 \
  --alarm-actions "arn:aws:automate:${REGION}:ec2:recover" "$PAGE"

echo "== Sev2: EC2 disk =="
aws cloudwatch put-metric-alarm --alarm-name hrms-ec2-disk-high \
  --namespace CWAgent --metric-name disk_used_percent \
  --dimensions Name=InstanceId,Value="$EC2" Name=path,Value=/ \
  --statistic Average --period 300 --threshold 85 \
  --comparison-operator GreaterThanThreshold --evaluation-periods 2 --alarm-actions "$NOTIFY"

echo "== Sev2: EC2 memory =="
aws cloudwatch put-metric-alarm --alarm-name hrms-ec2-mem-high \
  --namespace CWAgent --metric-name mem_used_percent \
  --dimensions Name=InstanceId,Value="$EC2" \
  --statistic Average --period 300 --threshold 85 \
  --comparison-operator GreaterThanThreshold --evaluation-periods 3 --alarm-actions "$NOTIFY"

echo "== Sev1: RDS low storage =="
aws cloudwatch put-metric-alarm --alarm-name hrms-db-low-storage \
  --namespace AWS/RDS --metric-name FreeStorageSpace \
  --dimensions Name=DBInstanceIdentifier,Value="$DB" \
  --statistic Average --period 300 --threshold 5000000000 \
  --comparison-operator LessThanThreshold --evaluation-periods 1 --alarm-actions "$PAGE"

echo "== Sev2: RDS CPU / connections =="
aws cloudwatch put-metric-alarm --alarm-name hrms-db-cpu-high \
  --namespace AWS/RDS --metric-name CPUUtilization \
  --dimensions Name=DBInstanceIdentifier,Value="$DB" \
  --statistic Average --period 300 --threshold 80 \
  --comparison-operator GreaterThanThreshold --evaluation-periods 3 --alarm-actions "$NOTIFY"

aws cloudwatch put-metric-alarm --alarm-name hrms-db-connections-high \
  --namespace AWS/RDS --metric-name DatabaseConnections \
  --dimensions Name=DBInstanceIdentifier,Value="$DB" \
  --statistic Maximum --period 60 --threshold 250 \
  --comparison-operator GreaterThanThreshold --evaluation-periods 2 --alarm-actions "$NOTIFY"

echo "== Sev1: COMPOSITE user-impact (5xx AND latency) =="
aws cloudwatch put-composite-alarm --alarm-name hrms-user-impact \
  --alarm-rule "ALARM(\"hrms-api-5xx-high\") AND ALARM(\"hrms-api-latency-high\")" \
  --alarm-actions "$PAGE"

echo "Done. Review in the CloudWatch console > Alarms."
