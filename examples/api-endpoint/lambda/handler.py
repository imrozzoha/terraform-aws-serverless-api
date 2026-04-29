import json


def cors_headers():
    return {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
    }


def lambda_handler(event, context):
    if event.get('httpMethod') == 'OPTIONS':
        return {'statusCode': 200, 'headers': cors_headers(), 'body': ''}

    body = json.loads(event.get('body') or '{}')
    name = body.get('name', 'world')

    return {
        'statusCode': 200,
        'headers': cors_headers(),
        'body': json.dumps({'message': f'Hello, {name}!'}),
    }
