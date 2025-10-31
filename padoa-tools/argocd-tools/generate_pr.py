import random
from datetime import date

from github import Repository
from prompt_toolkit.styles import Style
import questionary
import re
import yaml
import argocd_lib as argocd
import os
import logging
from colorama import init, Fore
import github_lib
import backup_lib
from constants import STACK_TYPE, STACK_NAME_MAX_LENGTH
from helper import call_editor

default_client = "sist2a"

init(autoreset=True)

# Create a logger object.
logger = logging.getLogger(__name__)

DEFAULT_STATE = "running"

os.system("export TERM=xterm")


def get_branches(site: Repository) -> list:
    return [branch.name for branch in site.get_branches()]

def validator_branch_exists(branches: list):
    def branch_lint(user_input):
        if user_input not in branches:
            return "Branch does not exist"
        return True
    return branch_lint

def validator_stack(branches):
    # Returns a function that will be used as a prompt validator.
    def lambda_f(user_input):
        # Returns True or an error message.
        if user_input in branches:
            return "Branch already exists"
        label_max_size = 63
        release_max_size = 53
        workflow_creator_label = "system-serviceaccount-medical-dev-" + "-wf"
        database_transformer_release = ".database-transformer"
        max_size = min(
                STACK_NAME_MAX_LENGTH,
                label_max_size - len(workflow_creator_label),
                release_max_size - len(database_transformer_release))
        if len(user_input) > max_size:
            return "Stack name is too long, max is {}".format(max_size)
        regex = re.compile(r'^[a-z][a-z0-9-]*[a-z0-9]$')
        if any(env in user_input for env in ["demo", "formation", "prod"]):
            return "'demo', 'formation' and 'prod' are not allowed in stack name"
        if not regex.match(user_input):
            return "Stack name must start with a letter and can only contain letters, numbers and '-'"
        return True
    return lambda_f

def extract_repo_name(repo):
    return repo if type(repo) == str else repo["repo"]


def extract_service_name(repo):
    return repo if type(repo) == str else repo["service"]


current_user = argocd.get_user()

print(f"Hello {Fore.GREEN}{current_user['username']}{Fore.RESET}!")
print(f"This script allow you to create dev environment through a Github file in realtime")
print(f"This stack will be deployed on Kubernetes using ArgoCD")
print(
    f"You can find a guide here: {Fore.CYAN}https://www.notion.so/padoa/Getting-Started-with-ArgoCD-dd4627583c8f439d8334f9c89aeea050")
print(
    f"\nYou'll first have to chose the services you want to test and their branch/commit (ie: haw-backend-steroids on branch feat-improve-digital-sign).")
print(
    f"Example:\n"
    f"  Stack name: feat-digital-sign2\n"
    f"  haw-backend-steroids:\n"
    f"    targetRevision: feat-improve-digital-sign\n"
    f"  haw-doctor-web:\n"
    f"    targetRevision: c948ac5cacb56ff41f64d92ebcc95aeb53d98a6b {Fore.RED}(!!! use full sha !!!){Fore.RESET}\n"
)
answers_1 = questionary.prompt([
    {
        'type': 'text',
        'name': 'stack_name',
        'message': 'What is the name of your stack ?',
        'validate': validator_stack(
                get_branches(github_lib.padoa_helm_repo) + get_branches(github_lib.padoa_main_secrets))
    },
    {
        'type': 'select',
        'name': 'stack_type',
        'message': "Which kind of stack do you want?",
        'choices': STACK_TYPE.ALL
    }
])
stack_type = answers_1["stack_type"]
repo_choices = []
if stack_type in (STACK_TYPE.MEDICAL_DEV, STACK_TYPE.MEDICAL_DEV_FACTU):
    repo_choices = [
        "database-transformer",
        "haw-backend-steroids",
        "haw-doctor-web",
        "stack-initiator",
        "socket-io-proxy",
        "padoa-postgres",
        "padoa-workflow-repo"
    ]
