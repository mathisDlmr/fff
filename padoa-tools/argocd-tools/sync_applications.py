#! /usr/bin/env python

import subprocess
import os
import json
from threading import Thread

ARGOCD_TOKEN = os.getenv('COOKIE_ARGOCD_TOKEN')
ARGOCD_URL = os.getenv('ARGOCD_URL', 'https://argocd.aodap-dev.fr')
REPO_URL = os.getenv('REPO_URL')
TARGET_REVISION = os.getenv('TARGET_REVISION')

error_report = set()
sync_report = set()

def argocd_cli_call(cmd, output=""):
    out = "" if output == "" else ["-o", output]
    cmd = ["/usr/local/bin/argocd", *cmd, *out, "--auth-token", ARGOCD_TOKEN, "--server",
           ARGOCD_URL.replace('https://', ''), "--grpc-web"]
    p = subprocess.run(cmd, capture_output=True)
    result = p.stdout.decode()
    if p.returncode != 0:
        raise Exception(f"Error launching {cmd} \n {result} \n {p.stderr.decode()}")
    return result


def sync_app(app_to_sync):
    global error_report
    try:
        print(f'Syncing {app_to_sync}')
        argocd_cli_call(["app", "sync", "--retry-backoff-duration", "1m", "--retry-limit", "10"] + [app_to_sync])
        sync_report.add(app_to_sync)
        print(f'{app_to_sync} synced')
        return True
    except Exception as e:
        print(e)
        error_report.add(app_to_sync)
        return False


if __name__ == "__main__":
    print(f'Listing apps watching {REPO_URL} on branch {TARGET_REVISION}')
    apps = json.loads(argocd_cli_call(["app", "list", "-o", "json"]))
    apps_to_sync = set()
    for app in apps:
        meta = app["metadata"]
        spec = app["spec"]
        if (
            "github_action" in meta["labels"] and meta["labels"]["github_action"] == "sync" and
            spec["source"]["repoURL"] == REPO_URL and spec["source"]["targetRevision"] == TARGET_REVISION
        ):
            apps_to_sync.add(meta["name"])
    print(f'{len(apps_to_sync)}/{len(apps)} apps to sync: {apps_to_sync}')
    if len(apps_to_sync) > 0:
        orders = [Thread(target=sync_app, args=[app_to_sync]) for app_to_sync in apps_to_sync]
        for order in orders:
            order.start()
        for order in orders:
            order.join()
        print(f'These apps synced: {sync_report if len(sync_report) >= 1 else "{}"}')
        if len(error_report) >= 1 or len(sync_report) < len(apps_to_sync):
            print(f'These apps failed to sync: {error_report}')
            exit(1)
