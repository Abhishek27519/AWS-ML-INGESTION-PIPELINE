import boto3
import json

# Connect to the live SageMaker Runtime
client = boto3.client('sagemaker-runtime', region_name='us-east-1')

# This is our fake sensor reading: Temperature = 65.5, Vibration = 0.12
# We format it exactly how we trained it (CSV without headers)
payload = "65.5,0.12"

print(f"Sending real-time sensor data to AI: {payload}")

# Ping the live endpoint
response = client.invoke_endpoint(
    EndpointName='sensor-production-endpoint',
    ContentType='text/csv',
    Body=payload
)

# Decode the AI's prediction
result = json.loads(response['Body'].read().decode())
print("\n🎉 AI Prediction Received 🎉")
print(json.dumps(result, indent=2))