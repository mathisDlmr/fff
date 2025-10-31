#! /usr/bin/env python
import os
from github import Github, GithubException, Repository
import yaml
import base64
import re

from constants import STACK_TYPE_TO_STACK_FOLDER, DEV_APPS_REPO_DEFAULT_BRANCH

APPENDED_FILES = ['pr-information.yaml']
GITHUB_TOKEN = os.environ['GITHUB_TOKEN']
g = Github(GITHUB_TOKEN)
padoa_helm_repo = g.get_repo('padoa/padoa-helm-repo')
padoa_main_secrets = g.get_repo('padoa/padoa-main-secrets')
dev_apps_repo = g.get_repo('padoa/dev-apps')


def build_dev_app_file_path(stack_folder: str, stack_name: str, is_deleted=False) -> str:
    deleted_folder = '/deleted' if is_deleted else ''
    return f'all-dev-apps/stacks/{stack_folder}{deleted_folder}/{stack_name}.yaml'


def build_github_file_https_path(repo_name: str, file_path: str, branch_name=DEV_APPS_REPO_DEFAULT_BRANCH) -> str:
    return f'https://github.com/padoa/{repo_name}/blob/{branch_name}/{file_path}'


def branch_exists(site: Repository, branch_name: str):
    if len(branch_name) == 0:
        return False
    try:
        site.get_branch(branch_name)
        return True
    except GithubException as e:
        if e.status == 404:
            return False
        print(f"Could not determine if {branch_name} exists:")
        raise GithubException(e)


def create_branch(site: Repository, branch_name: str):
    return site.create_git_ref(
        'refs/heads/{branch_name}'.format(**locals()),
        site.get_branch('master').commit.sha
    )


def change_or_create_secret(site: Repository, branch_name: str, new_secrets):
    # Downloading files from github
    secrets_file_gh = site.get_contents(
        path='main-secrets/secrets.yaml',
        ref=branch_name
    )
    secret_file = base64.b64decode(secrets_file_gh.content).decode("utf-8").replace('\\n', '\n')

    # Writing files on the machine, prepping for sops
    with open("secrets.yaml", "w+") as f:
        f.write(secret_file)

    # Current decrypted secrets on master
    os.system("sops -d secrets.yaml > secrets-dec.yaml")

    # Add new secrets to old secrets
    with open("secrets-dec.yaml") as f:
        secrets = yaml.load(f, Loader=yaml.FullLoader)

    for new_secret in new_secrets:
        secrets["secrets"][new_secret["key"]] = new_secret["value"]

    # Encrypt secrets
    with open("secrets-dec.yaml", "w+") as f:
        yaml.dump(secrets, f)
        os.system("sops -e secrets-dec.yaml > secrets.yaml && rm secrets-dec.yaml")

    with open("secrets.yaml", "r") as f:
        return site.update_file(
            path=f'main-secrets/secrets.yaml',
            message=f'Updated secrets for branch {branch_name}: added {[secret["key"] for secret in new_secrets]}',
            sha=secrets_file_gh.sha,
            content=f.read(),
            branch=branch_name
        )


def create_pull_request(site: Repository, branch_name: str, description="# Custom description here"):
    return site.create_pull(
        title=f"Stack: {branch_name}",
        body=(
            description
        ),
        draft=True,
        base="master",
        head=branch_name
    )


def github_create_pr_with_conf_padoa_secrets(branch_name: str, new_secrets, description):
    create_branch(padoa_main_secrets, branch_name)
    change_or_create_secret(padoa_main_secrets, branch_name, new_secrets)
    pull = create_pull_request(padoa_main_secrets, branch_name, description=description)
    return pull


def commit_stack_yaml(stack_type: str, stack_name: str, conf_dict: dict) -> str:
    stack_folder = STACK_TYPE_TO_STACK_FOLDER[stack_type]
    repo_path = build_dev_app_file_path(stack_folder, stack_name)
    http_path_to_file = build_github_file_https_path(dev_apps_repo.name, repo_path)

    conf_dict["global"]["githubDevAppFile"] = http_path_to_file
    conf_str = yaml.dump(conf_dict)
    for append_file in APPENDED_FILES:
        with open(append_file, 'r') as f:
            conf_str += ''.join(['\n', *f.readlines()])

    dev_apps_repo.create_file(
        path=repo_path,
        message=f'Create stack {stack_name} of type {stack_type} via create-stack',
        content=conf_str,
        branch=DEV_APPS_REPO_DEFAULT_BRANCH
    )
    return http_path_to_file
