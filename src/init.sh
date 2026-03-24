#!/bin/bash
# =================================================================
# Projekt: M346 Cloud-Lösungen - Face Recognition
# Autor: Vincent Haucke
# Beschreibung: Vollautomatisches Setup der AWS Ressourcen
# =================================================================
 
# 1. Definition der Variablen 
FUNCTION_NAME="FaceRecognitionHandler"
ROLE_ARN="arn:aws:iam::490789669163:role/LabRole"
REGION="us-east-1"
 
echo "--- Starte vollautomatisierte Installation ---"

echo "Räume alte Ressourcen auf..."
aws lambda delete-function --function-name $FUNCTION_NAME 2>/dev/null || true
# Wir ignorieren Fehler, falls die Funktion gar nicht existiert
 
# 2. S3 Buckets prüfen und ggf. erstellen
echo "Prüfe auf existierende Buckets..."

# Suche nach bereits existierenden Buckets im Account
EXISTING_IN=$(aws s3 ls | grep 'ims-face-in-' | awk '{print $3}' | head -n 1)
EXISTING_OUT=$(aws s3 ls | grep 'ims-face-out-' | awk '{print $3}' | head -n 1)

if [ -n "$EXISTING_IN" ]; then
    BUCKET_IN=$EXISTING_IN
    echo "-> Skript überspringt Erstellung: Verwende existierenden In-Bucket: $BUCKET_IN"
else
    BUCKET_IN="ims-face-in-$(date +%s)"
    echo "-> Erstelle neuen In-Bucket: $BUCKET_IN"
    aws s3 mb s3://$BUCKET_IN --region $REGION
fi

if [ -n "$EXISTING_OUT" ]; then
    BUCKET_OUT=$EXISTING_OUT
    echo "-> Skript überspringt Erstellung: Verwende existierenden Out-Bucket: $BUCKET_OUT"
else
    BUCKET_OUT="ims-face-out-$(date +%s)"
    echo "-> Erstelle neuen Out-Bucket: $BUCKET_OUT"
    aws s3 mb s3://$BUCKET_OUT --region $REGION
fi
 
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
    --timeout 15 \
    --region $REGION
 
# 5 Sekunden warten, damit AWS die Ressource registriert
sleep 5
 
# 5. S3-Berechtigung für Lambda setzen [cite: 68]
echo "Setze Berechtigungen..."
aws lambda add-permission \
    --function-name $FUNCTION_NAME \
    --statement-id "s3-invoke-perm-$(date +%s)" \
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