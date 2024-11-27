#!/bin/bash

# Variables
CSV_FILE="ec2_cost_summary.csv"
START_DATE=$(date -d '1 month ago' +%Y-%m-%d)
END_DATE=$(date +%Y-%m-%d)

# Initialize CSV File with Headers
echo "Usage Type,Account ID,Service,Amount (USD),Instance Type" > $CSV_FILE

# Get the list of accounts in the organization
ACCOUNT_IDS=$(aws organizations list-accounts --query 'Accounts[*].Id' --output text)

# Iterate over each account
for ACCOUNT_ID in $ACCOUNT_IDS
do
  echo "Processing account: $ACCOUNT_ID"
  
  # Get Cost and Usage data for EC2 instances
  COST_DATA=$(aws ce get-cost-and-usage \
    --time-period Start=$START_DATE,End=$END_DATE \
    --granularity MONTHLY \
    --filter '{"Dimensions": {"Key": "LINKED_ACCOUNT", "Values": ["'"$ACCOUNT_ID"'"]}}' \
    --metrics "UnblendedCost" \
    --group-by '[{"Type": "DIMENSION", "Key": "USAGE_TYPE"}, {"Type": "DIMENSION", "Key": "SERVICE"}]' \
    --output json)
  
  # Extract relevant data from COST_DATA using jq
  echo "$COST_DATA" | jq -c '.ResultsByTime[].Groups[]' | while read GROUP; do
    USAGE_TYPE=$(echo $GROUP | jq -r '.Keys[0]')
    SERVICE=$(echo $GROUP | jq -r '.Keys[1]')
    AMOUNT=$(echo $GROUP | jq -r '.Metrics.UnblendedCost.Amount')
    
    # Determine the instance type based on usage type
    if [[ $USAGE_TYPE == *"BoxUsage"* ]]; then
      INSTANCE_TYPE="On-Demand"
    elif [[ $USAGE_TYPE == *"Reserved"* ]]; then
      INSTANCE_TYPE="Reserved"
    else
      INSTANCE_TYPE="Other"
    fi
    
    # Only consider EC2-related services
    if [[ $SERVICE == "Amazon Elastic Compute Cloud - Compute" ]]; then
      echo "$USAGE_TYPE,$ACCOUNT_ID,$SERVICE,$AMOUNT,$INSTANCE_TYPE" >> $CSV_FILE
    fi
  done
done

echo "Cost summary has been saved to $CSV_FILE"