elif stack_type == STACK_TYPE.MEDICAL_INTEGRATION:
    repo_choices = [
        "database-transformer",
        "haw-backend-steroids",
        "haw-doctor-web",
        "haw-integration",
        "stack-initiator",
        "socket-io-proxy",
        "padoa-postgres",
        "padoa-workflow-repo"
    ]
elif STACK_TYPE.is_stats(stack_type):
    repo_choices = [
        "database-transformer",
        questionary.Choice('stats-api', {"repo": "haw-stats", "service": "stats-api"}),
        questionary.Choice('stats-manager', {"repo": "haw-stats", "service": "stats-manager"}),
        "stats-ml-reco-doc",
        "stats-user-api",
        "padoa-superset",
        "padoa-workflow-repo",
    ]
else:
    print("wrong stack type")
    exit(1)

answers_1.update(questionary.prompt([
    {
        'type': 'checkbox',
        'name': 'repo_to_follow',
        'message': "Which repositories will be tested (untested repo follow release or master)?",
        'choices': repo_choices
    }
]))
stack_name = f'd{random.randint(0, 9999)}-{answers_1["stack_name"].rstrip()}'

auto_complete_style = Style([
    ('answer', 'fg:#2bed4e bold'),
    ('selected', 'fg:#737373')
])
answers_2 = {}
follow_branch = 'Branch'
follow_deploy = 'Branch deployed after build and test (using tag _deploy)'
follow_fast = 'Branch deployed after build (using tag _deploy-fast)'
follow_commit = 'Commit'
for repo_to_follow in answers_1["repo_to_follow"]:
    service = extract_service_name(repo_to_follow)
    list_follow_choices = [follow_deploy, follow_fast] if service in (
        "haw-backend-steroids", "haw-doctor-web", "haw-integration") else [follow_branch]
    list_follow_choices += [follow_commit]
    choice = questionary.select(
        f'What will follow {service}? ("Branch" will auto-update with new commits, "Commit" will stay fixed',
        list_follow_choices).ask()
    if choice == follow_commit:
        answers_2.update(questionary.prompt([{
            'type': 'text',
            'name': f'target_{service}',
            'message': f'Commit full sha:',
        }]))
    elif choice in [follow_branch, follow_deploy, follow_fast]:
        branches = get_branches(github_lib.g.get_repo(f'padoa/{extract_repo_name(repo_to_follow)}'))
        answers_2.update(questionary.prompt([{
            'type': 'autocomplete',
            'name': f'target_{service}',
            'choices': branches,
            'validate': questionary.Validator.from_callable(
                validator_branch_exists(branches),
                error_message="This branch name does not exists"),
            'message': 'Branch name:'
        }], style=auto_complete_style))
        if choice == follow_deploy:
            answers_2[f"target_{service}"] += '_deploy'
        if choice == follow_fast:
            answers_2[f"target_{service}"] += '_deploy-fast'

# PICK CLIENT
questions_2 = [
    {
        'type': 'confirm',
        'name': 'default_client',
        'message': f'Do you want to use the default client ({default_client})?'
    },
    {
        'type': 'select',
        'name': 'client',
        'message': 'Select client',
        'when': lambda x: not x['default_client'],
        'choices': [
            'aipals',
            'aist21',
            'amet',
            'apst18',
            'apst37',
            'apst41',
            'ast74',
            'axa-france',
            'ciamt',
            'cmie',
            'dgac',
            'gie-axa',
            'gims13',
            'meteo-france',
            'prevaly',
            'saint-gobain',
            'santbtp-37',
            'santra-plus',
            'simt',
            'sist2a',
            'sist-narbonne',
            'simup',
            'prevaly'
        ]
    },
    {
        'type': 'confirm',
        'name': 'anonymize',
        'message': 'Do you want the database to be anonymized?'
    },
    {
        'type': 'confirm',
        'name': 'default_dump',
        'message': 'Use default database dump? (the most recent)',
        'when': lambda x: not x['anonymize'],
    },
]
answers_2.update(questionary.prompt(questions_2))

