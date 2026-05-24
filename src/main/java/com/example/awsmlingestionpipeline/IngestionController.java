package com.example.awsmlingestionpipeline;

import org.springframework.web.bind.annotation.*;
import org.springframework.http.ResponseEntity;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;
import software.amazon.awssdk.services.s3.presigner.model.PresignedPutObjectRequest;
import software.amazon.awssdk.services.s3.presigner.model.PutObjectPresignRequest;

import java.time.Duration;
import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/ingestion")
public class IngestionController {

    // TODO: Paste the exact unique bucket name printed by your Terraform output here!
    private final String bucketName = "ml-ingestion-pipeline-bucket-a66b3e5b";
    private final Region awsRegion = Region.US_EAST_1;

    @GetMapping("/presigned-url")
    public ResponseEntity<Map<String, String>> getPresignedUrl(@RequestParam("fileName") String fileName) {

        // 1. Initialize the cryptographic S3 Presigner engine
        // It automatically picks up the credentials you set in your 'aws configure' setup
        try (S3Presigner presigner = S3Presigner.builder()
                .region(awsRegion)
                .build()) {

            // 2. Define the target object destination rules inside the bucket
            PutObjectRequest objectRequest = PutObjectRequest.builder()
                    .bucket(bucketName)
                    .key("raw-uploads/" + fileName) // Organizes files inside a "raw-uploads" virtual directory
                    .contentType("text/csv")        // Locks down the upload format strictly to CSV data files
                    .build();

            // 3. Set the expiration timeout rule (e.g., URL link expires in 15 minutes)
            PutObjectPresignRequest presignRequest = PutObjectPresignRequest.builder()
                    .signatureDuration(Duration.ofMinutes(15))
                    .putObjectRequest(objectRequest)
                    .build();

            // 4. Generate the signed link artifact
            PresignedPutObjectRequest presignedRequest = presigner.presignPutObject(presignRequest);
            String uploadUrl = presignedRequest.url().toString();

            // 5. Structure the JSON map return response
            Map<String, String> response = new HashMap<>();
            response.put("fileName", fileName);
            response.put("uploadUrl", uploadUrl);
            response.put("targetBucket", bucketName);

            return ResponseEntity.ok(response);

        } catch (Exception e) {
            Map<String, String> errorResponse = new HashMap<>();
            errorResponse.put("error", "Failed to generate security token: " + e.getMessage());
            return ResponseEntity.internalServerError().body(errorResponse);
        }
    }
}