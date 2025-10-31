import argparse
import logging
import os
import re
from typing import List
from elasticsearch import Elasticsearch, BadRequestError, NotFoundError

ELASTIC_TIMEOUT: int = int(os.environ.get("ELASTIC_TIMEOUT", "120"))

INDEX_PATTERN_SUBPART = '[a-z0-9](-[a-z0-9]|[a-z0-9])+'
UUID_PATTERN_SUBPART = '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'
INDEX_PATTERN = f"^(?P<client>{INDEX_PATTERN_SUBPART})_(?P<stack>{INDEX_PATTERN_SUBPART})_(?P<type>{INDEX_PATTERN_SUBPART})_(?P<uuid>{UUID_PATTERN_SUBPART})$"


def setupElasticClient() -> Elasticsearch:
    """
    Fonction qui permet de setup un client connecté à une instance d'Elasticsearch.
    """
    ELASTIC_USER = os.environ["ELASTIC_USER"]
    ELASTIC_PASSWORD = os.environ["ELASTIC_PASSWORD"]
    ELASTIC_HOST = os.environ["ELASTIC_HOST"]
    logging.info("Setting up Elasticsearch client...")
    logging.debug(f"HOST: {ELASTIC_HOST}")
    logging.debug(f"USER: {ELASTIC_USER}")

    return Elasticsearch(
        ELASTIC_HOST,
        basic_auth=(ELASTIC_USER, ELASTIC_PASSWORD),
        request_timeout=ELASTIC_TIMEOUT,
    )


def getCommandLineArgs(esClient: Elasticsearch):
    """
    Parse et retourne les arguments passés au programme
    """
    parser = argparse.ArgumentParser(
        description="Manager de snapshots pour notre Elasticsearch Medical"
    )
    parser.add_argument(
        "--repository",
        required=True,
        nargs="?",
        help="Le nom du repository de snapshots. Il correspond au nom du storage container sur Azure.",
    )
    parser.add_argument(
        "--client",
        required=True,
        nargs="?",
        help="Le client de la stack (ex: CMIE, Prevaly...)",
    )
    parser.add_argument(
        "--stack-from",
        required=True,
        nargs="?",
        help="Le nom de la stack dont proviennent les indices.",
    )
    parser.add_argument(
        "--stack-to",
        required=True,
        nargs="?",
        help="Le nom de la stack dans laquelle restaurer les indices.",
    )
    parser.add_argument(
        "--indices",
        required=False,
        default="ALL",
        nargs="*",
        help="Indice à restaurer.",
    )
    parser.add_argument(
        "--date",
        required=False,
        default="LAST",
        nargs="?",
        help="Date du snapshot à restaurer.",
    )
    parser.add_argument(
        "--replicas",
        required=False,
        default=3,
        nargs="?",
        help="Nombre de replicas pour les indices à restaurer.",
    )
    parser.add_argument(
        "--replica-restore-timeout-in-sec",
        required=False,
        default=1200,
        nargs="?",
        help="Timeout pour la restauration des replicas.",
    )
    args = parser.parse_args()
    args.date = (
        getLastSnaphotName(
            esClient=esClient, repository=args.repository, client=args.client
        )
        if args.date == "LAST" or args.date == "" or args.date is None
        else args.date
    )

    return args


def listIndicesTypesFromSnapshot(
        esClient: Elasticsearch, repository: str, stack: str, date: str
) -> List:
    """
    Retourne les types d'indices depuis un snapshot
    """
    logging.info(f"Getting indices for stack {stack} in snapshot {date}...")
    allIndices = esClient.snapshot.get(repository=repository, snapshot=date)[
        "snapshots"
    ][0]["indices"]

    types = []
    for indice in allIndices:
        matched = re.search(INDEX_PATTERN, indice)
        if matched and matched.groupdict()['stack'] == stack:
            types.append(matched.groupdict()['type'])
        elif matched:
            # match pattern but is from another stack so we do not print any useless logs
            pass
        elif not matched and indice.startswith('.'):
            # does not match pattern but is an system indice so we do not print any useless logs
            pass
        else:
            print(f'Indice {indice} did not matched pattern and is ignored. It should be probably be cleaned up in '
                  f'production !')
    # we use this to get unique values. We risk to have duplicate for legacy types with dangling indices (such as planning)
    return list(set(types))


