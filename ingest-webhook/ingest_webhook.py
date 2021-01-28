#!/usr/bin/env python3
"""
ingest_webhook is a http server that accepts any json payload on and ingests it into the
`incoming-webhooks` dataset.
"""

import json
import os
from flask import Flask, request
import requests

app = Flask(__name__)
request_url = (
    os.environ["AXM_URL"] + "/api/v1/datasets/" + os.environ["AXM_DATASET"] + "/ingest"
)
headers = {
    "Authorization": "Bearer " + os.environ["AXM_TOKEN"],
    "Content-Type": "application/x-ndjson",
}


@app.route("/", methods=["POST"])
def handler():
    """
    Handler takes any JSON sent to it and ingests it into the `incoming-webhooks` dataset.
    """
    res = requests.post(request_url, data=json.dumps(request.json), headers=headers)
    return res.json()


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80)
