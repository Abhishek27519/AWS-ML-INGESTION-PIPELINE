import csv
import random
import time
import requests

# Configuration
SPRING_BOOT_URL = "http://localhost:8080/api/ingestion/presigned-url"
FILE_NAME = "sensor_data.csv"

def generate_mock_data(filename):
    print(f"Generating mock ML sensor data: {filename}...")
    # This matches typical manufacturing machine sensor metrics
    columns = ["timestamp", "sensor_id", "temperature", "vibration", "pressure", "status"]

    with open(filename, mode='w', newline='') as file:
        writer = csv.writer(file)
        writer.writerow(columns)

        # Generate 100 rows of fake sensor telemetry
        base_time = int(time.time())
        for i in range(100):
            timestamp = base_time + i
            sensor_id = f"SENSOR_{random.randint(101, 105)}"
            temperature = round(random.uniform(65.0, 120.0), 2)
            vibration = round(random.uniform(0.1, 4.5), 2)
            pressure = round(random.uniform(15.0, 50.0), 2)
            # Introduce occasional messy data (None/missing values) for AWS Glue to clean tomorrow!
            status = "NORMAL" if random.random() > 0.1 else ""

            writer.writerow([timestamp, sensor_id, temperature, vibration, pressure, status])
    print("Mock data generated successfully.")

def upload_file_via_presigned_url(filename):
    try:
        # 1. Fetch the cryptographic Pre-signed URL from your Spring Boot App
        print(f"Requesting secure token from Spring Boot for {filename}...")
        response = requests.get(SPRING_BOOT_URL, params={"fileName": filename})
        response.raise_for_status()

        payload = response.json()
        upload_url = payload["uploadUrl"]
        print("Secure upload token acquired from backend.")

        # 2. Upload the file directly to S3 using the Pre-signed URL
        print("Uploading file directly to AWS S3...")
        with open(filename, 'rb') as file_data:
            headers = {'Content-Type': 'text/csv'}
            upload_response = requests.put(upload_url, data=file_data, headers=headers)
            upload_response.raise_for_status()

        print("Success! File uploaded directly to S3 landing pad securely.")

    except requests.exceptions.RequestException as e:
        print(f"Pipeline error: {e}")

if __name__ == "__main__":
    generate_mock_data(FILE_NAME)
    upload_file_via_presigned_url(FILE_NAME)