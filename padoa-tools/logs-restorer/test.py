from logsRestorer import *
from os import environ as env
if __name__ == "__main__":
    # Load all environment variables
    host = env.get("HOST")
    port = env.get("PORT")
    repo_name = env.get("REPOSITORY")
    snapshot_prefix = env.get("SNAPSHOT")
    index_prefix = env.get("INDEX")
    from_date = env.get("FROM")
    to_date = env.get("TO")
    index_health_timeout = int(env.get("INDEX_HEALTH_TIMEOUT", 1800))
    DEBUG = True
    repo = Repository(host, repo_name, port)
    if DEBUG:
        print("[DEBUG] Warning: debug is active, unset DEBUG variable to disable")
        print("[DEBUG] Host: {}".format(host))
        print("[DEBUG] Port: {}".format(port))
        print("[DEBUG] Repository: {}".format(repo_name))
        print("[DEBUG] Snapshot prefix: {}".format(snapshot_prefix))
        print("[DEBUG] Index prefix: {}".format(index_prefix))
        print("[DEBUG] From date: {}".format(from_date))
        print("[DEBUG] To date: {}".format(to_date))
        print("[DEBUG] Snapshots in repo: ", repo.get_snapshots())
    else:
        sys.tracebacklimit = 0 # Suppress error traceback
    
    # Change this:
    index = Index(prefix=index_prefix, iso_date=from_date, snapshot_prefix=snapshot_prefix, repository=repo)
    index.restore()
    if index.delete():
        print("Success")
