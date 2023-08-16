import json
import os
import requests

#Create a SSM Client to access parameter store
import boto3 
ssm = boto3.client('ssm') 


def lambda_handler(event,context):
    
    print(json.dumps(event))
    
    #Get message from event when Lambda function gets invoked by SNS
    message = json.loads(event['Records'][0]['Sns']['Message'])
    print(json.dumps(message))
    
    #Getting the variables from the JSON message
    alarm_name = message['AlarmName']
    new_state = message['NewStateValue']
    reason = message['NewStateReason']
    trigger = message['Trigger']['MetricName']
    description = message['AlarmDescription']

    #Generate message to pass to Discord
    discord_message =  [
        {
          "name": "Alarm name",
          "value": alarm_name,
        },
        {
          "name": "Alarm description",
          "value": description,
        },
        {
          "name": "Alarm state",
          "value": new_state,
          "inline" : True

        },
        {
          "name": "Alarm trigger",
          "value": trigger,
          "inline" : True

        },
        {
          "name": "Reason",
          "value": reason
        }
      ]
    

    discord_webhook_data = {
        'username': 'AWS',
        'avatar_url': 'https://i.imgflip.com/29s5ao.jpg',
        "content": os.environ['project_name'],
        'embeds': [{
            'title': ":rotating_light: AWS Alarm was triggered! :rotating_light:",
            'color': 15204352,
            'fields': discord_message
        }]
    }



    #Get Discrod Webhook from Parameter Store
    webhook_url = ssm.get_parameter(Name=os.environ['ssm_name'], WithDecryption=True)
    
    #make request and hopefully a notification will be appearing in your Discord channel 
    headers = {'content-type': 'application/json'}
    response = requests.post(webhook_url['Parameter']['Value'], data=json.dumps(discord_webhook_data),
                                 headers=headers)

    print("Status Code", response.status_code)
    
    return(response.status_code)

