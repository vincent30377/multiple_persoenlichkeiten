#!/bin/bash
# =================================================================
# Projekt: M346 Cloud-Lösungen - Face Recognition
# Autor: Vincent Haucke
# Beschreibung: Vollautomatisches Setup der AWS Ressourcen
# =================================================================
 
# 1. Definition der Variablen 
# Nutze einen Zeitstempel, damit die Bucket-Namen weltweit eindeutig sind
ID_SUFFIX=$(date +%s)
BUCKET_IN="ims-face-in-$ID_SUFFIX"
BUCKET_OUT="ims-face-out-$ID_SUFFIX"
FUNCTION_NAME="FaceRecognitionHandler"
ROLE_ARN="arn:aws:iam::490789669163:role/LabRole"
REGION="us-east-1"
 
echo "--- Starte vollautomatisierte Installation ---"
 
# 2. S3 Buckets erstellen [cite: 20, 68]
echo "Erstelle Buckets..."
aws s3 mb s3://$BUCKET_IN --region $REGION
aws s3 mb s3://$BUCKET_OUT --region $REGION
 
# 3. Lambda-Code vorbereiten
echo "Verpacke Lambda-Code..."
zip function.zip lambda_function.py
 
# 4. Lambda-Funktion hochladen [cite: 68]
echo "Erstelle Lambda-Funktion..."
aws lambda create-function \
    --function-name $FUNCTION_NAME \
    --runtime python3.9 \
    --handler lambda_function.lambda_handler \
    --role $ROLE_ARN \
    --zip-file fileb://function.zip \
    --environment "Variables={OUT_BUCKET_NAME=$BUCKET_OUT}" \
    --region $REGION
 
# 5 Sekunden warten, damit AWS die Ressource registriert
sleep 5
 
# 5. S3-Berechtigung für Lambda setzen [cite: 68]
echo "Setze Berechtigungen..."
aws lambda add-permission \
    --function-name $FUNCTION_NAME \
    --statement-id s3-invoke-perm \
    --action "lambda:InvokeFunction" \
    --principal s3.amazonaws.com \
    --source-arn "arn:aws:s3:::$BUCKET_IN" \
    --region $REGION
 
# 6. S3-Trigger (Event Notification) konfigurieren [cite: 20, 69]
echo "Konfiguriere S3-Trigger..."
LAMBDA_ARN=$(aws lambda get-function --function-name $FUNCTION_NAME --query 'Configuration.FunctionArn' --output text)
 
cat <<EOF > notification.json
{
  "LambdaFunctionConfigurations": [
    {
      "LambdaFunctionArn": "$LAMBDA_ARN",
      "Events": ["s3:ObjectCreated:*"]
    }
  ]
}
EOF
 
aws s3api put-bucket-notification-configuration \
    --bucket $BUCKET_IN \
    --notification-configuration file://notification.json
 
echo "--- Installation erfolgreich beendet ---"
echo "In-Bucket:  $BUCKET_IN"
echo "Out-Bucket: $BUCKET_OUT"