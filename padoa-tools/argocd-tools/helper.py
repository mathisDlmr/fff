#! /usr/bin/env python
# coding: utf-8
import os
import tempfile

EDITOR = os.environ.get('EDITOR', 'vim')
EXAMPLES = '''
###################
#####-HELPERS-#####
###################

# # Add a secret to backend (from ref to vault)
# haw-backend-steroids:
#   backend:
#     vault_secrets:
#       MY_SECRET: path/to/secret#secret-key

# # Add an env variable to backend
# haw-backend-steroids:
#   backend:
#     variables:
#       MY_VARIABLE: value

# # Add an env variable to frontend
# haw-doctor-web:
#   web:
#     variables:
#       MY_VARIABLE : value

# # Enable a specific recurrent_task (and not the others)
# haw-backend-steroids:
#   recurrent_tasks_override:
#     recurrent_task_name:
#       enabled: true
#       alert_severity: low
#       command: "npm run my-job"
#       schedule: "cron"
#       limit_cpu: "200m"
#       limit_memory: "300Mi"
#       request_cpu: "50m"
#       request_memory: "200Mi"
# global:
#   recurrent_tasks: true

# # Enable all workers
# global:
#   backend_workers: true
'''

def call_editor(initial_message="", editor_choice=None):
  with tempfile.NamedTemporaryFile(suffix=".yaml") as tf:
    tf.write(initial_message.encode())
    tf.write(EXAMPLES.encode())
    tf.flush()
    os.system(f"{editor_choice if editor_choice is not None else EDITOR} {tf.name}")

    # do the parsing with `tf` using regular File operations.
    # for instance:
    tf.seek(0)
    return tf.read()
