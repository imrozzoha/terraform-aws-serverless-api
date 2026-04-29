import json
import os
import boto3

SES = boto3.client('ses', region_name=os.environ.get('AWS_REGION', 'us-east-1'))
RECIPIENT = os.environ['RECIPIENT_EMAIL']
SENDER    = os.environ['SENDER_EMAIL']


def cors_headers(origin='*'):
    return {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': origin,
        'Access-Control-Allow-Headers': 'Content-Type',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
    }


def lambda_handler(event, context):
    if event.get('httpMethod') == 'OPTIONS':
        return {'statusCode': 200, 'headers': cors_headers(), 'body': ''}

    try:
        body = json.loads(event.get('body') or '{}')
        name    = body.get('name', '').strip()[:100]
        email   = body.get('email', '').strip()[:200]
        message = body.get('message', '').strip()[:2000]

        if not name or not email or not message:
            return {
                'statusCode': 400,
                'headers': cors_headers(),
                'body': json.dumps({'error': 'name, email, and message are required'}),
            }

        SES.send_email(
            Source=SENDER,
            Destination={'ToAddresses': [RECIPIENT]},
            Message={
                'Subject': {'Data': f'Contact form: {name}'},
                'Body': {
                    'Text': {
                        'Data': f'From: {name} <{email}>\n\n{message}'
                    }
                },
            },
            ReplyToAddresses=[email],
        )

        return {
            'statusCode': 200,
            'headers': cors_headers(),
            'body': json.dumps({'success': True}),
        }

    except Exception as e:
        print(f'Error: {e}')
        return {
            'statusCode': 500,
            'headers': cors_headers(),
            'body': json.dumps({'error': 'Failed to send message'}),
        }
