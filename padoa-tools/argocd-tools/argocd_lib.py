import subprocess
import os
import yaml
from time import sleep
import requests

# The content of this cookie will be checked later
ARGOCD_TOKEN = os.getenv('COOKIE_ARGOCD_TOKEN')
ARGOCD_URL = os.getenv('ARGOCD_URL', 'https://argocd.aodap-dev.fr')


class bcolors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'


def fail(content):
    print(bcolors.FAIL + content + bcolors.ENDC)
    exit(1)


def bold_print(content):
    print(bcolors.BOLD + content + bcolors.ENDC)


def green_print(content):
    print(bcolors.OKGREEN + content + bcolors.ENDC)


def get_user():
    user = login_call("session/userinfo")
    if 'username' in user:
        return user
    else:
        print(user)
        need_reconnect_then_exit()


def login_call(api_object, requester=requests.get, params=None, jsonData=None):
    if ARGOCD_TOKEN is None:
        need_reconnect_then_exit()

    cookies = {'argocd.token': f"{ARGOCD_TOKEN}"}
    result = requester(f"{ARGOCD_URL}/api/v1/{api_object}", cookies=cookies, params=params, json=jsonData)
    if result.status_code == 200:
        for c in result.cookies:
            print(c.name, c.value)
        return result.json()
    else:
        need_reconnect_then_exit()


def need_reconnect_then_exit():
    print(f"---> You need to connect to {bcolors.OKBLUE}{ARGOCD_URL}")
    print(f"{bcolors.FAIL}Exiting ...")
    exit(1)
