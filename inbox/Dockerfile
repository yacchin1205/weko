FROM python:3.12-slim AS base

ENV PYTHONUNBUFFERED True
ENV APP_HOME /app
WORKDIR $APP_HOME

FROM base AS production

# System deps for building some Python packages (e.g. JPype1) on slim images
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    git \
    build-essential \
 && rm -rf /var/lib/apt/lists/*
RUN git clone --branch nii_main https://github.com/RCOSDP/coar-notify-inbox.git $APP_HOME

RUN pip install --upgrade pip
RUN pip install --no-cache-dir -r requirements.txt --prefer-binary

CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8080"]
