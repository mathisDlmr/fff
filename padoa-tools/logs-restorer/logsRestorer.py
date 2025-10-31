import requests
import time
from datetime import date
import json
from os import environ as env
import sys

class Repository:
    def __init__(self, host="", name="", port=9200):
        self.host = host
        self.name = name
        self.port = port

    def __str__(self):
        # str(repo) will be its name
        return self.name

    def get_snapshots(self):
        return requests.get("{}:{}/_snapshot/{}/_all".format(self.host, self.port, self.name)).json()["snapshots"]

    @staticmethod
    def get_all(host, port=9200):
        """
        Helper to list all repos in host
        """
        raw = requests.get("{}:{}/_cat/repositories".format(host, port)).text
        repos = []
        for line in raw.split('\n'):
            repo = line.split(' ')[0]
            if repo != '':
                repos.append(Repository(host, repo, port))
        return repos


class Snapshot:
    def __init__(self, prefix, iso_date, repository=Repository()):
        # @Param repository: defaults to empty for simple operations
        self.prefix = prefix
        self.date = date.fromisoformat(iso_date).toordinal()
        self.repository = repository

    def _strip_date(self) -> int:
        # Helper to strip dashes from iso date and return it ready for computation
        iso = date.isoformat(date.fromordinal(self.date))
        return int("".join(iso.split('-')))

    def __str__(self):
        # Get full name
        return "{}-{}".format(self.prefix, self._strip_date() + 1) # Snapshot of the next day contains the data from this day

    def __repr__(self) -> str:
        return str(self)

    def get(self):
        # get json data from snapshot
        return requests.get("{}:{}/_snapshot/{}/{}".format(self.repository.host, self.repository.port, self.repository.name, str(self))).json()



class Index:
    def __init__(self, prefix, snapshot_prefix, iso_date, repository=Repository()):
        self.prefix = prefix
        self.snapshot = Snapshot(snapshot_prefix, iso_date, repository)

    def __str__(self):
        return "{}-{}".format(self.prefix, self.snapshot._strip_date())

    def __repr__(self) -> str:
        return str(self)

    def until(self, other):
        # get range between self and other included
        res = []
        for day in range(self.snapshot.date, other.snapshot.date+1):
            res.append(Index(self.prefix, self.snapshot.prefix, date.isoformat(date.fromordinal(day)), self.snapshot.repository))

        return res

    def delete(self):
        res = requests.delete("{}:{}/{}".format(self.snapshot.repository.host, self.snapshot.repository.port, str(self))).json()
        if "error" in res:
            print("Failed to delete {}: {}".format(self, res["error"]))
            return False
        elif not "acknowledged" in res:
            print("Failed to delete {}: {}".format(self, res))
            return False
        elif res["acknowledged"]:
            return True

    def health(self):
        # Get index health
        return requests.get("{}:{}/_cluster/health/{}".format(self.snapshot.repository.host, self.snapshot.repository.port, str(self))).json()["status"]

    def wait_success(self, timeout=1800):
        # Wait until the index is green
        # Returns True if success, False if timeout
        time.sleep(10) # Wait 10sec for the index to be created
        for i in range(2, int(timeout/5)):
            status = self.health()
            if status == "green":
                return True
            elif status == "red":
                print("[ERR] Failed to restore {}: index is red. This probably means that the index is corrupted and cannot be restored.".format(self), end=" ")
                if self.delete():
                    print("The index {} was deleted.".format(self))
                else:
                    print("Failed to delete the index {}, see the error message above.".format(self)) # delete() will print the error message
                return False
            else:
                print("Waiting for restore to finish... (status is {}, want green) [{}/{}s]".format(status, i*5, timeout))
                time.sleep(5)
        print("[ERR] Failed to restore {}: timeout after {}s".format(self, timeout))
        return False

    def restore(self, timeout=1800):
        # Restore index
        if DEBUG:
            print("[DEBUG] Using snapshot: ", str(self.snapshot))
            print("[DEBUG] Indices in snapshot: ", self.snapshot.get())
            print("[DEBUG] Using index: ", str(self))
        post_data = {"indices": str(self)}
        res = requests.post("{}:{}/_snapshot/{}/{}/_restore".format(self.snapshot.repository.host,
                self.snapshot.repository.port,
                self.snapshot.repository.name,
                str(self.snapshot)),
            data=json.dumps(post_data), 
            headers={'Content-Type': 'application/json'}).json()

        if "error" in res:
            print("Failed to restore {}: {}".format(self, res["error"]["root_cause"][0]["reason"]))
            return False
        elif not "accepted" in res:
            print("Failed to restore {}: {}".format(self, res))
            return False
        elif res["accepted"]:
            print("Restoring {}...".format(self))
            if self.wait_success(timeout):
                print("Restored {}.".format(self))
                return True
            else:
                return False
        else:
            print("Failed to restore {}: unknown error {}".format(self, res))
            return False

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
    DEBUG = env.get("DEBUG")
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

    start = Index(index_prefix, snapshot_prefix, from_date, repo)
    end = Index(index_prefix, snapshot_prefix, to_date, repo)
    span = start.until(end)
    if len(span) > 30:
        raise IndexError("Cannot restore more than 30 days at a time")
    success = all([index.restore(timeout=index_health_timeout) for index in span])
    if not success:
        raise RuntimeError("Some snapshots were not restored.")
