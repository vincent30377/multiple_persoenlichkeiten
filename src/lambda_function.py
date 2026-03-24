# Autor: Silas Lachauer
# Datum: 24. März 2026
# Zweck: Erkennt bekannte Persönlichkeiten via AWS Rekognition

import boto3
import json
import os

def lambda_handler(event, context):
    rekognition = boto3.client('rekognition')
    s3 = boto3.client('s3')
    
    # 1. Informationen aus dem S3-Event holen
    bucket_in = event['Records'][0]['s3']['bucket']['name']
    image_key = event['Records'][0]['s3']['object']['key']
    
    # Name des Ziel-Buckets aus Umgebungsvariable lesen
    bucket_out = os.environ['OUT_BUCKET_NAME']
    
    try:
        # 2. AWS Rekognition aufrufen (Celebrity Recognition)
        # Quelle: https://docs.aws.amazon.com/rekognition/latest/dg/celebrities.html
        response = rekognition.recognize_celebrities(
            Image={'S3Object': {'Bucket': bucket_in, 'Name': image_key}}
        )
        
        # 3. Ergebnis als JSON formatieren
        result_json = json.dumps(response, indent=4)
        output_key = f"result-{image_key}.json"
        
        # 4. JSON im Out-Bucket speichern
        s3.put_object(
            Bucket=bucket_out,
            Key=output_key,
            Body=result_json,
            ContentType='application/json'
        )
        
        return {
            'statusCode': 200,
            'body': f"Erfolgreich: {output_key} erstellt."
        }
        
    except Exception as e:
        print(f"Fehler: {str(e)}")
        raise e