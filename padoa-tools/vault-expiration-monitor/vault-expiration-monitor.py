import os
import hvac
import requests
from dateutil.parser import parse
from datetime import datetime
import logging
import sys
import json

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    stream=sys.stdout
)
logger = logging.getLogger()

VAULT_ADDR = os.getenv('VAULT_ADDR')
VAULT_TOKEN = os.getenv('VAULT_TOKEN')
NOTIFICATION_WEBHOOK = os.getenv('NOTIFICATION_WEBHOOK') #default slack webhook for gesfin: channel void for now
NOTIFICATION_WEBHOOK_GESFIN = os.getenv('NOTIFICATION_WEBHOOK_GESFIN')  #slack webhook for gesfin: fargo-prod-alerts
NOTION_URL = os.getenv("NOTION_URL", "")
SECRET_PATHS = [p.strip() for p in os.getenv('SECRET_PATHS', '').split(',') if p.strip()]
VAULT_MOUNT_POINT = os.getenv('VAULT_MOUNT_POINT', 'secret')

# Notification thresholds in days: before three months + two months + before one month , before two weeks and then before one week
NOTIFY_DAYS = [90, 60, 30, 14, 7]

def send_alert(message, secret_path=None):  # Modified to accept secret_path
    """Send alert to Slack, using gesfin webhook if path contains 'gesfin'"""
    full_message = f"🔴 *CRITICAL*: {message}"
    if NOTION_URL and (secret_path is None or "gesfin" not in secret_path.lower()):
       full_message += f"\n<{NOTION_URL}|📘 View Documentation>"
    # Determine webhook based on path
    webhook_url = NOTIFICATION_WEBHOOK
    if secret_path and "gesfin" in secret_path.lower():
        if NOTIFICATION_WEBHOOK_GESFIN:
            webhook_url = NOTIFICATION_WEBHOOK_GESFIN
            logger.info("Using GESFIN webhook for notification")
        else:
            logger.warning("GESFIN path detected but NOTIFICATION_WEBHOOK_GESFIN not set! Using default webhook")

    if webhook_url:
        try:
            logger.info(f"Attempting to send Slack alert: {message}")
            payload = {"text": full_message}
            response = requests.post(
                webhook_url,
                json=payload,
                timeout=10,
                headers={'Content-Type': 'application/json'}
            )

            if response.status_code != 200:
                logger.error(f"Slack API error: {response.status_code} - {response.text}")
            else:
                logger.info("Slack notification sent successfully")

        except requests.exceptions.Timeout:
            logger.error("Slack request timed out after 10 seconds")
        except requests.exceptions.RequestException as e:
            logger.error(f"Slack connection error: {str(e)}")
        except Exception as e:
            logger.error(f"Unexpected error sending to Slack: {str(e)}")
    else:
        logger.info(f"Slack webhook not configured. Alert: {full_message}")

def check_secret_expiry():
    logger.info(f"\n=== Starting Vault Check at {datetime.now().isoformat()} ===")
    logger.info(f"VAULT_ADDR: {VAULT_ADDR}")
    logger.info(f"MOUNT_POINT: {VAULT_MOUNT_POINT}")
    logger.info(f"SECRET_PATHS: {SECRET_PATHS}")

    # Log webhook configurations
    if NOTIFICATION_WEBHOOK:
        logger.info(f"Default Slack webhook configured: {NOTIFICATION_WEBHOOK[:15]}...{NOTIFICATION_WEBHOOK[-10:]}")
    else:
        logger.warning("No default Slack webhook URL configured - alerts will only be logged")
    
    if NOTIFICATION_WEBHOOK_GESFIN:  # Log gesfin webhook status
        logger.info(f"GESFIN Slack webhook configured: {NOTIFICATION_WEBHOOK_GESFIN[:15]}...{NOTIFICATION_WEBHOOK_GESFIN[-10:]}")
    else:
        logger.warning("No GESFIN Slack webhook URL configured - gesfin alerts will use default channel")

    if not VAULT_ADDR or not VAULT_TOKEN:
        error_msg = "VAULT_ADDR or VAULT_TOKEN environment variables not set!"
        logger.error(error_msg)
        send_alert(f"Vault configuration error: {error_msg}")
        return

    try:
        client = hvac.Client(url=VAULT_ADDR, token=VAULT_TOKEN)

        if not client.is_authenticated():
            logger.error(" Vault authentication failed")
            send_alert("Vault authentication failed")
            return

        logger.info(" Vault authentication successful")
        today = datetime.now().date()
        processed_secrets = set()

        for raw_path in SECRET_PATHS:
            path = raw_path.strip().lstrip('/')
            if not path:
                continue

            logger.info(f"\n Processing path: '{path}'")

            try:
                list_response = client.secrets.kv.v2.list_secrets(
                    path=path,
                    mount_point=VAULT_MOUNT_POINT
                )
                keys = list_response['data']['keys']
                logger.info(f"Found {len(keys)} items in directory")

                for key in keys:
                    new_path = f"{path.rstrip('/')}/{key}"
                    if key.endswith('/'):
                        process_path(client, new_path, today, processed_secrets)
                    elif new_path not in processed_secrets:
                        check_single_secret(client, new_path, today)
                        processed_secrets.add(new_path)

            except hvac.exceptions.InvalidPath:
                logger.info(f"Path not a directory, trying as secret: '{path}'")
                if path not in processed_secrets:
                    check_single_secret(client, path, today)
                    processed_secrets.add(path)

            except Exception as e:
                logger.error(f"Error processing path '{path}': {str(e)}")
                send_alert(f"Error processing Vault path '{path}': {str(e)}", path)  # Pass path to send_alert

        logger.info(f"\n Checked {len(processed_secrets)} secrets total")

    except Exception as e:
        error_msg = f"Vault connection error: {str(e)}"
        logger.exception(error_msg)
        send_alert(error_msg)

