import boto3
import subprocess
import os
import json
import logging
import base64

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ecs_client = boto3.client("ecs")
sns_client = boto3.client("sns")
ecr = boto3.client("ecr")

PUBLIC_KEY_PATH = "/var/task/cosign.pub"
SNS_TOPIC_ARN = os.environ.get("SNS_TOPIC_ARN", "")


def verify_image(image: str) -> tuple[bool, str]:
    """
    Verify a container image signature using the cosign binary.
    Returns (success: bool, output: str)
    """
    try:
        auth_data = ecr.get_authorization_token()["authorizationData"][0]

        registry = auth_data["proxyEndpoint"].replace("https://", "")

        username, password = base64.b64decode(
            auth_data["authorizationToken"]
        ).decode().split(":")

        docker_config = {
            "auths": {
                registry: {
                    "auth": base64.b64encode(
                        f"{username}:{password}".encode()
                    ).decode()
                }
            }
        }

        docker_dir = "/tmp/.docker"
        os.makedirs(docker_dir, exist_ok=True)

        with open(f"{docker_dir}/config.json", "w") as f:
            json.dump(docker_config, f)

        env = os.environ.copy()
        env["DOCKER_CONFIG"] = docker_dir
        logger.info("Successfully obtained ECR auth token")
        result = subprocess.run(
            [
                "/usr/local/bin/cosign",
                "verify",
                "--key", PUBLIC_KEY_PATH,
                "--insecure-ignore-tlog",   # skip Rekor transparency log (offline verify)
                image,
            ],
            env=env,
            capture_output=True,
            text=True,
            timeout=30,
        )
        if result.returncode == 0:
            logger.info(f"[PASS] Image verified: {image}")
            return True, result.stdout
        else:
            logger.warning(f"[FAIL] Verification failed for: {image}\n{result.stderr}")
            return False, result.stderr
    except subprocess.TimeoutExpired:
        msg = f"cosign verification timed out for image: {image}"
        logger.error(msg)
        return False, msg
    except Exception as e:
        msg = f"Unexpected error during verification: {str(e)}"
        logger.error(msg)
        return False, msg


def stop_ecs_task(cluster_arn: str, task_arn: str, reason: str):
    """Stop an ECS task with a given reason."""
    try:
        ecs_client.stop_task(
            cluster=cluster_arn,
            task=task_arn,
            reason=reason,
        )
        logger.info(f"Stopped task: {task_arn} in cluster: {cluster_arn}")
    except Exception as e:
        logger.error(f"Failed to stop task {task_arn}: {str(e)}")
        raise


def send_sns_alert(cluster_arn: str, task_arn: str, image: str, reason: str):
    """Send an SNS notification about a blocked container."""
    if not SNS_TOPIC_ARN:
        logger.warning("SNS_TOPIC_ARN not set — skipping notification.")
        return
    try:
        message = (
            f"🚨 Unsigned Container Blocked\n\n"
            f"Cluster : {cluster_arn}\n"
            f"Task    : {task_arn}\n"
            f"Image   : {image}\n\n"
            f"Reason  : {reason}\n\n"
            f"The task has been automatically stopped."
        )
        sns_client.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject="[SECURITY] Unsigned ECS container blocked by Cosign",
            Message=message,
        )
        logger.info("SNS alert sent successfully.")
    except Exception as e:
        logger.error(f"Failed to send SNS alert: {str(e)}")


def lambda_handler(event, context):
    """
    Main Lambda handler — triggered by EventBridge on ECS task state changes.

    Expected EventBridge event shape:
    {
        "detail-type": "ECS Task State Change",
        "detail": {
            "taskArn": "arn:aws:ecs:...",
            "clusterArn": "arn:aws:ecs:...",
            "lastStatus": "RUNNING",
            "containers": [
                { "image": "123456789.dkr.ecr.us-east-1.amazonaws.com/app:latest" }
            ]
        }
    }
    """
    logger.info(f"Received event: {json.dumps(event)}")

    detail = event.get("detail", {})
    task_arn = detail.get("taskArn", "")
    cluster_arn = detail.get("clusterArn", "")
    last_status = detail.get("lastStatus", "")
    containers = detail.get("containers", [])

    # Only act on tasks that are RUNNING
    if last_status != "RUNNING":
        logger.info(f"Task status is '{last_status}' — skipping verification.")
        return {"statusCode": 200, "body": "Skipped — task not RUNNING"}

    if not containers:
        logger.warning("No containers found in event detail.")
        return {"statusCode": 200, "body": "No containers to verify"}

    blocked = []

    for container in containers:
        image = container.get("image", "")
        if not image:
            logger.warning("Container has no image field — skipping.")
            continue

        logger.info(f"Verifying image: {image}")
        verified, output = verify_image(image)

        if not verified:
            reason = f"Cosign signature verification failed: {output[:200]}"
            stop_ecs_task(cluster_arn, task_arn, reason)
            send_sns_alert(cluster_arn, task_arn, image, output[:500])
            blocked.append(image)
        else:
            logger.info(f"Image '{image}' passed verification.")

    if blocked:
        return {
            "statusCode": 200,
            "body": f"Blocked and stopped task due to unverified images: {blocked}",
        }

    return {"statusCode": 200, "body": "All images verified successfully."}
