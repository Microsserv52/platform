FROM python:3.13-alpine

WORKDIR /app
COPY server.py .

RUN mkdir -p /data
ENV IMAGE_STORAGE_DATA_DIR=/data

EXPOSE 8090
CMD ["python", "server.py"]
