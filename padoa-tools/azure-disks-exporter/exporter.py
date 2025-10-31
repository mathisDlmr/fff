import os
import json
import requests
from azure.identity import ClientSecretCredential
from azure.mgmt.compute import ComputeManagementClient
from urllib.parse import quote

ESTIMATED_COST_PER_GB_PER_MONTH=0.09

def get_unowned_disks(subscription_id):
    """
    Fetch disks without owners from the Azure subscription,
    excluding those in prod-critical-persistant resource group.
    """
    credential = ClientSecretCredential(
        tenant_id=os.getenv("AZURE_TENANT_ID"),
        client_id=os.getenv("AZURE_CLIENT_ID"),
        client_secret=os.getenv("AZURE_CLIENT_SECRET"),
    )
    compute_client = ComputeManagementClient(credential, subscription_id)

    excluded_resource_groups = {"prod-critical-persistent", "PROD-CRITICAL-PERSISTENT"}
    unowned_disks = []

    for disk in compute_client.disks.list():
        resource_group = disk.id.split("/")[4]
        if not disk.managed_by and resource_group not in excluded_resource_groups:
            unowned_disks.append({
                "id": disk.id,
                "name": disk.name,
                "location": disk.location,
                "size_gb": disk.disk_size_gb,
                "estimated_cost": round(disk.disk_size_gb * ESTIMATED_COST_PER_GB_PER_MONTH, 2),
                "resource_group": resource_group,
                "subscription_id": subscription_id
            })

    return unowned_disks

from urllib.parse import quote

def format_disk_link(subscription_id, resource_group, disk_name):
    return (
        f"https://portal.azure.com/#@padoa-group.com/resource/subscriptions/"
        f"{quote(subscription_id)}/resourceGroups/"
        f"{quote(resource_group)}/providers/Microsoft.Compute/disks/"
        f"{quote(disk_name)}/overview"
    )

def generate_blocks(disks_by_env, doc_link):
    blocks = [
        {
            "type": "header",
            "text": {
                "type": "plain_text",
                "text": "💾 Unattached Disks Report",
                "emoji": True
            }
        },
        {"type": "divider"}
    ]

    for env, disks in disks_by_env.items():
        total_cost = round(sum(disk['estimated_cost'] for disk in disks), 2)
        blocks.append({
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": f"{':warning:' if disks else ':white_check_mark:'} *{env.upper()}* - {len(disks)} ({total_cost}$/m) unattached disks"
            }
        })

        if disks:
            disks.sort(key=lambda x: x['estimated_cost'], reverse=True)
            disk_items = []
            for disk in disks:
                link = format_disk_link(
                    disk['subscription_id'],
                    disk['resource_group'],
                    disk['name']
                )
                disk_items.append(f"• <{link}|{disk['name']}> ({disk['size_gb']}GB - {disk['estimated_cost']}$/m)")

            max_length = 2800
            current_chunk = []
            current_length = 0
            
            for item in disk_items:
                item_length = len(item)
                if current_length + item_length > max_length:
                    blocks.append({
                        "type": "section",
                        "text": {
                            "type": "mrkdwn",
                            "text": "\n".join(current_chunk)
                        }
                    })
                    current_chunk = [item]
                    current_length = item_length
                else:
                    current_chunk.append(item)
                    current_length += item_length

            if current_chunk:
                blocks.append({
                    "type": "section",
                    "text": {
                        "type": "mrkdwn",
                        "text": "\n".join(current_chunk)
                    }
                })
        else:
            blocks.append({
                "type": "context",
                "elements": [{
                    "type": "mrkdwn",
                    "text": "_No unattached disks found_"
                }]
            })

        blocks.append({"type": "divider"})

    blocks.append({
        "type": "section",
        "text": {
            "type": "mrkdwn",
            "text": f":book: *Cleanup Guide:* <{doc_link}|Click here for documentation>"
        }
    })

    if len(blocks) > 50:
        raise ValueError(f"Slack block limit exceeded (50 max, got {len(blocks)})")

    return blocks

def send_slack_notification(webhook_url, disks_by_env, doc_link):
    try:
        blocks = generate_blocks(disks_by_env, doc_link)
        
        payload_str = json.dumps({"blocks": blocks})
        if len(payload_str) > 40000:
            raise ValueError("Payload size exceeds Slack's 40KB limit")

        response = requests.post(
            webhook_url,
            json={"blocks": blocks},
            headers={"Content-Type": "application/json"},
            timeout=10
        )

        if response.status_code != 200:
            error_info = response.text
            try:
                slack_error = json.loads(response.text)
                error_info = slack_error.get('response_metadata', {}).get('messages', ['Unknown error'])[0]
            except:
                pass
            raise ValueError(f"Slack API Error ({response.status_code}): {error_info}")

    except Exception as e:
        raise RuntimeError(f"Notification failed: {str(e)}") from e


def main():
    dev_subscription_id = os.getenv("AZURE_DEV_SUBSCRIPTION_ID")
    staging_subscription_id = os.getenv("AZURE_STAGING_SUBSCRIPTION_ID")
    prod_subscription_id = os.getenv("AZURE_PROD_SUBSCRIPTION_ID")
    slack_webhook_url = os.getenv("SLACK_WEBHOOK_URL")
    doc_link = os.getenv("DOC_LINK")

    if not (dev_subscription_id and staging_subscription_id and prod_subscription_id and slack_webhook_url and doc_link):
        raise ValueError("Missing required environment variables.")

    subscriptions = {
        "dev": dev_subscription_id,
        "staging": staging_subscription_id,
        "prod": prod_subscription_id
    }

    disks_by_env = {}
    for env, subscription_id in subscriptions.items():
        disks_by_env[env] = get_unowned_disks(subscription_id)

    send_slack_notification(slack_webhook_url, disks_by_env, doc_link)


if __name__ == "__main__":
    main()