def process_path(client, path, today, processed_secrets):
    """Process a path as a directory (list secrets within it)"""
    try:
        list_response = client.secrets.kv.v2.list_secrets(
            path=path,
            mount_point=VAULT_MOUNT_POINT
        )
        keys = list_response['data']['keys']
        logger.info(f"  Found {len(keys)} items in subdirectory")

        for key in keys:
            new_path = f"{path.rstrip('/')}/{key}"
            if key.endswith('/'):
                process_path(client, new_path, today, processed_secrets)
            elif new_path not in processed_secrets:
                check_single_secret(client, new_path, today)
                processed_secrets.add(new_path)

    except hvac.exceptions.InvalidPath:
        logger.error(f" Path not found: {path}")
    except hvac.exceptions.Forbidden:
        logger.error(f" Permission denied for path: {path}")
        send_alert(f"Permission denied accessing Vault path: {path}", path)  # Pass path to send_alert
    except Exception as e:
        logger.error(f"  Error processing path '{path}': {str(e)}")
        send_alert(f"Error processing Vault path '{path}': {str(e)}", path)  # Pass path to send_alert

def check_single_secret(client, full_path, today):
    try:
        logger.info(f"  Checking secret: '{full_path}'")

        metadata = client.secrets.kv.v2.read_secret_metadata(
            path=full_path,
            mount_point=VAULT_MOUNT_POINT
        )

        # Extract custom metadata: expire : year-month-days
        custom_metadata = metadata['data'].get('custom_metadata', {})
        expiration_str = custom_metadata.get('expire')

        if not expiration_str:
            logger.info(f" No expiration date for '{full_path}'")
            return

        expiration = parse(expiration_str).date()
        days_to_expiry = (expiration - today).days

        if days_to_expiry < 0:
            alert = f"Secret '{full_path}' EXPIRED {abs(days_to_expiry)} days ago!"
            logger.warning(f"    ‼️ {alert}")
            send_alert(f"Secret `{full_path}` expired {abs(days_to_expiry)} days ago on {expiration.strftime('%Y-%m-%d')}", full_path)  # Pass path
        elif days_to_expiry in NOTIFY_DAYS:
            alert = f"'{full_path}' expires in {days_to_expiry} days"
            logger.warning(f"    ⚠️ {alert}")
            send_alert(f"Secret `{full_path}` expires in {days_to_expiry} days on {expiration.strftime('%Y-%m-%d')}", full_path)  # Pass path
        else:
            logger.info(f"    ✅ '{full_path}' valid for {days_to_expiry} days")

    except hvac.exceptions.Forbidden:
        logger.error(f"     Permission denied for secret: '{full_path}'")
        send_alert(f"Permission denied accessing Vault secret: {full_path}", full_path)  # Pass path
    except hvac.exceptions.InvalidPath:
        logger.error(f"    Secret not found: '{full_path}'")
        send_alert(f"Vault secret not found: {full_path}", full_path)  # Pass path
    except Exception as e:
        logger.error(f"    Error checking secret '{full_path}': {str(e)}")
        send_alert(f"Error checking Vault secret '{full_path}': {str(e)}", full_path)  # Pass path

if __name__ == "__main__":
    try:
        check_secret_expiry()
        logger.info("\n Check completed successfully")
    except Exception as e:
        error_msg = f"\n Fatal error: {str(e)}"
        logger.exception(error_msg)
        send_alert(f"Vault expiry check failed: {str(e)}")
