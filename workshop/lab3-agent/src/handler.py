import json


def handler(event, context):
    for record in event["Records"]:
        body = json.loads(record["Body"])
        for s3_event in body.get("Records", []):
            bucket = s3_event["s3"]["bucket"]["name"]
            key = s3_event["s3"]["object"]["key"]
            size = s3_event["s3"]["object"].get("size", 0)
            print(f"PROCESSED s3://{bucket}/{key} ({size} bytes)")
    return {"ok": True}
