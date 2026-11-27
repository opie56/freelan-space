FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends python3 python3-pil tesseract-ocr tesseract-ocr-eng \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY server.py .
RUN chmod 0644 /app/server.py
USER 65534:65534
ENV PYTHONDONTWRITEBYTECODE=1
EXPOSE 8080
CMD ["/usr/bin/python3", "server.py"]
