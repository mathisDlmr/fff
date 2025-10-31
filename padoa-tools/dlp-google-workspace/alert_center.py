#!/usr/bin/env python3
import json
import logging
import os
import sys
import time
from datetime import datetime, timedelta, timezone
from google.auth.transport.requests import Request
from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from zoneinfo import ZoneInfo

SCOPES= ["https://www.googleapis.com/auth/apps.alerts"]
PAGE_SIZE = 200
MAX_RETRIES = 3
RECENT_DELTA = timedelta(hours=2)

logger = logging.getLogger("alert_center")
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)

def _filter_alerts(alert):
    return {
        'alertId':    alert['alertId'],
        'createTime': alert['createTime'],
        'data': {
            'ruleViolationInfo': {
                'ruleInfo':     {'displayName': alert['data']['ruleViolationInfo']['ruleInfo']['displayName']}
            }
        }
    }

def _require_env(name):
    value = os.getenv(name)
    if not value:
        sys.exit(f"Variable d'environnement manquante : {name}")
    return value

def _load_credentials():
    raw = _require_env("SERVICE_ACCOUNT_JSON")
    try:
        info = json.loads(raw)
    except json.JSONDecodeError as exc:
        sys.exit(f"JSON invalide dans SERVICE_ACCOUNT_JSON : {exc}")
    try:
        creds = service_account.Credentials.from_service_account_info(info, scopes=SCOPES)
    except Exception as exc:
        sys.exit(f"Impossible de créer les Credentials : {exc}")

    delegated_email = _require_env("DELEGATED_EMAIL")
    creds = creds.with_subject(delegated_email)

    try:
        creds.refresh(Request())
    except Exception as exc:
        sys.exit(
            "Échec du refresh() – vérifiez la délégation domain-wide et les scopes."
        )
    return creds

def _build_service(creds):
    try:
        return build("alertcenter", "v1beta1", credentials=creds, cache_discovery=False)
    except Exception as exc:
        sys.exit(f"Impossible de construire le client Alert Center : {exc}")

def _execute_with_retries(request, retries = MAX_RETRIES):
    for attempt in range(1, retries + 1):
        try:
            return request.execute()
        except HttpError as exc:
            if exc.resp.status < 500 or attempt == retries:
                raise
            logger.warning("Erreur HTTP %s – tentative %s/%s", exc.resp.status, attempt, retries)
            sleep = 2 ** attempt
            logger.info("Nouvelle tentative dans %s s…", sleep)
            time.sleep(sleep)

def list_alerts(service):
    alerts = []
    req = service.alerts().list(pageSize=PAGE_SIZE)
    resp = _execute_with_retries(req)
    alerts.extend(resp.get("alerts", []))
    return alerts

def _is_recent_dlp(alert, delta = RECENT_DELTA):
    if alert.get("type") == "Data Loss Prevention":
        created = datetime.fromisoformat(alert["createTime"].replace("Z", "+00:00"))
        return datetime.now(timezone.utc) - created < delta
    else:
        return False

def main():
    try:
        creds = _load_credentials()
        service = _build_service(creds)
        alerts = list_alerts(service)
        recent_alerts = [_filter_alerts(a) for a in alerts if _is_recent_dlp(a)]

        if recent_alerts:
            for alert in recent_alerts:
                alert["createTime"] = str(datetime.fromisoformat(alert["createTime"].replace("Z", "+00:00")).astimezone(ZoneInfo("Europe/Paris")))
                print(json.dumps(alert), flush=True)
            logger.info("%s alerte(s) récente(s) affichée(s).", len(recent_alerts))
        else:
            logger.info("Aucune alerte récente.")
    except HttpError as exc:
        logger.error("Erreur API Google (%s): %s", exc.resp.status, exc)
        sys.exit(2)
    except Exception:
        logger.exception("Erreur inattendue")
        sys.exit(99)

if __name__ == "__main__":
    main()
