import requests
import os
import json

# https://www.notion.so/padoa/How-to-generate-an-up-to-date-vault-map-b2980b183a664e6898c46eadc61a9586

# TODO:
# - Run all get_data requests asynchronously (concurrently)
#

TOKEN = os.environ['VAULT_TOKEN']
ENGINE = os.getenv('ENGINE', 'secret')
URL = os.getenv('URL', 'https://vault.padoa.fr')
OUTPUT_FILE = os.getenv('OUTPUT_FILE', './vault-map.json')
vault_map = {}


def generate_headers() -> dict:
    return {
        'x-vault-token': TOKEN
    }

def generate_url(request_route: str, split_vault_path: list)->str:
    return f"{URL}/v1/{ENGINE}/{request_route}/{''.join(split_vault_path)}"


def get_metadata(split_vault_path: list):
    return requests.get(
        generate_url('metadata', split_vault_path),
        params={'list': True},
        headers=generate_headers()
        ).json()['data'][ 'keys']

def get_data(split_vault_path: list):
    print(split_vault_path)
    secrets = requests.get(
        generate_url('data', split_vault_path),
        headers=generate_headers()
        ).json()['data']['data']
    if secrets is None:
        print(f"Warning! No secret in path : {''.join(split_vault_path)}. Its last version might be empty")
        return []

    return list((requests.get(
        generate_url('data', split_vault_path),
        headers=generate_headers()
        ).json()['data']['data']).keys())


def map_from_path(split_path: list) -> None:
    pointer = vault_map
    for index, path_element in enumerate(split_path):
        if index == len(split_path) - 1:
            pointer[path_element] = 'Secret value'
        elif path_element not in pointer:
            pointer[path_element] = {}
        pointer = pointer[path_element]


def fill_map_from_path_r(split_path: list):
    # EXIT CONDITION
    if len(split_path) and  split_path[-1][-1] != '/': # Last char of last elem is not / : It's not a path
        leafs = get_data(split_path)
        for leaf in leafs:
            map_from_path([*split_path, leaf])
    else:
        children = get_metadata(split_path)
        for child in children:
            fill_map_from_path_r([*split_path, child])

fill_map_from_path_r([])
json_vault_map = json.dumps(vault_map, indent=4, sort_keys=True)
with open(OUTPUT_FILE, 'w') as f:
    f.write(json_vault_map)
    print(f'Wrote to: {OUTPUT_FILE}')
