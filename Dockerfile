FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:99

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential xvfb fluxbox x11vnc websockify \
    curl unzip fonts-liberation libnss3 libatk-bridge2.0-0 \
    libdrm2 libxcomposite1 libxdamage1 libxrandr2 libgbm1 \
    libpango-1.0-0 libasound2t64 libcups2 libxkbcommon0 \
    wget xz-utils libatomic1

RUN apt-get install -y novnc

# ngrok agent — used by entrypoint.sh to expose noVNC (6080) with a public URL.
RUN curl -sSLo /tmp/ngrok.tgz https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz \
    && tar -xzf /tmp/ngrok.tgz -C /usr/local/bin \
    && rm /tmp/ngrok.tgz \
    && ngrok --version

RUN rm -rf /var/lib/apt/lists/*

RUN useradd -m x
USER x

WORKDIR /home/x

RUN wget https://nodejs.org/dist/v26.4.0/node-v26.4.0-linux-x64.tar.xz
RUN tar -xf node-v26.4.0-linux-x64.tar.xz

ENV PATH="/home/x/node-v26.4.0-linux-x64/bin:$PATH"

RUN node -v

RUN wget -qO- https://get.pnpm.io/install.sh | ENV="$HOME/.dashrc" SHELL="$(which dash)" dash -

ENV PNPM_HOME="/home/x/.local/share/pnpm"
ENV PATH="$PNPM_HOME/bin:$PATH"

RUN pnpm -v

COPY --chown=x:x package.json ./
COPY --chown=x:x pnpm-lock.yaml ./
COPY --chown=x:x pnpm-workspace.yaml ./

RUN pnpm install

USER root

ENV PLAYWRIGHT_BROWSERS_PATH=/home/x/.playwright
RUN pnpm exec playwright install chromium --with-deps 2>/dev/null

USER x

COPY --chown=x:x . .
RUN pnpm run build

ENV PATH="/home/x:$PATH"
ENTRYPOINT ["entrypoint.sh"]

EXPOSE 6080