if answers_2["default_client"]:
    answers_2["client"] = default_client

dump_answers = {}
if (not answers_2['anonymize']) and (not answers_2['default_dump']):
    dump_kinds = backup_lib.list_backup_kind()

    dump_answers.update(questionary.prompt([{
        'type': 'select',
        'name': 'kind',
        'message': "What kind of backup do you want to use?",
        'choices': dump_kinds,
    }]))

    dump_envs = backup_lib.list_client_environments(dump_answers['kind'], answers_2['client'])

    dump_answers.update(questionary.prompt([{
        'type': 'select',
        'name': 'prefix',
        'message': "From wich original stack do you want to take the backup ?",
        'choices': dump_envs,
    }]))

    dump_versions = backup_lib.list_available_backups(dump_answers['kind'], dump_answers['prefix'])

    dump_answers.update(questionary.prompt([{
        'type': 'select',
        'name': 'version',
        'message': "Which backup do you want to use?",
        'choices': dump_versions,
    }]))

# VALIDITY DURATION
questions_2 = [
    {
        'name': 'validity_duration',
        'type': 'text',
        'default': '1h',
        'message': 'Validity duration (ie: 1m 2h 3d - max: 5d)?',
        'validate': lambda val: bool(re.match("[0-5][0-9]m|[1-9]m|[0-2][0-9]h|[1-9]h|[1-5]d", val))
    },
    {
        'type': 'confirm',
        'name': 'add_secret',
        'message': 'Do you want to add or change a secret environment variable (token, api key)?',
        # Waiting for rework with vault
        'when': lambda _: False
    },
    {
        'type': 'confirm',
        'name': 'add_secret',
        'message': 'Are you sure? Reminder: the format is ENVIRONMENT_NAME: secret-key-name (refers to secret-key-value)',
        'when': lambda x: 'add_secret' in x and x['add_secret']
    }
]
answers_2.update(questionary.prompt(questions_2))
answers_2['add_secret'] = False

new_secret = answers_2['add_secret']
secrets = []
while new_secret:
    secret_questions = [
        {
            'type': 'checkbox',
            'name': 'repo',
            'message': "Which services should have the secret?",
            'choices': ["haw-backend-steroids"]
        },
        {
            'type': 'text',
            'name': 'env_name',
            'message': 'Environment variable name:',
            'validate': lambda val: len(val) >= 1
        },
        {
            'type': 'text',
            'name': 'key',
            'message': 'Secret key name:',
            'validate': lambda val: len(val) >= 1
        },
        {
            'type': 'text',
            'name': 'value',
            'message': 'Secret key value:',
            'validate': lambda val: len(val) >= 1
        },
        {
            'type': 'confirm',
            'name': 'new_secret',
            'message': 'Do you want to add another secret?'
        }
    ]
    secret_answers = questionary.prompt(secret_questions)
    new_secret = secret_answers["new_secret"]
    secret_answers.pop("new_secret")
    secrets.append(secret_answers)

followed_by_repo = {}
for repo in answers_1["repo_to_follow"]:
    service = extract_service_name(repo)
    followed_by_repo[service] = {'targetRevision': answers_2[f"target_{service}"]}
if answers_2['add_secret']:
    followed_by_repo["main_secret"] = {'targetRevision': stack_name}

# as this can be misleading, we remove the anonymize from stats stacks
anonymize_global_options = dict() if STACK_TYPE.is_stats(stack_type) else {'anonymize': answers_2["anonymize"]}

conf_dict = {
    'global': {
        **anonymize_global_options,
        'createdAt': date.today(),
        'stackType': stack_type,
        'client_name': answers_2["client"],
        'creator_name': current_user["username"],
        'validity_duration': answers_2["validity_duration"],
        'state': DEFAULT_STATE,
    },
    **followed_by_repo
}

