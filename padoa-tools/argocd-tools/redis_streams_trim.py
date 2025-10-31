#!/usr/bin/env python
import os
import redis

REDIS_HOSTNAME = os.getenv('REDIS_HOSTNAME', 'localhost')
REDIS_PORT = os.getenv('REDIS_PORT', 6379)
REDIS_STREAM_MAX_LENGTH = os.getenv('REDIS_STREAM_MAX_LENGTH', 1000)
CLUSTER_ENV = os.getenv('CLUSTER_ENV', None)

client = redis.Redis(host=REDIS_HOSTNAME, port=REDIS_PORT)


def trim_redis_streams():
    streams = client.scan_iter(_type='stream')
    for stream in streams:
        print(f'Trimming stream {stream}')
        client.xtrim(stream, REDIS_STREAM_MAX_LENGTH, approximate=False)


if __name__ == "__main__":
    if CLUSTER_ENV == 'prod':
        raise Exception('redis clean must not run in prod')
    print(f'Deleting redis keys in env {CLUSTER_ENV} for redis {REDIS_HOSTNAME}')
    trim_redis_streams()
    print('Done !')
