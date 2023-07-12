ARG PY_VERSION=3.10

ARG OPENAI_TOKEN
ARG OPENAI_ORGANIZATION
ARG DISCORD_TOKEN
ARG PINECONE_TOKEN
ARG PINECONE_REGION
ARG GOOGLE_SEARCH_API_KEY
ARG GOOGLE_SEARCH_ENGINE_ID
ARG DEEPL_TOKEN
ARG WOLFRAM_API_KEY
ARG REPLICATE_API_KEY
ARG DEBUG_GUILD
ARG DEBUG_CHANNEL
ARG ALLOWED_GUILDS
ARG MODERATIONS_ALERT_CHANNEL
ARG ADMIN_ROLES
ARG DALLE_ROLES
ARG GPT_ROLES
ARG TRANSLATOR_ROLES
ARG SEARCH_ROLES
ARG INDEX_ROLES
ARG CHANNEL_CHAT_ROLES
ARG CHANNEL_INSTRUCTION_ROLES
ARG CHAT_BYPASS_ROLES
ARG USER_INPUT_API_KEYS
ARG USER_KEY_DB_PATH
ARG MAX_SEARCH_PRICE
ARG MAX_DEEP_COMPOSE_PRICE
ARG CUSTOM_BOT_NAME
ARG WELCOME_MESSAGE
ARG BOT_TAGGABLE
ARG PRE_MODERATE
ARG FORCE_ENGLISH

ENV OPENAI_TOKEN=$OPENAI_TOKEN
ENV OPENAI_ORGANIZATION=$OPENAI_ORGANIZATION
ENV DISCORD_TOKEN=$DISCORD_TOKEN
ENV PINECONE_TOKEN=$PINECONE_TOKEN
ENV PINECONE_REGION=$PINECONE_REGION
ENV GOOGLE_SEARCH_API_KEY=$GOOGLE_SEARCH_API_KEY
ENV GOOGLE_SEARCH_ENGINE_ID=$GOOGLE_SEARCH_ENGINE_ID
ENV DEEPL_TOKEN=$DEEPL_TOKEN
ENV WOLFRAM_API_KEY=$WOLFRAM_API_KEY
ENV REPLICATE_API_KEY=$REPLICATE_API_KEY
ENV DEBUG_GUILD=$DEBUG_GUILD
ENV DEBUG_CHANNEL=$DEBUG_CHANNEL
ENV ALLOWED_GUILDS=$ALLOWED_GUILDS
ENV MODERATIONS_ALERT_CHANNEL=$MODERATIONS_ALERT_CHANNEL
ENV ADMIN_ROLES=$ADMIN_ROLES
ENV DALLE_ROLES=$DALLE_ROLES
ENV GPT_ROLES=$GPT_ROLES
ENV TRANSLATOR_ROLES=$TRANSLATOR_ROLES
ENV SEARCH_ROLES=$SEARCH_ROLES
ENV INDEX_ROLES=$INDEX_ROLES
ENV CHANNEL_CHAT_ROLES=$CHANNEL_CHAT_ROLES
ENV CHANNEL_INSTRUCTION_ROLES=$CHANNEL_INSTRUCTION_ROLES
ENV CHAT_BYPASS_ROLES=$CHAT_BYPASS_ROLES
ENV USER_INPUT_API_KEYS=$USER_INPUT_API_KEYS
ENV USER_KEY_DB_PATH=$USER_KEY_DB_PATH
ENV MAX_SEARCH_PRICE=$MAX_SEARCH_PRICE
ENV MAX_DEEP_COMPOSE_PRICE=$MAX_DEEP_COMPOSE_PRICE
ENV CUSTOM_BOT_NAME=$CUSTOM_BOT_NAME
ENV WELCOME_MESSAGE=$WELCOME_MESSAGE
ENV BOT_TAGGABLE=$BOT_TAGGABLE
ENV PRE_MODERATE=$PRE_MODERATE
ENV FORCE_ENGLISH=$FORCE_ENGLISH


# Build container
FROM python:${PY_VERSION} as base
FROM base as builder
ARG PY_VERSION
ARG TARGETPLATFORM
ARG FULL

COPY . .

#Install rust
RUN apt-get update
RUN apt-get install -y \
    build-essential \
    gcc \
    curl
RUN curl https://sh.rustup.rs -sSf | bash -s -- -y
ARG PATH="/root/.cargo/bin:${PATH}"
# https://github.com/rust-lang/cargo/issues/10583
ARG CARGO_NET_GIT_FETCH_WITH_CLI=true

RUN mkdir /install /src
WORKDIR /install

RUN pip install --target="/install" --upgrade pip setuptools wheel setuptools_rust

COPY requirements_base.txt /install
COPY requirements_full.txt /install
RUN pip install --target="/install" --upgrade -r requirements_base.txt
RUN if [ "${FULL}" = "true" ]; then \
    if [ "${TARGETPLATFORM}" = "linux/amd64" ]; then pip install --target="/install" --upgrade torch==1.13.1+cpu torchvision==0.14.1+cpu -f https://download.pytorch.org/whl/torch_stable.html ; fi \
    ; if [ "${TARGETPLATFORM}" = "linux/arm64" ]; then pip install --target="/install" --upgrade torch==1.13.1 torchvision==0.14.1 -f https://torch.kmtea.eu/whl/stable.html -f https://ext.kmtea.eu/whl/stable.html ; fi \  
    ; pip install --target="/install" --upgrade \
       -r requirements_full.txt \
    ; pip install --target="/install" --upgrade \
       --no-deps --no-build-isolation openai-whisper sentence-transformers==2.2.2 \
    ; fi

COPY README.md /src
COPY cogs /src/cogs
COPY models /src/models
COPY services /src/services
COPY gpt3discord.py /src
COPY pyproject.toml /src

# For debugging + seeing that the modiles file layouts look correct ...
RUN find /src
RUN pip install --target="/install" /src

# Copy minimal to main image (to keep as small as possible)
FROM python:${PY_VERSION}-slim

ARG PY_VERSION
COPY . .
COPY --from=builder /install /usr/local/lib/python${PY_VERSION}/site-packages
#Install ffmpeg and clean
RUN apt-get -y update
RUN apt-get -y install --no-install-recommends ffmpeg
RUN apt-get clean
RUN rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt/gpt3discord/etc
COPY gpt3discord.py /opt/gpt3discord/bin/
COPY image_optimizer_pretext.txt language_detection_pretext.txt conversation_starter_pretext.txt conversation_starter_pretext_minimal.txt /opt/gpt3discord/share/
COPY openers /opt/gpt3discord/share/openers
CMD ["python3", "/opt/gpt3discord/bin/gpt3discord.py"]