def getLastSnaphotName(esClient: Elasticsearch, repository: str, client: str) -> str:
    """
    Retourne le nom du snapshot le plus récent
    """

    def get_latest_snapshot_name_with_expression(snapshot: str) -> str:
        return esClient.snapshot.get(
            repository=repository, snapshot=snapshot, size=1, order="desc"
        )["snapshots"][0]["snapshot"]

    snapshot_expression = f"*_{client}"
    try:
        lastSnapshotName = get_latest_snapshot_name_with_expression(snapshot_expression)
        logging.debug(lastSnapshotName)
        return lastSnapshotName
    except NotFoundError:
        logging.warning(
            f"Could not find snapshot {snapshot_expression} falling back to '_all'"
        )

        lastSnapshotName = get_latest_snapshot_name_with_expression("_all")
        logging.debug(lastSnapshotName)
        return lastSnapshotName


def deleteIndices(esClient: Elasticsearch, indices: List[str]) -> None:
    groupsToDelete = [indices[i:i + 15] for i in range(0, len(indices), 15)]
    for chunkToDelete in groupsToDelete:
        indicesToDelete = ",".join(chunkToDelete)
        logging.info(f"Deleting indice: {indicesToDelete}")
        esClient.indices.delete(index=indicesToDelete)


def main() -> None:
    logging.basicConfig(level=logging.INFO)

    esClient = setupElasticClient()
    args = getCommandLineArgs(esClient=esClient)

    # Les indices à remplacer dans la stack de destination
    indicesTypes = (
        args.indices
        if args.indices != "ALL"
        else listIndicesTypesFromSnapshot(
            esClient=esClient,
            repository=args.repository,
            stack=args.stack_from,
            date=args.date,
        )
    )
    if len(indicesTypes) == 0:
        logging.error(
            f"No indices found for stack {args.stack_from} in snapshot {args.date} and repository {args.repository}."
        )
        return

    logging.info(
        f"Restoring indices {', '.join(indicesTypes)} from snapshot: {args.date}"
    )

    for indiceType in indicesTypes:
        # SUPPRESSION DES ANCIENS INDEX
        listOfIndicesToDelete = list(esClient.indices.get(
            index=f"{args.client}_{args.stack_to}_{indiceType}_*"
        ).keys())
        if listOfIndicesToDelete:
            deleteIndices(esClient, listOfIndicesToDelete)
        # RESTAURATION DU NOUVEL INDEX
        replicasSettings = {"index.number_of_replicas": args.replicas}
        indiceToRestore = f"{args.client}_{args.stack_from}_{indiceType}_*"
        logging.info(f"Restoring indice: {indiceToRestore}")
        esClient.snapshot.restore(
            repository=args.repository,
            snapshot=args.date,
            indices=indiceToRestore,
            include_aliases=False,
            rename_pattern=f"(.+){args.stack_from}(.+)",
            rename_replacement=f"$1{args.stack_to}$2",
            index_settings=replicasSettings,
            master_timeout=f"{args.replica_restore_timeout_in_sec}s",
            wait_for_completion=True,
        )

        # SWAP DE L'ALIAS
        aliasToCreate = f"{args.client}_{args.stack_to}_{indiceType}"
        restoredIndices = list(esClient.indices.get(
            index=f"{args.client}_{args.stack_to}_{indiceType}_*"
        ).keys())
        # Handle the case where reindexation is ocurring at the same time on the stack and a raw index without an
        # alias is being recreated
        restoredIndices = [indice for indice in restoredIndices if indice != aliasToCreate]
        # There was exactly one indice restored : we can alias it so the backend can use it
        if len(restoredIndices) == 1:
            indexToAlias = restoredIndices[0]
            logging.info(f"Creating alias {aliasToCreate} -> {indexToAlias}")
            try:
                esClient.indices.put_alias(index=indexToAlias, name=aliasToCreate)
            except BadRequestError as err:
                logging.info(err)
                # Handle the case where reindexation is ocurring at the same time on the stack and a raw index without an alias is being recreated
                if err.message == 'invalid_alias_name_exception':
                    logging.info(
                        f"Creating alias {aliasToCreate} -> {indexToAlias}: index was recreated due to stack activity, beginning a swap")
                    esClient.indices.update_aliases(actions=[
                        {'add': {'index': indexToAlias, 'alias': aliasToCreate}},
                        {'remove_index': {'index': aliasToCreate}}
                    ])
                else:
                    raise err
        # There was more than one indice restored : we can not determine which one the backend should use
        # so we delete them all and the backend will do a full reload to rebuild this indice from scratch
        else:
            logging.warning(
                f"More than one indice was restored for type {indiceType}. A full reload must be performed after running this script. Running cleanup...")
            deleteIndices(esClient, restoredIndices)


if __name__ == "__main__":
    main()
