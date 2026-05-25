# AWS ML Data Ingestion & Serverless ETL Pipeline

An enterprise-grade, end-to-end data engineering pipeline designed to securely capture, isolate, and transform raw machine learning sensor telemetry streams into optimized analytical datasets.

## 🏗️ Architecture Blueprint
* **Ingestion Tier:** A Java 17 / Spring Boot microservice utilizing the official AWS SDK to securely generate cryptographic S3 Pre-signed URLs on-demand.
* **Client Simulation:** A lightweight Python telemetry generator that simulates real edge-device machinery metrics, handles the authentication handshake with the backend, and uploads raw CSV datasets directly to cloud storage.
* **Network Isolation:** Fully isolated custom AWS VPC infrastructure bounded by public/private subnets and tight network firewalls (NACLs).
* **Serverless Analytics Data Lake:** Integrated AWS Glue Data Catalog, automated schema discovery Crawlers, and PySpark processing workflows orchestrated via AWS Step Functions.

## 🛠️ Technology Stack
* **Backend:** Java 17, Spring Boot 3, Apache Maven, Python 3
* **Infrastructure as Code (IaC):** Terraform
* **Cloud Infrastructure (AWS):** VPC, S3, IAM, Glue Data Catalog, Glue Crawlers, Step Functions

## 🚀 Progress & Status
- [x] Phase 1: Core Custom Network VPC & NACL Security Shielding
- [x] Phase 2: S3 Landing Pad Ingestion via Spring Boot Pre-signed URL Handshakes
- [x] Phase 3: Python Client Ingestion Simulator & Raw S3 Live Landing
- [x] Phase 4: Serverless AWS Glue Data Catalog & Schema Crawler Infrastructure
- [ ] Phase 5: PySpark Transform Script & AWS Step Function Visual State Orchestration *(Next Up)*