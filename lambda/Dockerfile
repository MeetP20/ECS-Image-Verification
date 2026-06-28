FROM python:3.12-slim

ARG COSIGN_VERSION=v2.4.1

RUN apt-get update && \
    apt-get install -y curl ca-certificates && \
    rm -rf /var/lib/apt/lists/*

RUN curl -Lo /usr/local/bin/cosign \
    "https://github.com/sigstore/cosign/releases/download/${COSIGN_VERSION}/cosign-linux-amd64" && \
    chmod +x /usr/local/bin/cosign && \
    cosign version

# Install Lambda Runtime Interface Client
RUN pip install --no-cache-dir awslambdaric

WORKDIR /var/task

COPY cosign.pub .
COPY handler.py .
COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

# Use the Lambda RIC as the entrypoint
ENTRYPOINT ["/usr/local/bin/python", "-m", "awslambdaric"]
CMD ["handler.lambda_handler"]