for secret in secrets:
    for repo in secret["repo"]:
        # WARNING only works for backend !!!
        if repo not in conf_dict:
            conf_dict[repo] = {}
        if "backend" not in conf_dict[repo]:
            conf_dict[repo]["backend"] = {}
        if "secrets" not in conf_dict[repo]["backend"]:
            conf_dict[repo]["backend"]["secrets"] = {}
        conf_dict[repo]["backend"]["secrets"][secret["env_name"]] = secret["key"]

# For custom backups
if dump_answers:
    if 'database-transformer' not in conf_dict:
        conf_dict['database-transformer'] = {}
    if 'variables' not in conf_dict['database-transformer']:
        conf_dict['database-transformer']['variables'] = {}

    _variables = backup_lib.get_database_transformer_env(
        dump_answers['kind'],
        dump_answers['prefix'],
        dump_answers['version']
    )

    conf_dict['database-transformer']['variables'].update(_variables)

if stack_type == STACK_TYPE.MEDICAL_DEV_FACTU:
    if 'haw-backend-steroids' not in conf_dict.keys():
        conf_dict['haw-backend-steroids'] = {}
    if 'backend' not in conf_dict['haw-backend-steroids'].keys():
        conf_dict['haw-backend-steroids']['backend'] = {}
    if 'vault_secrets' not in conf_dict['haw-backend-steroids']['backend'].keys():
        conf_dict['haw-backend-steroids']['backend']['vault_secrets'] = {}
    vault_secrets = conf_dict['haw-backend-steroids']['backend']['vault_secrets']
    vault_secrets['API_BILLING_REPORTING_TOKEN'] = '$cluster_env/billing/lambda-reporting#token'
    vault_secrets['API_BILLING_TOKEN'] = '$cluster_env/billing/api/$client#token'

conf = yaml.dump(conf_dict)

# CREATE SECRETS
print(f"\nStack name: {stack_name}\n\nConfiguration file:\n{Fore.YELLOW}{conf}")
if answers_2['add_secret']:
    print(f"Secrets:\n{Fore.YELLOW}{yaml.dump(secrets)}")
while not questionary.confirm(
        "Are you ok with this config ? If not, an editor will open (Mostly use for infra changes on highly customized stack)").ask():
    conf = call_editor(conf).decode()
    os.system("clear")
    print(f"Stack name: {stack_name}\n\nModified configuration file:\n{Fore.YELLOW}{conf}")
    if answers_2['add_secret']:
        print(f"Secrets:\n{Fore.YELLOW}{yaml.dump(secrets)}")

print(f"\n{Fore.GREEN}The stack commit is now being created...")

if answers_2['add_secret']:
    secret_pr = github_lib.github_create_pr_with_conf_padoa_secrets(stack_name, secrets,
                                                                    f"Created by {current_user['username']}")
    print(f"\n-> Secret stack PR: {Fore.CYAN}{secret_pr.html_url}\n")
conf_dict = yaml.load(conf, Loader=yaml.FullLoader)

# COMMIT
github_link = github_lib.commit_stack_yaml(stack_type, stack_name, conf_dict)

created_namespace = f'stack-{stack_name}' if STACK_TYPE.is_stats(stack_type) else f'medical-pr-{stack_name}'

print("Here are some useful links. You can copy them by just selecting them.")
print(f"-> ArgoCD stack: {Fore.CYAN}{argocd.ARGOCD_URL}/applications/{stack_name}")
print(
    f"-> Init logs ({Fore.GREEN}\u2714{Fore.RESET} = Stack is ready!): {Fore.CYAN}https://workflow-pr.aodap-dev.fr/workflows/{created_namespace}")
if STACK_TYPE.is_stats(stack_type):
    print(f"-> Frontend domain: {Fore.CYAN}https://{stack_name}.aodap-dev.fr/stats")
else:
    print(f"-> Frontend domain: {Fore.CYAN}https://beta-{stack_name}-{answers_2['client']}.aodap-dev.fr")
print(f"-> Github file: {Fore.CYAN}{github_link}")
