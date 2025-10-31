import os
from azure.storage.blob import ContainerClient

def _blob_client(kind=None):
    config = {
        'hourly': {
            'endpoint': os.environ['BACKUP_BLOBSTORAGE_HOURLY_ENDPOINT'],
            'sas': os.environ['BACKUP_BLOBSTORAGE_HOURLY_SAS'],
        },
        'daily': {
            'endpoint': os.environ['BACKUP_BLOBSTORAGE_DAILY_ENDPOINT'],
            'sas': os.environ['BACKUP_BLOBSTORAGE_DAILY_SAS'],
        },
    }

    if kind:
        if not kind in config:
            # Cas specifique des backups claranet en monthly / weekly qui sont
            # dans le container dont la configuration s'appele daily
            kind = 'daily'

        return ContainerClient.from_container_url(
            config[kind]['endpoint'] + config[kind]['sas']
        )
    else:
        return {
            key: ContainerClient.from_container_url(
                value['endpoint'] + value['sas']
            )
            for key, value in config.items()
        }


def list_backup_kind():
    clients = _blob_client()

    prefixes = []

    for client_name, client in clients.items():
        for obj in client.walk_blobs():
            # obj format is {'name': '{kind}/', ...}
            name = obj['name'].split('/')[0]
            prefixes.append(name)

    return prefixes


def list_client_environments(kind, clientname):
    client = _blob_client(kind)

    prefixes = []
    for obj in client.walk_blobs(name_starts_with=f"{kind}/"):
        # obj format is {'name': '{kind}/{stack_name}/', ...}
        name = obj['name'].split('/')[1]
        prefixes.append(name)

    # Filter prefixes with the client name only
    prefixes = [name for name in prefixes if clientname in name]

    return prefixes


def list_available_backups(kind, stack_name):
    client = _blob_client(kind)

    prefixes = []
    for obj in client.walk_blobs(name_starts_with=f"{kind}/{stack_name}/"):
        # obj format is {'name': '{kind}/{stack_name}/{backup_name}', ...}
        name = obj['name'].split('/')[2]
        prefixes.append(name)
    return prefixes


def get_database_transformer_env(kind, prefix, version):
    variables = {'BLOBSTORAGE_PREFIX': f"{kind}/{prefix}/{version}"}

    if not kind in ['daily', 'hourly']:
        # Cas specifique des backups claranet en monthly / weekly qui sont
        # dans le container dont la configuration s'appele daily
        kind = 'daily'

    variables['BLOBSTORAGE_SOURCE'] = kind
    return variables
